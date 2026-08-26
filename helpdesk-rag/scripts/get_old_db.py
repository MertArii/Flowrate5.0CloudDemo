import json
import os
import glob
import psycopg2
from psycopg2.extras import Json, execute_values

DB_CONFIG = {
    "dbname": "helpdesk",
    "user": "helpdesk",
    "password": "demopw",
    "host": "127.0.0.1",
    "port": 5433
}

# JSON dosyalarının bulunduğu dizin
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(BASE_DIR, "db", "archive", "20_08_26")

# Tabloların Foreign Key hiyerarşisine göre yüklenme sırası ve dosya ön ekleri
TABLE_LOAD_ORDER = [
    {"table": "support_groups", "file_prefix": "support_groups_"},
    {"table": "sla_policies", "file_prefix": "sla_policies_"},
    {"table": "classification_categories", "file_prefix": "classification_categories_"},
    {"table": "users", "file_prefix": "users_"},
    {"table": "routing_rules", "file_prefix": "routing_rules_"},
    {"table": "tickets", "file_prefix": "tickets_"},
    {"table": "routing_logs", "file_prefix": "routing_logs_"},
    {"table": "ticket_messages", "file_prefix": "ticket_messages_"},
    {"table": "ticket_solutions", "file_prefix": "ticket_solutions_"},
    {"table": "ai_feedbacks", "file_prefix": "ai_feedbacks_"},
    {"table": "message_attachments", "file_prefix": "message_attachments_"},
    {"table": "attachment_vectors", "file_prefix": "attachment_vectors_"}
]

# JSONB ve Vector/Array tipindeki özel kolonlar
JSONB_COLUMNS = {"decision_factors", "rag_sources_used", "metadata"}
VECTOR_COLUMNS = {"embedding"}
ARRAY_COLUMNS = {"uzman_kategorileri", "keyword_triggers"}

def find_file(prefix, directory):
    files = glob.glob(os.path.join(directory, f"{prefix}*.json"))
    return files[0] if files else None

def extract_records(json_data):
    if isinstance(json_data, list):
        return json_data
    if isinstance(json_data, dict):
        for key, value in json_data.items():
            if isinstance(value, list):
                return value
    return []

def format_value(col_name, value):
    if value is None:
        return None
    if col_name in JSONB_COLUMNS:
        return Json(value)
    if col_name in VECTOR_COLUMNS:
        if isinstance(value, list):
            return f"[{','.join(map(str, value))}]"
        return str(value)
    if col_name in ARRAY_COLUMNS:
        if isinstance(value, str) and value.startswith("{") and value.endswith("}"):
            inner = value[1:-1]
            return [x.strip() for x in inner.split(",") if x.strip()]
        return value
    return value

def main():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = False
        cur = conn.cursor()

        # Replikasyon rolünü 'replica' yaparak trigger ve FK kontrollerini geçici olarak devre dışı bırakıyoruz
        cur.execute("SET session_replication_role = 'replica';")

        # 1. TÜM TABLOLARI TEMİZLE
        print("[!] Veritabanı temizleniyor...")
        for item in reversed(TABLE_LOAD_ORDER):
            cur.execute(f"TRUNCATE TABLE public.{item['table']} RESTART IDENTITY CASCADE;")
        print("[✓] Tüm tablolar temizlendi.\n")

        # 2. VERİLERİ YÜKLE
        for item in TABLE_LOAD_ORDER:
            table_name = item["table"]
            file_path = find_file(item["file_prefix"], DATA_DIR)

            if not file_path or not os.path.exists(file_path):
                print(f"[!] Dosya bulunamadı: {item['file_prefix']}*.json")
                continue

            with open(file_path, "r", encoding="utf-8") as f:
                raw_json = json.load(f)
                records = extract_records(raw_json)
                
                if not records:
                    print(f"[-] {table_name}: Kayıt bulunamadı, atlanıyor.")
                    continue

                columns = list(records[0].keys())
                col_names = ", ".join([f'"{col}"' for col in columns])
                placeholders = ", ".join(["%s"] * len(columns))
                
                rows = []
                for rec in records:
                    row = [format_value(col, rec.get(col)) for col in columns]
                    rows.append(tuple(row))

                query = f"INSERT INTO public.{table_name} ({col_names}) VALUES %s"
                execute_values(cur, query, rows)
                print(f"[+] {table_name}: {len(rows)} kayıt başarıyla yüklendi.")

        # Replikasyon rolünü normale döndür ve commit et
        cur.execute("SET session_replication_role = 'origin';")
        conn.commit()
        print("\n[✓] Eski veriler başarıyla geri yüklendi.")

    except Exception as e:
        if 'conn' in locals() and conn:
            conn.rollback()
        print(f"\n[X] Hata oluştu, işlemler geri alındı: {e}")
    finally:
        if 'cur' in locals() and cur:
            cur.close()
        if 'conn' in locals() and conn:
            conn.close()

if __name__ == "__main__":
    main()
