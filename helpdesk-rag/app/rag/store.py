"""Veri katmanı — yeni 10 tablolu şema (UUID + çift katmanlı RAG).

RAG iki katman:
  Katman 1: ticket_solutions      (net sorun/çözüm çiftleri)
  Katman 2: attachment_vectors    (doküman parçaları; bağımsız KB dahil)
"""
from __future__ import annotations

import json

import psycopg
from pgvector.psycopg import register_vector

from app.config import settings


def _connect() -> psycopg.Connection:
    conn = psycopg.connect(settings.database_url)
    register_vector(conn)
    return conn


# ---- İndeksleme (KB doküman parçaları) --------------------------------------

def add_knowledge_chunks(source: str, chunks: list[tuple[str, list[float]]]) -> int:
    """Bağımsız bilgi bankası dokümanını attachment_vectors'e yazar
    (attachment_id/ticket_id NULL). Eklenen parça sayısını döner."""
    with _connect() as conn, conn.cursor() as cur:
        for i, (content, emb) in enumerate(chunks):
            cur.execute(
                """
                INSERT INTO attachment_vectors
                    (source, chunk_index, chunk_content, embedding)
                VALUES (%s, %s, %s, %s)
                """,
                (source, i, content, emb),
            )
        conn.commit()
    return len(chunks)


# ---- RAG arama (iki katman) -------------------------------------------------

def search_knowledge(query_embedding: list[float], top_k: int) -> list[dict]:
    """Katman 2: doküman parçaları."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            SELECT chunk_content,
                   COALESCE(source, 'ek') AS source,
                   1 - (embedding <=> %s::vector) AS score
            FROM attachment_vectors
            ORDER BY embedding <=> %s::vector
            LIMIT %s
            """,
            (query_embedding, query_embedding, top_k),
        )
        rows = cur.fetchall()
    return [{"content": r[0], "source": r[1], "score": float(r[2]), "tip": "dokuman"}
            for r in rows]


def search_solutions(query_embedding: list[float], top_k: int) -> list[dict]:
    """Katman 1: geçmiş net çözümler."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            SELECT problem_text, solution_text,
                   COALESCE(category, 'genel') AS category,
                   1 - (embedding <=> %s::vector) AS score,
                   ticket_id,
                   metadata->>'harici_no' AS harici_no
            FROM ticket_solutions
            WHERE embedding IS NOT NULL
            ORDER BY embedding <=> %s::vector
            LIMIT %s
            """,
            (query_embedding, query_embedding, top_k),
        )
        rows = cur.fetchall()
    return [{"content": f"Sorun: {r[0]}\nÇözüm: {r[1]}", "source": f"cozum:{r[2]}",
             "score": float(r[3]), "tip": "cozum",
             "ticket_id": str(r[4]) if r[4] else None,
             "harici_ticket_no": r[5]} for r in rows]


# ---- Destek grubu / ticket / routing log ------------------------------------

def get_or_create_support_group(name: str, description: str = "") -> str:
    """Grup adından UUID döner; yoksa oluşturur."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT id FROM support_groups WHERE name = %s", (name,))
        row = cur.fetchone()
        if row:
            return str(row[0])
        cur.execute(
            "INSERT INTO support_groups (name, description) VALUES (%s, %s) RETURNING id",
            (name, description),
        )
        gid = cur.fetchone()[0]
        conn.commit()
    return str(gid)


def get_user_id_by_email(email: str) -> str | None:
    """E-postadan users.id döner; yoksa None (uydurma/placeholder isim demektir)."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT id FROM users WHERE email = %s", (email,))
        row = cur.fetchone()
    return str(row[0]) if row else None


def get_agents_info(emails: list[str]) -> dict[str, dict]:
    """E-posta listesi -> {email: {id, region}}. Bölgesi olmayan uzmanlar
    (region=None) genel/bölgesiz yedek sayılır."""
    if not emails:
        return {}
    with _connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT email, id, region FROM users WHERE email = ANY(%s)", (emails,))
        rows = cur.fetchall()
    return {r[0]: {"id": str(r[1]), "region": r[2]} for r in rows}


