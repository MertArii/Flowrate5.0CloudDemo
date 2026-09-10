"""db/archive/20_08_26'daki SABİT/referans verileri (ticket'lara bağlı
tarihsel veri DEĞİL) canlı DB'ye geri yükler — DB tamamen sıfırlandıktan
sonraki kurtarma için. Sıra FK bağımlılıklarına göre zorunludur:
  support_groups -> sla_policies -> classification_categories -> users -> routing_rules

tickets/routing_logs/ticket_messages/ticket_solutions/ai_feedbacks/
message_attachments/attachment_vectors BİLEREK yüklenmiyor (kullanıcı
3 haftalık eski ticket verisini istemiyor, bunun yerine sla dataset'ten
~4000 kayıt import edilecek).

Çalıştırma (api container içinde):
    docker exec -e PYTHONPATH=/code -w /code helpdesk-rag-api-1 python scripts/restore_static_data.py
"""
from __future__ import annotations

import json
from pathlib import Path

import psycopg

from app.config import settings

ARCHIVE_DIR = Path(__file__).resolve().parent.parent / "db" / "archive" / "20_08_26"

TABLES = [
    ("support_groups", "support_groups_202608201205.json",
     ["id", "name", "email_alias", "description", "created_at"]),
    ("sla_policies", "sla_policies_202608201205.json",
     ["id", "level_int", "level_name", "priority_key", "response_target",
      "workaround_target", "resolution_target", "is_business_days",
      "description", "created_at"]),
    ("classification_categories", "classification_categories_202608201204.json",
     ["id", "category_key", "aciklama", "ekip_group_id", "is_active",
      "created_at", "ekip_gorunum_adi"]),
    ("users", "users_202608201521.json",
     ["id", "email", "full_name", "title", "department", "region", "phone",
      "role", "support_group_id", "created_at", "updated_at"]),
    ("routing_rules", "routing_rules_202608201205.json",
     ["id", "rule_name", "recipient_email_pattern", "keyword_triggers",
      "sender_domain", "target_group_id", "default_assigned_agent_id",
      "priority_score", "is_active", "created_at"]),
]

# uzman_kategorileri artik users'ta degil, ayri agent_expertise koprü
# tablosunda (1NF, bkz. db/010_uzman_kategorileri_1nf.sql) -- users.json
# arsivindeki dizi alani asagida restore_agent_expertise() ile
# geri yuklenir, buradaki genel TABLES dongusune dahil degil.
ARRAY_COLUMNS = {"keyword_triggers"}
INTERVAL_COLUMNS = {"response_target", "workaround_target", "resolution_target"}


def _load(filename: str) -> list[dict]:
    data = json.loads((ARCHIVE_DIR / filename).read_text(encoding="utf-8"))
    if isinstance(data, dict):
        data = data[next(iter(data))]
    return data


def _cast(col: str) -> str:
    if col in ARRAY_COLUMNS:
        return "::text[]"
    if col in INTERVAL_COLUMNS:
        return "::interval"
    return ""


def restore_agent_expertise(cur, conn) -> None:
    """users_202608201521.json arşivindeki uzman_kategorileri dizisini
    agent_expertise köprü tablosuna (1NF) geri yükler. Tabloda category_id
    (UUID) tutulduğu için category_key -> id çevirisi classification_categories
    üzerinden yapılır."""
    cur.execute("SELECT count(*) FROM agent_expertise")
    if cur.fetchone()[0] > 0:
        print("[atla] agent_expertise: zaten kayıt var, üzerine yazmıyorum.")
        return

    records = _load("users_202608201521.json")
    eklendi = 0
    for rec in records:
        kategoriler = rec.get("uzman_kategorileri")
        if not kategoriler:
            continue
        for kat in kategoriler:
            try:
                cur.execute(
                    """
                    INSERT INTO agent_expertise (user_id, category_id)
                    SELECT %s, cc.id FROM classification_categories cc WHERE cc.category_key = %s
                    ON CONFLICT DO NOTHING
                    """,
                    (rec["id"], kat),
                )
                conn.commit()
                eklendi += 1
            except Exception as e:
                conn.rollback()
                print(f"[hata] agent_expertise ({rec.get('id')}, {kat}): {e}")
    print(f"[+] agent_expertise: {eklendi} kayıt yüklendi.")


def main() -> None:
    conn = psycopg.connect(settings.database_url)
    cur = conn.cursor()
    for table, filename, columns in TABLES:
        cur.execute(f"SELECT count(*) FROM {table}")
        mevcut = cur.fetchone()[0]
        if mevcut > 0:
            print(f"[atla] {table}: zaten {mevcut} kayıt var, üzerine yazmıyorum.")
            continue

        records = _load(filename)
        col_list = ", ".join(columns)
        placeholders = ", ".join(f"%s{_cast(c)}" for c in columns)
        sql = f"INSERT INTO {table} ({col_list}) VALUES ({placeholders})"

        eklendi = 0
        for rec in records:
            values = [rec.get(c) for c in columns]
            try:
                cur.execute(sql, values)
                conn.commit()
                eklendi += 1
            except Exception as e:
                conn.rollback()
                print(f"[hata] {table} kaydı ({rec.get('id')}): {e}")
        print(f"[+] {table}: {eklendi}/{len(records)} kayıt yüklendi.")

    restore_agent_expertise(cur, conn)

    cur.close()
    conn.close()
    print("TAMAMLANDI.")


if __name__ == "__main__":
    main()
