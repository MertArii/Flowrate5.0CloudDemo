"""L1 triyaj orkestrasyonu (yeni şema): sınıflandır -> yönlendir ->
RAG çözüm denemesi -> tickets + routing_logs kaydı.
"""
from __future__ import annotations

from app.rag import pipeline
from app.triage import classifier, router

REFUSAL_MARK = "elimde bilgi yok"

# Sınıflandırıcının Türkçe öncelik etiketini şema CHECK değerine çevir.
_ONCELIK_MAP = {"dusuk": "low", "orta": "medium", "yuksek": "high", "kritik": "urgent"}


async def triage(
    ticket_text: str,
    customer_email: str = "demo@sirket.com",
    recipient_email: str = "destek@sirket.com",
    subject: str | None = None,
    region: str | None = None,
    min_score: float | None = None,
) -> dict:
    from app.rag import store  # geç import: DB tabloları hazır olmadan yüklenmesin

    c = await classifier.classify(ticket_text)
    r = router.route(c)

    # Bilinen sorun mu? RAG (çift katman) ile otomatik çözüm denemesi.
    rag = await pipeline.answer(ticket_text, min_score=min_score)
    cozuldu = REFUSAL_MARK not in rag["answer"].lower()
    onerilen_cozum = rag["answer"] if cozuldu else None

    # Yönlendirme -> destek grubu UUID'si (otomatik atandıysa)
    otomatik = r["otomatik_atandi"]
    group_id = store.get_or_create_support_group(r["ekip"]) if otomatik else None
    priority = _ONCELIK_MAP.get(c["oncelik"], "medium")
    status = "assigned" if otomatik else "l1_routing"
    subj = subject or ticket_text[:60]

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
    )

    store.create_routing_log(
        ticket_id=tid,
        decision_factors={"siniflandirma": c, "yonlendirme": r},
        assigned_group_id=group_id,
        confidence_score=c["guven"],
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