def get_categories() -> dict[str, dict]:
    """Sınıflandırma kategorilerini DB'den çeker:
    {category_key: {aciklama, ekip, ekip_gorunum_adi}}.
    ekip=None ise gruba bağlanmamış demektir (o kategori güvenle otomatik
    atanamaz, çağıran taraf insan triyajına düşürmeli). ekip_gorunum_adi,
    gerçek support_group'tan bağımsız iş-türüne özel görünür isimdir
    (ör. donanım için "Donanım Destek Ekibi") — atama mantığını etkilemez,
    sadece API yanıtında gösterilir."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            SELECT cc.category_key, cc.aciklama, sg.name, cc.ekip_gorunum_adi
            FROM classification_categories cc
            LEFT JOIN support_groups sg ON sg.id = cc.ekip_group_id
            WHERE cc.is_active = true
            ORDER BY cc.category_key
            """
        )
        rows = cur.fetchall()
    return {r[0]: {"aciklama": r[1], "ekip": r[2], "ekip_gorunum_adi": r[3] or r[2]}
            for r in rows}


# ---- Admin: uzman/kategori yönetimi -----------------------------------------

def get_support_group_id_by_name(name: str) -> str | None:
    """Grup adından id döner; yoksa None. Elle ID kopyalama hatasını
    (yanlış grubun ID'sini girmek) önlemek için isimle çalışılır."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT id FROM support_groups WHERE name = %s", (name,))
        row = cur.fetchone()
    return str(row[0]) if row else None


def get_all_group_names() -> list[str]:
    with _connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT name FROM support_groups ORDER BY name")
        return [r[0] for r in cur.fetchall()]


def get_all_category_keys() -> list[str]:
    with _connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT category_key FROM classification_categories WHERE is_active = true ORDER BY category_key")
        return [r[0] for r in cur.fetchall()]


def create_agent(
    email: str, full_name: str, title: str | None, department: str | None,
    region: str | None, support_group_id: str, uzman_kategorileri: list[str] | None,
) -> str:
    """Yeni bir uzman (agent) ekler, users.id döner."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO users (email, full_name, title, department, region, role,
                                support_group_id, uzman_kategorileri)
            VALUES (%s,%s,%s,%s,%s,'agent',%s,%s)
            RETURNING id
            """,
            (email, full_name, title, department, region, support_group_id,
             uzman_kategorileri or None),
        )
        uid = cur.fetchone()[0]
        conn.commit()
    return str(uid)


def create_category(
    category_key: str, aciklama: str, ekip_group_id: str, ekip_gorunum_adi: str | None,
) -> str:
    """Yeni bir sınıflandırma kategorisi ekler, id döner."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO classification_categories (category_key, aciklama, ekip_group_id, ekip_gorunum_adi)
            VALUES (%s,%s,%s,%s)
            RETURNING id
            """,
            (category_key, aciklama, ekip_group_id, ekip_gorunum_adi),
        )
        cid = cur.fetchone()[0]
        conn.commit()
    return str(cid)


def get_agents_in_group(group_name: str) -> list[dict]:
    """Bir destek grubundaki TÜM uzmanları DB'den çeker (email, id, region).
    Elle tutulan bir liste dosyasından bağımsız — grup üyeliği
    değiştiğinde (yeni uzman eklendiğinde) otomatik günceldir."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            SELECT u.email, u.id, u.region
            FROM users u JOIN support_groups g ON g.id = u.support_group_id
            WHERE g.name = %s AND u.role = 'agent'
            ORDER BY u.email
            """,
            (group_name,),
        )
        rows = cur.fetchall()
    return [{"email": r[0], "id": str(r[1]), "region": r[2]} for r in rows]


def get_agents_by_category(category_key: str, group_name: str) -> list[dict]:
    """Bu kategoride uzman olan, bu ekipteki uzmanlar (email, id, region).

    Öncelik sırası:
      1) ELLE beyan edilmiş uzmanlık (users.uzman_kategorileri) — gerçek
         title'lardan türetilmiş, en güvenilir sinyal.
      2) Elle beyan yoksa: geçmişte bu kategoriyi gerçekten çözmüş uzmanlar
         (ticket geçmişi) — daha zayıf bir sezgi, az veri varsa yanıltıcı
         olabilir (ör. tek seferlik çapraz görevlendirme "uzmanlık" sanılabilir).

    Boş dönerse hiçbir sinyal yok demektir — çağıran taraf tüm ekibe
    (get_agents_in_group) düşmelidir."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            SELECT u.email, u.id, u.region
            FROM users u
            JOIN support_groups g ON g.id = u.support_group_id
            WHERE g.name = %s AND u.role = 'agent'
              AND u.uzman_kategorileri IS NOT NULL
              AND %s = ANY(u.uzman_kategorileri)
            ORDER BY u.email
            """,
            (group_name, category_key),
        )
        rows = cur.fetchall()
        if rows:
            return [{"email": r[0], "id": str(r[1]), "region": r[2]} for r in rows]

        cur.execute(
            """
            SELECT DISTINCT u.email, u.id, u.region
            FROM tickets t
            JOIN users u ON u.id = t.assigned_agent_id
            JOIN support_groups g ON g.id = u.support_group_id
            WHERE t.extracted_category = %s AND g.name = %s AND u.role = 'agent'
            ORDER BY u.email
            """,
            (category_key, group_name),
        )
        rows = cur.fetchall()
    return [{"email": r[0], "id": str(r[1]), "region": r[2]} for r in rows]


def get_open_ticket_counts(agent_ids: list[str]) -> dict[str, int]:
    """Verilen uzman id'leri için AÇIK (kapanmamış) ticket sayısı.
    'resolved'/'closed' sayılmaz — iş yükü sadece devam eden işlerden."""
    if not agent_ids:
        return {}
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            SELECT assigned_agent_id, count(*)
            FROM tickets
            WHERE assigned_agent_id = ANY(%s) AND status NOT IN ('resolved', 'closed')
            GROUP BY assigned_agent_id
            """,
            (agent_ids,),
        )
        rows = cur.fetchall()
    return {str(r[0]): r[1] for r in rows}


