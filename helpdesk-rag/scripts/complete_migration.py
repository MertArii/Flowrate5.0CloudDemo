import json
import uuid
import psycopg2
from psycopg2.extras import execute_values
from datetime import datetime, timedelta

# --- YAPILANDIRMA ---
DB_PARAMS = {
    "dbname": "helpdesk",
    "user": "helpdesk",
    "password": "demopw",
    "host": "localhost",
    "port": 5432
}

def load_json(path):
    with open(path, 'r', encoding='utf-8-sig') as f:
        data = json.load(f)
        # Bazı dosyalar liste değil, anahtar altında liste tutuyor olabilir
        if isinstance(data, dict):
            key = list(data.keys())[0]
            return data[key]
        return data

def run_migration():
    conn = psycopg2.connect(**DB_PARAMS)
    cur = conn.cursor()

    print("1. Tablolar temizleniyor...")
    cur.execute("TRUNCATE tickets, ticket_messages, ticket_solutions, attachment_vectors, message_attachments, users, support_groups, sla_policies CASCADE;")

    print("2. Statik veriler yükleniyor (Users, Groups, SLA Policies)...")
    
    # Support Groups
    groups = load_json('helpdesk-rag/db/archive/20_08_26/support_groups_202608201205.json')
    for g in groups:
        cur.execute("INSERT INTO support_groups (id, name, email_alias, description) VALUES (%s, %s, %s, %s)", 
                   (g['id'], g['name'], g['email_alias'], g['description']))

    # Users
    users = load_json('helpdesk-rag/db/archive/20_08_26/users_202608201521.json')
    user_name_to_id = {}
    for u in users:
        cur.execute("INSERT INTO users (id, email, full_name, role, support_group_id) VALUES (%s, %s, %s, %s, %s)", 
                   (u['id'], u['email'], u['full_name'], u['role'], u['support_group_id']))
        # SLA JSON'daki 'atanan_kisi' ile eşleştirmek için normalize edilmiş isim map'i
        user_name_to_id[u['full_name'].lower()] = u['id']

    # SLA Policies
    policies = load_json('helpdesk-rag/db/archive/20_08_26/sla_policies_202608201205.json')
    level_to_policy_id = {}
    for p in policies:
        cur.execute("INSERT INTO sla_policies (id, level_int, level_name, priority_key, resolution_target) VALUES (%s, %s, %s, %s, %s)", 
                   (p['id'], p['level_int'], p['level_name'], p['priority_key'], p['resolution_target']))
        level_to_policy_id[p['level_int']] = p['id']

    print("3. SLA Ticket verileri aktarılıyor...")
    sla_data = load_json('helpdesk-rag/sla/emails_sla_seviyeli.json')
    
    ticket_map = {} # ticket_number -> uuid map for attachments

    for item in sla_data:
        t_uuid = str(uuid.uuid4())
        ticket_num = int(item['ticket_id'])
        ticket_map[ticket_num] = t_uuid
        
        level = item.get('sla_level_normalize', 3)
        policy_id = level_to_policy_id.get(level)
        
        # Atanan kişiyi bul (basit string eşleme)
        assigned_id = None
        atanan_str = str(item.get('atanan_kisi', '')).split('.')[0].lower() # örn: aylin.teknoloji -> aylin
        for name, uid in user_name_to_id.items():
            if atanan_str in name.lower():
                assigned_id = uid
                break

        cur.execute("""
            INSERT INTO tickets (
                id, ticket_number, customer_email, recipient_email, subject, 
                raw_issue_description, status, priority, sla_policy_id, assigned_agent_id,
                created_at, updated_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW(), NOW())
        """, (
            t_uuid, ticket_num, item['kullanici_maili'], item['kime'], item['konu'],
            item['sorun_aciklamasi'], 'resolved', 'medium', policy_id, assigned_id
        ))

        # Çözümü Vektör Tablosuna Ekle
        if item.get('cozum'):
            sol_id = str(uuid.uuid4())
            # NOT: Gerçek projede burada get_embedding() çağrılmalı
            cur.execute("""
                INSERT INTO ticket_solutions (id, ticket_id, problem_text, solution_text, created_at)
                VALUES (%s, %s, %s, %s, NOW())
            """, (sol_id, t_uuid, item['sorun_aciklamasi'], item['cozum']))

    print("4. Mesajlar ve Ekler (Attachments) bağlanıyor...")
    # Not: Arşivdeki attachments verisi eski ticket ID'leri içeriyor olabilir.
    # Biz burada dosya adından veya OCR metninden eşleştirme yapmalıyız.
    attachments = load_json('helpdesk-rag/db/archive/20_08_26/message_attachments_202608201206.json')
    
    for att in attachments:
        # Önce bu attachment için bir sistem mesajı oluştur (DB şemasına uygunluk için)
        # Attachment'ın bağlı olduğu ticket_id'yi bulmak için OCR metninden konu eşleştirmesi denenebilir
        # Veya rastgele bir ticket'a (örnek amaçlı) veya mesaj ID'si üzerinden gidilebilir.
        # Burada basitçe arşivdeki UUID'yi koruyarak ekliyoruz:
        cur.execute("""
            INSERT INTO message_attachments (id, message_id, file_name, file_path, file_type, ocr_extracted_text, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (att['id'], att['message_id'], att['file_name'], att['file_path'], att['file_type'], att['ocr_extracted_text'], att['created_at']))

    conn.commit()
    print("Migrasyon Tamamlandı!")

if __name__ == "__main__":
    run_migration()