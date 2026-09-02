from __future__ import annotations
"""L1 triyaj orkestrasyonu (yeni şema): sınıflandır -> yönlendir ->
RAG çözüm denemesi -> tickets + routing_logs kaydı.

Atama mantığının tamamı (uzmanlık uyuşması -> bölge -> iş yükü -> rastgele
eşitlik) router.route() içinde, tümüyle DB'den. Bkz. app/triage/router.py.
"""
from langfuse import observe

from datetime import datetime, timezone

from app.logging_config import get_logger
from app.rag import pipeline
from app.triage import classifier, router, sla

logger = get_logger(__name__)

REFUSAL_MARK = "elimde bilgi yok"

# Sınıflandırıcının "1"-"5" (SLA seviyesi) çıktısını tickets.priority CHECK
# değerine çevirir. sla_policies.level_int ile birebir aynı sıralama:
# 1=urgent, 2=high, 3=medium, 4=low, 5=planned.
_ONCELIK_MAP = {"1": "urgent", "2": "high", "3": "medium", "4": "low", "5": "planned"}

@observe(name="triage_orchestration")
async def triage(
    ticket_text: str,
    customer_email: str = "demo@sirket.com",
    recipient_email: str = "destek@sirket.com",
    subject: str | None = None,
    region: str | None = None,
    min_score: float | None = None,
    extra_context: str | None = None,
    images_b64: list[str] | None = None,
    attachment: dict | None = None,
) -> dict:
    """attachment verilirse (file_name, file_path, file_type, extracted_text)
    ticket'a bağlı bir müşteri mesajına eklenip attachment_vectors'e
    (RAG Katman 2) kalıcı olarak yazılır — ileride başka sorularda da
    bulunabilir hale gelir."""
    from app.rag import store  # geç import: DB tabloları hazır olmadan yüklenmesin

    c = await classifier.classify(ticket_text)
    logger.info(
        "Sınıflandırma: %s (güven %.2f)",
        c["modul"], c["guven"],
    )
    r = router.route(c, region=region)

    # Bilinen sorun mu? RAG (çift katman) ile otomatik çözüm denemesi.
    # extra_context/images_b64 -> eklenen dosya varsa bu cevaba da katılır.
    rag = await pipeline.answer(
        ticket_text, min_score=min_score,
        extra_context=extra_context, images_b64=images_b64,
    )
    cozuldu = REFUSAL_MARK not in rag["answer"].lower()
    onerilen_cozum = rag["answer"] if cozuldu else None

    # atanan_uzman zaten DB'den (get_agents_in_group/get_agents_by_category)
    # geldiği için normalde her zaman gerçek bir users kaydına çözülür. Yine
    # de savunma amaçlı: çözülemezse otomatik atama İPTAL edilir.
    otomatik = r["otomatik_atandi"]
    agent_id = store.get_user_id_by_email(r["atanan_uzman"]) if otomatik and r["atanan_uzman"] else None
    if otomatik and r["atanan_uzman"] and not agent_id:
        otomatik = False
        r = {**r, "otomatik_atandi": False,
             "sebep": f"{r['atanan_uzman']} gerçek bir kullanıcı değil — insan triyajı gerekiyor."}

    status = "assigned" if otomatik else "l1_routing"
    subj = subject or ticket_text[:60]
    group_id = store.get_or_create_support_group(r["ekip"]) if otomatik else None
    priority = _ONCELIK_MAP.get(c["oncelik"], "medium")

    baslangic = datetime.now(timezone.utc)
    sla_policy = store.get_sla_policy(priority)
    deadlines = sla.compute_deadlines(baslangic, sla_policy) if sla_policy else {}

    sub_category_id = store.get_alt_kategori_id(c.get("alt_kategori"), c.get("kategori_grubu"))
    sap_module_id = store.get_sap_module_id(c.get("sap_modulu"))

    tid, tno = store.create_ticket(
        customer_email=customer_email,
        recipient_email=recipient_email,
        subject=subj,
        raw_issue_description=ticket_text,
        extracted_category=c["modul"],
        region=region,
        status=status,
        priority=priority,
        assigned_group_id=group_id,
        assigned_agent_id=agent_id if otomatik else None,
        sla_policy_id=sla_policy["id"] if sla_policy else None,
        response_deadline=deadlines.get("response_deadline"),
        workaround_deadline=deadlines.get("workaround_deadline"),
        resolution_deadline=deadlines.get("resolution_deadline"),
        sub_category_id=sub_category_id,
        sap_module_id=sap_module_id,
    )

    store.create_routing_log(
        ticket_id=tid,
        decision_factors={"siniflandirma": c, "yonlendirme": r},
        assigned_group_id=group_id,
        assigned_agent_id=agent_id if otomatik else None,
        confidence_score=c["guven"],
    )

    # Mesaj zinciri: müşteri sorusu + (varsa) ek + AI'ın taslak cevabı.
    musteri_mid = store.create_ticket_message(
        ticket_id=tid, sender_email=customer_email, sender_type="customer",
        message_body=ticket_text,
    )
    if attachment:
        att_id = store.create_attachment(
            message_id=musteri_mid,
            file_name=attachment["file_name"],
            file_path=attachment["file_path"],
            file_type=attachment.get("file_type"),
            ocr_extracted_text=attachment.get("extracted_text"),
        )
        if attachment.get("extracted_text"):
            from app.rag import ollama_client
            emb = await ollama_client.embed(attachment["extracted_text"])
            store.add_attachment_vector(
                attachment_id=att_id, ticket_id=tid,
                source=attachment["file_name"],
                content=attachment["extracted_text"], embedding=emb,
            )
    store.create_ticket_message(
        ticket_id=tid, sender_email="ai_bot@sirket.local", sender_type="ai_bot",
        message_body="AI tarafından çözüm taslağı hazırlandı.",
        ai_generated_draft=rag["answer"], rag_sources_used=rag["sources"],
    )

    return {
        "ticket_id": tid,
        "ticket_number": tno,
        "siniflandirma": c,
        "yonlendirme": r,
        "otomatik_cozum": onerilen_cozum,   # None ise uzmana gitmeli (triyaj anlamı)
        "kaynaklar": rag["sources"] if cozuldu else [],
        # /ask gibi her zaman cevap gösteren yerler için (reddetse bile dolu):
        "cevap_metni": rag["answer"],
        "tum_kaynaklar": rag["sources"],
    }