def create_ticket(
    customer_email: str, recipient_email: str, subject: str,
    raw_issue_description: str, extracted_category: str | None,
    region: str | None, status: str, priority: str,
    assigned_group_id: str | None,
    assigned_agent_id: str | None = None,
    sla_policy_id: str | None = None,
    response_deadline=None, workaround_deadline=None, resolution_deadline=None,
) -> tuple[str, int]:
    """Ticket oluşturur, (id, ticket_number) döner."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO tickets
                (customer_email, recipient_email, subject, raw_issue_description,
                 extracted_category, region, status, priority, assigned_group_id,
                 assigned_agent_id, sla_policy_id, response_deadline,
                 workaround_deadline, resolution_deadline)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            RETURNING id, ticket_number
            """,
            (customer_email, recipient_email, subject, raw_issue_description,
             extracted_category, region, status, priority, assigned_group_id,
             assigned_agent_id, sla_policy_id, response_deadline,
             workaround_deadline, resolution_deadline),
        )
        tid, tno = cur.fetchone()
        conn.commit()
    return str(tid), tno


# ---- SLA ----------------------------------------------------------------

def get_sla_policy(priority_key: str) -> dict | None:
    """priority_key ('urgent'|'high'|'medium'|'low'|'planned') -> sla_policies
    satırı. Hedefler timedelta olarak döner (psycopg interval->timedelta)."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, response_target, workaround_target, resolution_target,
                   is_business_days
            FROM sla_policies WHERE priority_key = %s
            """,
            (priority_key,),
        )
        row = cur.fetchone()
    if not row:
        return None
    return {
        "id": str(row[0]),
        "response_target": row[1],
        "workaround_target": row[2],
        "resolution_target": row[3],
        "is_business_days": row[4],
    }


