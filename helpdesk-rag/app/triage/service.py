"""L1 triyaj orkestrasyonu: sınıflandır -> yönlendir -> (RAG cevabı) -> kaydet.

Sistem çalıştıkça her ticket DB'ye yazılır; bu birikim ileride 'geçmiş
ticket'lardan öğrenme' (benzerlik tabanlı yönlendirme) için veri tabanı olur.
"""
from __future__ import annotations

import psycopg

from app.config import settings
from app.rag import pipeline
from app.triage import classifier, router

REFUSAL_MARK = "elimde bilgi yok"


def _save_ticket(text: str, c: dict, r: dict, cozum: str | None) -> int:
    with psycopg.connect(settings.database_url) as conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO tickets
                (sorun_aciklamasi, modul, oncelik, ozet, guven, ekip,
                 atanan_kisi, otomatik_atandi, onerilen_cozum, durum)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING ticket_id
            """,
            (
                text, c["modul"], c["oncelik"], c["ozet"], c["guven"],
                r["ekip"], r["atanan_uzman"], r["otomatik_atandi"],
                cozum, "acik",
            ),
        )
        tid = cur.fetchone()[0]
        conn.commit()
    return tid


async def triage(ticket_text: str) -> dict:
    c = await classifier.classify(ticket_text)
    r = router.route(c)

    # Bilinen bir sorun mu? RAG ile otomatik cevap denemesi.
    rag = await pipeline.answer(ticket_text)
    cozuldu = REFUSAL_MARK not in rag["answer"].lower()
    onerilen_cozum = rag["answer"] if cozuldu else None

    tid = _save_ticket(ticket_text, c, r, onerilen_cozum)

    return {
        "ticket_id": tid,
        "siniflandirma": c,
        "yonlendirme": r,
        "otomatik_cozum": onerilen_cozum,   # None ise uzmana gitmeli
        "kaynaklar": rag["sources"] if cozuldu else [],
    }
