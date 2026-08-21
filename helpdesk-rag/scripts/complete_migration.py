import json
import uuid
import psycopg2
import requests
from datetime import datetime, timedelta
import random

# --- YAPILANDIRMA ---
DB_PARAMS = {
    "dbname": "helpdesk",
    "user": "helpdesk",
    "password": "demopw",
    "host": "127.0.0.1",
    "port": 5433
}

OLLAMA_URL = "http://localhost:11434/api/embeddings"
EMBED_MODEL = "bge-m3"

def get_embedding(text):
    if not text or len(text.strip()) == 0: return None
    try:
        r = requests.post(OLLAMA_URL, json={"model": EMBED_MODEL, "prompt": text}, timeout=60)
        return r.json()["embedding"]
    except: return None

def parse_interval(inv_str):
    if not inv_str or inv_str == 'null': return timedelta(hours=24) # Default 1 gün
    try:
        h, m, s = map(int, inv_str.split(':'))
        return timedelta(hours=h, minutes=m, seconds=s)
    except: return timedelta(hours=24)

def load_json(path):
    print(f"Okunuyor: {path}")
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        return data[list(data.keys())[0]] if isinstance(data, dict) else data

def run_migration():
    conn = None
    try:
        conn = psycopg2.connect(**DB_PARAMS)
        cur = conn.cursor()
        print("1. Tablolar temizleniyor...")
        cur.execute("TRUNCATE tickets, ticket_messages, ticket_solutions, attachment_vectors, message_attachments, users, support_groups, sla_policies, routing_rules, classification_categories CASCADE;")

        # --- STATİK VERİLER ---
        print("2. Statik veriler yükleniyor (Null-Free Stratejisi)...")
        
        # Support Groups
        groups = load_json('helpdesk-rag/db/archive/20_08_26/support_groups_202608201205.json')
        for g in groups:
            cur.execute("""
                INSERT INTO support_groups (id, name, email_alias, description) 
                VALUES (%s, %s, %s, %s)
            """, (g['id'], g['name'], g.get('email_alias', f"{g['name'].lower()}@sirket.com"), g.get('description', 'Genel destek grubu')))

        # Users
        users = load_json('helpdesk-rag/db/archive/20_08_26/users_202608201521.json')
        user_map = {}
        for u in users:
            cur.execute("""
                INSERT INTO users (id, email, full_name, title, department, region, role, support_group_id, uzman_kategorileri) 
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (u['id'], u['email'], u['full_name'], 
                 u.get('title') or ('Uzman' if u['role'] == 'agent' else 'Kullanıcı'),
                 u.get('department') or 'Genel',
                 u.get('region') or 'Merkez Ofis',
                 u['role'], u.get('support_group_id'), u.get('uzman_kategorileri')))
            user_map[u['full_name'].lower().split()[0]] = u # İlk isimden eşleme için

        # SLA Policies
        policies = load_json('helpdesk-rag/db/archive/20_08_26/sla_policies_202608201205.json')
        policy_map = {}
        for p in policies:
            cur.execute("""
                INSERT INTO sla_policies (id, level_int, level_name, priority_key, response_target, workaround_target, resolution_target) 
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (p['id'], p['level_int'], p['level_name'], p['priority_key'], 
                 p.get('response_target', '01:00:00'), p.get('workaround_target', '04:00:00'), p['resolution_target']))
            policy_map[p['level_int']] = p

        # Routing Rules & Categories
        for r in load_json('helpdesk-rag/db/archive/20_08_26/routing_rules_202608201205.json'):
            cur.execute("INSERT INTO routing_rules (id, rule_name, target_group_id, is_active) VALUES (%s, %s, %s, %s)", (r['id'], r['rule_name'], r['target_group_id'], True))
        for c in load_json('helpdesk-rag/db/archive/20_08_26/classification_categories_202608201204.json'):
            cur.execute("INSERT INTO classification_categories (id, category_key, aciklama) VALUES (%s, %s, %s)", (c['id'], c['category_key'], c['aciklama']))

        # --- SLA TICKETLARI ---
        print("3. SLA Ticketları ve Çözümler (7168 kayıt için tam mapping)...")
        sla_data = load_json('helpdesk-rag/sla/emails_sla_seviyeli.json')
        priority_levels = {1: "urgent", 2: "high", 3: "medium", 4: "low", 5: "planned"}

        for item in sla_data: # Tüm 7168 kayıt işleniyor
            t_id = str(uuid.uuid4())
            created_at = datetime.now() - timedelta(days=random.randint(1, 30), hours=random.randint(1, 23))
            
            level = item.get('sla_level_normalize', 3)
            p_info = policy_map.get(level, list(policy_map.values())[0])
            
            # Agent/Grup Eşleme
            assigned_agent_id, assigned_group_id = None, None
            prefix = str(item.get('atanan_kisi', '')).split('.')[0].lower()
            if prefix in user_map:
                assigned_agent_id = user_map[prefix]['id']
                assigned_group_id = user_map[prefix].get('support_group_id')

            # --- NULL KORUMALI DEĞERLER ---
            subject = item.get('konu') or item.get('sorun_aciklamasi') or 'Başlıksız Talep'
            description = item.get('sorun_aciklamasi') or item.get('konu') or 'Açıklama belirtilmemiş'
            customer_email = item.get('kullanici_maili') or 'bilinmeyen@sirket.com'
            recipient_email = item.get('kime') or 'destek@sirket.com'
            region = item.get('bolge') or 'Genel'

            # --- SLA VE DEADLINE MANTIĞI ---
            res_target = parse_interval(p_info['resolution_target'])
            res_deadline = created_at + res_target
            
            # Rastgele SLA İhlali (%6 olasılık)
            is_breached = random.random() < 0.06
            if is_breached:
                resolved_at = res_deadline + timedelta(hours=random.randint(1, 48))
                sla_status = 'outside_sla'
            else:
                resolved_at = created_at + (res_target * random.uniform(0.1, 0.9))
                sla_status = 'within_sla'

            cur.execute("""
                INSERT INTO tickets (
                    id, ticket_number, customer_email, recipient_email, subject, raw_issue_description, 
                    region, status, priority, assigned_group_id, assigned_agent_id, created_at, updated_at, 
                    resolved_at, sla_policy_id, response_deadline, resolution_deadline, sla_status, total_paused_duration
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                t_id, int(item.get('ticket_id', 0)), 
                customer_email, recipient_email, subject[:255], description,
                region, 'resolved', priority_levels.get(level, 'medium'),
                assigned_group_id, assigned_agent_id,
                created_at, resolved_at, resolved_at,
                p_info['id'], created_at + timedelta(hours=1), res_deadline,
                sla_status, '00:00:00'
            ))

            # 1. Çözüm Vektörü
            if item.get('cozum'):
                print(f"Çözüm vektörize ediliyor: Ticket {item.get('ticket_id')}")
                emb = get_embedding(item['cozum'])
                cur.execute("INSERT INTO ticket_solutions (id, ticket_id, problem_text, solution_text, embedding) VALUES (%s, %s, %s, %s, %s)",
                           (str(uuid.uuid4()), t_id, description, item['cozum'], emb))

            # 2. Sanal Ek ve Vektörü (Sorun Açıklaması)
            msg_id = str(uuid.uuid4())
            cur.execute("INSERT INTO ticket_messages (id, ticket_id, sender_email, sender_type, message_body, created_at) VALUES (%s, %s, %s, %s, %s, %s)",
                       (msg_id, t_id, customer_email, 'customer', description, created_at))
            
            att_id = str(uuid.uuid4())
            file_name = f"issue_desc_{item.get('ticket_id')}.txt"
            cur.execute("INSERT INTO message_attachments (id, message_id, file_name, file_path, file_type, ocr_extracted_text, created_at) VALUES (%s, %s, %s, %s, %s, %s, %s)",
                       (att_id, msg_id, file_name, f"/virtual/{file_name}", "text/plain", description, created_at))
            
            print(f"Sanal ek vektörize ediliyor: Ticket {item.get('ticket_id')}")
            att_emb = get_embedding(description)
            if att_emb:
                cur.execute("""
                    INSERT INTO attachment_vectors (id, attachment_id, ticket_id, source, chunk_content, embedding, chunk_index, created_at) 
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """, (str(uuid.uuid4()), att_id, t_id, file_name, description, att_emb, 0, created_at))

        # --- ARŞİV VERİLERİ ---
        print("4. Arşiv mesajları ve ekleri bağlanıyor...")
        legacy_t_id = str(uuid.uuid4())
        cur.execute("""
            INSERT INTO tickets (id, ticket_number, customer_email, recipient_email, subject, raw_issue_description, status) 
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (legacy_t_id, 99999, 'archive@sirket.com', 'destek@sirket.com', 'ARŞİV', 'Eski Mesajlar', 'closed'))

        for m in load_json('helpdesk-rag/db/archive/20_08_26/ticket_messages_202608201128.json'):
            cur.execute("""
                INSERT INTO ticket_messages (id, ticket_id, sender_email, sender_type, message_body, created_at) 
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (m['id'], legacy_t_id, m['sender_email'], m['sender_type'], m['message_body'], m['created_at']))

        for att in load_json('helpdesk-rag/db/archive/20_08_26/message_attachments_202608201206.json'):
            cur.execute("""
                INSERT INTO message_attachments (id, message_id, file_name, file_path, file_type, ocr_extracted_text) 
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (att['id'], att['message_id'], att['file_name'], att['file_path'], att['file_type'], att.get('ocr_extracted_text', 'OCR yok')))

        conn.commit()
        print("\nTEBRİKLER: Veritabanı %100'e yakın doluluk oranıyla ve SLA uyumlu olarak hazırlandı.")

    except Exception as e:
        print(f"HATA: {e}")
        if conn: conn.rollback()
    finally:
        if conn: conn.close()

if __name__ == "__main__":
    run_migration()