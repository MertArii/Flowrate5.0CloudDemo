"""Mevcut (zaten seed edilmiş) 105 tarihsel ticket'ın kategorisini eski
taksonomiden (SAP-SD/MM, Donanım, Hesap/E-posta...) yeni/canlı taksonomiye
(SAP-SD, IT-Donanim, IT-Hesap...) çevirir. TAM RE-SEED YAPMAZ — sonradan
/ask veya /triage ile oluşturulmuş test ticket'larına (106+) dokunmaz,
çünkü onlar zaten canlı sınıflandırıcının kategorilerini kullanıyordu.

Eşleştirme, orijinal problem metnine göre yapılır (emails.json'daki
sorun_aciklamasi tickets.raw_issue_description ve ticket_solutions.problem_text
ile birebir aynı olduğu için güvenilir bir anahtar).

Çalıştırma:
    docker compose -f docker-compose.demo.yml exec api python app/remap_categories.py
"""
from __future__ import annotations

import json
from pathlib import Path

import psycopg

from app.config import settings
from app.seed_from_emails import guess_category

SEED_FILE = Path(__file__).resolve().parent.parent / "data" / "seed" / "emails.json"


def main():
    data = json.loads(SEED_FILE.read_text(encoding="utf-8"))
    conn = psycopg.connect(settings.database_url)
    cur = conn.cursor()

    guncellenen = 0
    for e in data:
        yeni_kategori = guess_category(e["kime"], e["konu"], e["sorun_aciklamasi"])

        cur.execute(
            "UPDATE tickets SET extracted_category=%s WHERE raw_issue_description=%s",
            (yeni_kategori, e["sorun_aciklamasi"]),
        )
        cur.execute(
            "UPDATE ticket_solutions SET category=%s WHERE problem_text=%s",
            (yeni_kategori, e["sorun_aciklamasi"]),
        )
        guncellenen += cur.rowcount

    conn.commit()
    cur.execute("SELECT extracted_category, count(*) FROM tickets GROUP BY extracted_category ORDER BY 1")
    print("[remap] Yeni kategori dağılımı:")
    for kat, adet in cur.fetchall():
        print(f"  {kat}: {adet}")
    cur.close()
    conn.close()
    print(f"[remap] TAMAM. {len(data)} kayıt işlendi.")


if __name__ == "__main__":
    main()
