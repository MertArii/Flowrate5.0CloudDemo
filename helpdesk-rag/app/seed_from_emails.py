"""emails.json'daki 105 gerçek ticket/çözümü yeni 10 tablolu şemaya dağıtır
ve tüm tabloları mantıklı sahte veriyle doldurur.

Nasıl çalışır (api container içinde, Ollama + Postgres erişimi olan yerde):
    docker compose -f docker-compose.demo.yml exec api python app/seed_from_emails.py

Üretilen:
  support_groups (2)  users (müşteriler + 13 uzman)  tickets (105, resolved/closed)
  ticket_messages (müşteri + ai_bot taslağı + uzman çözümü)
  message_attachments + attachment_vectors (görsel içeren ticket'lar için, OCR + embedding)
  ticket_solutions (105, problem embedding'i ile — RAG Katman 1)
  routing_logs (105)  routing_rules (4)  ai_feedbacks (ai_bot mesajlarına puan)

DİKKAT: Başta tüm tabloları TRUNCATE eder (mevcut test verisi silinir).
"""
from __future__ import annotations

import asyncio
import json
import os
import random
from datetime import datetime, timedelta
from pathlib import Path

import psycopg
from pgvector.psycopg import register_vector

from app.config import settings
from app.rag import ollama_client

random.seed(42)
SEED_FILE = Path(__file__).resolve().parent.parent / "data" / "seed" / "emails.json"

# kime -> destek grubu
GROUP_BY_RECIPIENT = {
    "sapdestek@gmail.com": ("SAP Danışman Ekibi", "SAP modülleri (FI, MM, SD) ve iş süreçleri desteği"),
    "btdestek@gmail.com": ("BT Destek Ekibi", "Donanım, ağ, e-posta, hesap ve genel BT desteği"),
}
DEFAULT_GROUP = ("Genel Triyaj", "Sınıflandırılamayan talepler için insan triyaj kuyruğu")

# Öncelik tahmini için anahtar kelimeler
HIGH_KW = ["acil", "çalışmıyor", "giremiyorum", "durdu", "erişemiyorum", "kritik", "mavi ekran"]
URGENT_KW = ["üretim durdu", "hiç kimse", "tüm", "acilen"]

# Kategori tahmini
def guess_category(recipient: str, konu: str, sorun: str) -> str:
    t = (konu + " " + sorun).lower()
    if "sapdestek" in recipient:
        if any(k in t for k in ["vl01n", "teslimat", "sipariş", "mmbe", "va03", "stok"]):
            return "SAP-SD/MM"
        if any(k in t for k in ["fb60", "fatura", "muhasebe", "mizan"]):
            return "SAP-FI"
        return "SAP-Genel"
    if any(k in t for k in ["monitör", "ekran", "görüntü", "kablo", "yazıcı", "klavye", "fare"]):
        return "Donanım"
    if any(k in t for k in ["outlook", "mail", "e-posta", "parola", "şifre", "hesap", "kilit"]):
        return "Hesap/E-posta"
    if any(k in t for k in ["vpn", "ağ", "internet", "bağlant"]):
        return "Ağ"
    return "Genel-BT"


def guess_priority(konu: str, sorun: str) -> str:
    t = (konu + " " + sorun).lower()
    if any(k in t for k in URGENT_KW):
        return "urgent"
    if any(k in t for k in HIGH_KW):
        return "high"
    return random.choice(["medium", "medium", "low"])


def needs_attachment(konu: str, sorun: str) -> bool:
    t = (konu + " " + sorun).lower()
    return any(k in t for k in ["ekran", "monitör", "görüntü", "hata", "mavi ekran", "yazıcı"])


def agent_email(name: str) -> str:
    base = name.strip().lower().replace(" ", ".")
    tr = str.maketrans("çğıöşü", "cgiosu")
    return base.translate(tr) + "@sirket.com"


