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
      "role", "support_group_id", "created_at", "updated_at",
      "uzman_kategorileri"]),
    ("routing_rules", "routing_rules_202608201205.json",
     ["id", "rule_name", "recipient_email_pattern", "keyword_triggers",
      "sender_domain", "target_group_id", "default_assigned_agent_id",
      "priority_score", "is_active", "created_at"]),
]

ARRAY_COLUMNS = {"uzman_kategorileri", "keyword_triggers"}
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

    cur.close()
    conn.close()
    print("TAMAMLANDI.")


if __name__ == "__main__":
    main()