def get_sla_violations() -> list[dict]:
    """Süresi geçmiş ama hâlâ açık olan ticket'lar (response veya resolution
    deadline'ı geçmiş, resolved_at boş)."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            SELECT t.id, t.ticket_number, t.subject, t.priority, t.status,
                   t.response_deadline, t.resolution_deadline, t.first_response_at,
                   t.assigned_agent_id, u.email
            FROM tickets t
            LEFT JOIN users u ON u.id = t.assigned_agent_id
            WHERE t.resolved_at IS NULL
              AND t.status NOT IN ('resolved', 'closed')
              AND (
                    (t.response_deadline IS NOT NULL AND t.first_response_at IS NULL
                     AND now() > t.response_deadline)
                 OR (t.resolution_deadline IS NOT NULL AND now() > t.resolution_deadline)
              )
            ORDER BY t.resolution_deadline NULLS LAST
            """
        )
        rows = cur.fetchall()
    return [
        {
            "ticket_id": str(r[0]), "ticket_number": r[1], "subject": r[2],
            "priority": r[3], "status": r[4],
            "response_deadline": r[5], "resolution_deadline": r[6],
            "first_response_at": r[7], "assigned_agent_email": r[9],
        }
        for r in rows
    ]


def create_routing_log(
    ticket_id: str, decision_factors: dict,
    assigned_group_id: str | None, confidence_score: float,
    assigned_agent_id: str | None = None,
) -> None:
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO routing_logs
                (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (ticket_id, json.dumps(decision_factors, ensure_ascii=False),
             assigned_group_id, assigned_agent_id, confidence_score),
        )
        conn.commit()


# ---- Mesajlar / ekler --------------------------------------------------

def create_ticket_message(
    ticket_id: str, sender_email: str, sender_type: str, message_body: str,
    ai_generated_draft: str | None = None, rag_sources_used: list | None = None,
) -> str:
    """ticket_messages'a bir satır ekler, message_id döner."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO ticket_messages
                (ticket_id, sender_email, sender_type, message_body,
                 ai_generated_draft, rag_sources_used)
            VALUES (%s,%s,%s,%s,%s,%s) RETURNING id
            """,
            (ticket_id, sender_email, sender_type, message_body,
             ai_generated_draft,
             json.dumps(rag_sources_used, ensure_ascii=False) if rag_sources_used else None),
        )
        mid = cur.fetchone()[0]
        conn.commit()
    return str(mid)


def create_attachment(
    message_id: str, file_name: str, file_path: str, file_type: str | None,
    ocr_extracted_text: str | None,
) -> str:
    """message_attachments'a bir satır ekler, attachment_id döner."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO message_attachments
                (message_id, file_name, file_path, file_type, ocr_extracted_text)
            VALUES (%s,%s,%s,%s,%s) RETURNING id
            """,
            (message_id, file_name, file_path, file_type, ocr_extracted_text),
        )
        aid = cur.fetchone()[0]
        conn.commit()
    return str(aid)


def add_attachment_vector(
    attachment_id: str, ticket_id: str, source: str, content: str,
    embedding: list[float],
) -> None:
    """Ekin metnini (görsel açıklaması / doküman metni) attachment_vectors'e
    yazar — RAG Katman 2'ye kalıcı olarak eklenmiş olur, ileride başka
    sorularda da bulunabilir."""
    with _connect() as conn:
        register_vector(conn)
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO attachment_vectors
                    (attachment_id, ticket_id, source, chunk_index, chunk_content, embedding)
                VALUES (%s,%s,%s,0,%s,%s)
                """,
                (attachment_id, ticket_id, source, content, embedding),
            )
            conn.commit()