async def main():
    data = json.loads(SEED_FILE.read_text(encoding="utf-8"))
    conn = psycopg.connect(settings.database_url)
    register_vector(conn)
    cur = conn.cursor()

    print(f"[seed] {len(data)} kayıt yüklenecek. Tablolar temizleniyor...")
    cur.execute("""
        TRUNCATE ai_feedbacks, attachment_vectors, message_attachments,
                 ticket_messages, ticket_solutions, routing_logs, tickets,
                 routing_rules, users, support_groups RESTART IDENTITY CASCADE;
    """)
    conn.commit()

    # --- support_groups ---
    group_ids: dict[str, str] = {}
    for gname, gdesc in list(GROUP_BY_RECIPIENT.values()) + [DEFAULT_GROUP]:
        cur.execute(
            "INSERT INTO support_groups (name, description, email_alias) VALUES (%s,%s,%s) RETURNING id",
            (gname, gdesc, None),
        )
        group_ids[gname] = cur.fetchone()[0]
    # e-posta alias'ları
    for rec, (gname, _) in GROUP_BY_RECIPIENT.items():
        cur.execute("UPDATE support_groups SET email_alias=%s WHERE id=%s", (rec, group_ids[gname]))
    conn.commit()

    def group_for(recipient: str) -> str:
        return group_ids[GROUP_BY_RECIPIENT.get(recipient, (DEFAULT_GROUP[0],))[0]] \
            if recipient in GROUP_BY_RECIPIENT else group_ids[DEFAULT_GROUP[0]]

    # --- users: uzmanlar ---
    agent_ids: dict[str, str] = {}
    # her uzmanı, en çok baktığı gruba ata
    agent_group: dict[str, str] = {}
    for e in data:
        a = e["atanan_kisi"]
        agent_group.setdefault(a, e["kime"])
    for a, rec in agent_group.items():
        email = agent_email(a)
        full = a.split(".")[0].capitalize() + " " + a.split(".")[-1].capitalize()
        gname = GROUP_BY_RECIPIENT.get(rec, (DEFAULT_GROUP[0],))[0]
        cur.execute(
            """INSERT INTO users (email, full_name, title, department, role, support_group_id)
               VALUES (%s,%s,%s,%s,'agent',%s) RETURNING id""",
            (email, full, "Destek Uzmanı", "Bilgi Teknolojileri", group_ids[gname]),
        )
        agent_ids[a] = cur.fetchone()[0]
    conn.commit()

    # --- users: müşteriler ---
    customer_ids: dict[str, str] = {}
    titles = ["Uzman", "Müdür", "Şef", "Direktör", "Mühendis", "Sorumlu"]
    depts = ["Muhasebe", "Lojistik", "Satış", "Üretim", "İK", "Satınalma"]
    for e in data:
        em = e["kullanici_maili"]
        if em in customer_ids:
            continue
        full = em.split("@")[0].replace(".", " ").title()
        cur.execute(
            """INSERT INTO users (email, full_name, title, department, region, role)
               VALUES (%s,%s,%s,%s,%s,'customer') RETURNING id""",
            (em, full, random.choice(titles), random.choice(depts), e["bolge"]),
        )
        customer_ids[em] = cur.fetchone()[0]
    conn.commit()
    print(f"[seed] {len(agent_ids)} uzman, {len(customer_ids)} müşteri eklendi.")

    # --- routing_rules (statik) ---
    sap_gid = group_ids["SAP Danışman Ekibi"]
    bt_gid = group_ids["BT Destek Ekibi"]
    rules = [
        ("SAP Mail Doğrudan Atama", "sapdestek@%", ["VL01N", "VA03", "FB60", "MMBE"], None, sap_gid, 20),
        ("BT Mail Doğrudan Atama", "btdestek@%", ["monitör", "outlook", "parola", "yazıcı"], None, bt_gid, 20),
        ("SAP Anahtar Kelime", None, ["SAP", "teslimat belgesi", "sipariş"], None, sap_gid, 10),
        ("Donanım Anahtar Kelime", None, ["ekran", "kablo", "klavye"], None, bt_gid, 10),
    ]
    for rn, pat, kw, dom, gid, ps in rules:
        cur.execute(
            """INSERT INTO routing_rules (rule_name, recipient_email_pattern, keyword_triggers,
                       sender_domain, target_group_id, priority_score)
               VALUES (%s,%s,%s,%s,%s,%s)""",
            (rn, pat, kw, dom, gid, ps),
        )
    conn.commit()

    # --- her ticket için tam zincir ---
    now = datetime.now()
    att_count = 0
    for i, e in enumerate(data):
        created = now - timedelta(days=random.randint(1, 60), hours=random.randint(0, 23))
        resolved = created + timedelta(hours=random.randint(1, 48))
        cat = guess_category(e["kime"], e["konu"], e["sorun_aciklamasi"])
        prio = guess_priority(e["konu"], e["sorun_aciklamasi"])
        gid = group_for(e["kime"])
        aid = agent_ids[e["atanan_kisi"]]
        cid = customer_ids[e["kullanici_maili"]]
        status = "closed" if random.random() < 0.3 else "resolved"

        cur.execute(
            """INSERT INTO tickets
               (customer_email, customer_id, recipient_email, subject, raw_issue_description,
                extracted_category, region, status, priority, assigned_group_id,
                assigned_agent_id, created_at, updated_at, resolved_at)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id""",
            (e["kullanici_maili"], cid, e["kime"], e["konu"], e["sorun_aciklamasi"],
             cat, e["bolge"], status, prio, gid, aid, created, resolved, resolved),
        )
        tid = cur.fetchone()[0]

        # mesajlar: müşteri -> ai_bot taslağı -> uzman çözümü
        cur.execute(
            """INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body, created_at)
               VALUES (%s,%s,'customer',%s,%s)""",
            (tid, e["kullanici_maili"], e["sorun_aciklamasi"], created),
        )
        draft = f"Öneri: {e['cozum'][:180]}"
        cur.execute(
            """INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body,
                       ai_generated_draft, rag_sources_used, created_at)
               VALUES (%s,'ai_bot@sirket.local','ai_bot',%s,%s,%s,%s) RETURNING id""",
            (tid, "AI tarafından çözüm taslağı hazırlandı.", draft,
             json.dumps({"katman": "ticket_solutions", "eslesme": e["ticket_id"]}),
             created + timedelta(minutes=2)),
        )
        ai_msg_id = cur.fetchone()[0]
        cur.execute(
            """INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body, created_at)
               VALUES (%s,%s,'agent',%s,%s)""",
            (tid, agent_email(e["atanan_kisi"]), e["cozum"], resolved),
        )

        # ai_feedbacks: uzmanın taslağa verdiği puan
        cur.execute(
            """INSERT INTO ai_feedbacks (message_id, user_id, rating, feedback_text)
               VALUES (%s,%s,%s,%s)""",
            (ai_msg_id, aid, random.choice([3, 4, 4, 5, 5]),
             random.choice(["Taslak isabetliydi.", "Küçük düzeltme ile kullanıldı.",
                            "Doğru yöne işaret etti.", "Çözümün çoğu doğruydu."])),
        )

        # ekler (görsel içeren ticket'lar)
        if needs_attachment(e["konu"], e["sorun_aciklamasi"]):
            fname = random.choice(["hata_ekrani.png", "ekran_goruntusu.png", "cihaz_foto.jpg"])
            ocr = f"[Ekran görüntüsü OCR] {e['konu']} - {e['sorun_aciklamasi'][:120]}"
            cur.execute(
                """INSERT INTO message_attachments (message_id, file_name, file_path, file_type, ocr_extracted_text, created_at)
                   VALUES (%s,%s,%s,%s,%s,%s) RETURNING id""",
                (ai_msg_id, fname, f"/data/attachments/{e['ticket_id']}_{fname}",
                 "image/png" if fname.endswith("png") else "image/jpeg", ocr, created),
            )
            att_id = cur.fetchone()[0]
            emb = await ollama_client.embed(ocr)
            cur.execute(
                """INSERT INTO attachment_vectors (attachment_id, ticket_id, source, chunk_index, chunk_content, embedding)
                   VALUES (%s,%s,%s,0,%s,%s)""",
                (att_id, tid, fname, ocr, emb),
            )
            att_count += 1

        # ticket_solutions (RAG Katman 1) — problem metninin embedding'i
        emb = await ollama_client.embed(e["sorun_aciklamasi"])
        cur.execute(
            """INSERT INTO ticket_solutions
               (ticket_id, category, problem_text, solution_text, embedding, metadata, is_verified)
               VALUES (%s,%s,%s,%s,%s,%s,true)""",
            (tid, cat, e["sorun_aciklamasi"], e["cozum"], emb,
             json.dumps({"bolge": e["bolge"], "uzman": e["atanan_kisi"],
                         "harici_no": e["ticket_id"]}, ensure_ascii=False)),
        )

        # routing_logs
        cur.execute(
            """INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id,
                       assigned_agent_id, confidence_score, created_at)
               VALUES (%s,%s,%s,%s,%s,%s)""",
            (tid, json.dumps({"alici": e["kime"], "kategori": cat,
                              "kural": "recipient_email_pattern", "bolge": e["bolge"]},
                             ensure_ascii=False),
             gid, aid, round(random.uniform(0.72, 0.98), 2), created),
        )

        if (i + 1) % 20 == 0:
            conn.commit()
            print(f"[seed] {i + 1}/{len(data)} ticket işlendi...")

    conn.commit()
    cur.close()
    conn.close()
    print(f"[seed] TAMAM. 105 ticket, {att_count} ek/vektör, 105 çözüm embedding'i yazıldı.")


if __name__ == "__main__":
    asyncio.run(main())
