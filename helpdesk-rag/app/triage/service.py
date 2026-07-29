"""L1 triyaj orkestrasyonu (yeni şema): sınıflandır -> yönlendir ->
RAG çözüm denemesi -> tickets + routing_logs kaydı.
"""
from __future__ import annotations

from app.rag import pipeline
from app.triage import classifier, router

REFUSAL_MARK = "elimde bilgi yok"

# Sınıflandırıcının Türkçe öncelik etiketini şema CHECK değerine çevir.
_ONCELIK_MAP = {"dusuk": "low", "orta": "medium", "yuksek": "high", "kritik": "urgent"}

# Bölge eşleşmesi SADECE bu kategoride uygulanır (donanım = sahaya çıkan iş).
# SAP kategorilerinde asla uygulanmaz — SAP desteği bölgeden bağımsızdır.
BOLGE_ESLESMESI_UYGULANAN_MODUL = "IT-Donanim"


def _bolge_eslesen_uzman(store, ekip: str, region: str | None) -> str | None:
    """O grubun TÜM üyelerini DB'den çeker (routing_rules.json'daki elle
    tutulan listeye değil, gerçek support_group üyeliğine dayanır) ve
    region'ı isteğe uyan ilk uzmanı döner; yoksa None."""
    if not region:
        return None
    for agent in store.get_agents_in_group(ekip):
        if agent["region"] == region:
            return agent["email"]
    return None


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

    # Yönlendirme -> destek grubu + uzman UUID'leri.
    otomatik = r["otomatik_atandi"]

    # Bölge eşleşmesi — SADECE donanım kategorisinde, SAP'de asla. Talep
    # sahibinin bölgesiyle aynı bölgedeki uzman varsa o tercih edilir;
    # yoksa router'ın varsayılan (ilk) adayında kalınır.
    bolge_eslesti = False
    if otomatik and c["modul"] == BOLGE_ESLESMESI_UYGULANAN_MODUL and region:
        eslesen = _bolge_eslesen_uzman(store, r["ekip"], region)
        if eslesen and eslesen != r["atanan_uzman"]:
            r = {**r, "atanan_uzman": eslesen,
                 "sebep": f"{r['sebep']} + bölge eşleşmesi ({region})"}
            bolge_eslesti = True
        elif eslesen:
            bolge_eslesti = True  # varsayılan zaten doğru bölgedeydi

    # atanan_uzman bir e-posta olarak gelir (routing_rules.json); DB'de gerçek
    # bir users kaydına çözülemiyorsa (uydurma/placeholder isim) otomatik
    # atama İPTAL edilir ve ticket insan triyajına düşer — yanlış kişiye
    # (veya var olmayan birine) atanmasını engeller.
    agent_id = store.get_user_id_by_email(r["atanan_uzman"]) if otomatik and r["atanan_uzman"] else None
    if otomatik and r["atanan_uzman"] and not agent_id:
        otomatik = False
        r = {**r, "otomatik_atandi": False,
             "sebep": f"{r['atanan_uzman']} gerçek bir kullanıcı değil — insan triyajı gerekiyor."}

    # Sonuçta gösterilecek bölge bilgisi (talep edilen + eşleşme durumu).
    r = {**r, "istenen_bolge": region,
         "bolge_eslesti": bolge_eslesti if c["modul"] == BOLGE_ESLESMESI_UYGULANAN_MODUL else None}

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
        assigned_agent_id=agent_id if otomatik else None,
    )

    store.create_routing_log(
        ticket_id=tid,
        decision_factors={"siniflandirma": c, "yonlendirme": r},
        assigned_group_id=group_id,
        assigned_agent_id=agent_id if otomatik else None,
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
