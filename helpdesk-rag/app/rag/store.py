"""Veri katmanı — yeni 10 tablolu şema (UUID + çift katmanlı RAG).

RAG iki katman:
  Katman 1: ticket_solutions      (net sorun/çözüm çiftleri)
  Katman 2: attachment_vectors    (doküman parçaları; bağımsız KB dahil)

Hata dayanıklılığı:
  - Pool bağlantı hataları → DatabaseConnectionError (503)
  - IntegrityError (unique/FK ihlali) → DatabaseIntegrityError (409)
  - Tüm DB hataları loglanır
"""
from __future__ import annotations

import json
from datetime import datetime

import psycopg
from pgvector.psycopg import register_vector
from psycopg_pool import ConnectionPool, PoolTimeout

from app.config import settings
from app.exceptions import DatabaseConnectionError, DatabaseIntegrityError
from app.logging_config import get_logger

logger = get_logger(__name__)


def _configure_connection(conn: psycopg.Connection) -> None:
    """Havuzdaki her YENİ bağlantı açıldığında BİR KEZ çalışır
    (pgvector tipini kaydeder). Her sorguda tekrar tekrar çağrılan
    register_vector(conn) yerine, sadece bağlantı ilk kurulduğunda yapılır."""
    register_vector(conn)


_pool = ConnectionPool(
    settings.database_url,
    min_size=getattr(settings, "db_pool_min_size", 2),
    max_size=getattr(settings, "db_pool_max_size", 10),
    configure=_configure_connection,
    open=False,  # uygulama başlarken open_pool() ile açık şekilde başlatılır
)


def open_pool() -> None:
    """Uygulama başlarken (main.py startup / worker startup) bir kez çağrılır."""
    # Havuz zaten açık durumdaysa işlemi atla, çökmesini engelle
    if getattr(_pool, "_opened", False):
        return
        
    try:
        _pool.open(wait=True)
        # Bağlantı testi
        with _pool.connection() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
        logger.info("DB connection pool açıldı ve bağlantı doğrulandı.")
    except Exception as exc:
        logger.error("DB pool açılamadı: %s", exc)
        raise DatabaseConnectionError(
            f"Veritabanı bağlantısı kurulamadı: {exc}"
        ) from exc


def close_pool() -> None:
    """Uygulama kapanırken bir kez çağrılır."""
    try:
        _pool.close()
        logger.info("DB connection pool kapatıldı.")
    except Exception:
        logger.exception("DB pool kapatılırken hata")


def _connect():
    """Her fonksiyon 'with _connect() as conn, conn.cursor() as cur:' şeklinde
    çalışır. YENİ bağlantı AÇMAZ — havuzdan ödünç alır; blok bitince bağlantı
    KAPANMAZ, havuza geri döner.

    Pool tükenmiş veya bağlantı kopmuşsa DatabaseConnectionError fırlatır."""
    try:
        return _pool.connection()
    except PoolTimeout as exc:
        logger.error("DB pool tükendi — tüm bağlantılar meşgul")
        raise DatabaseConnectionError(
            "Veritabanı bağlantı havuzu doldu. Lütfen daha sonra tekrar deneyin."
        ) from exc
    except psycopg.OperationalError as exc:
        logger.error("DB bağlantı hatası: %s", exc)
        raise DatabaseConnectionError(
            f"Veritabanına bağlanılamıyor: {exc}"
        ) from exc


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
    """Yeni bir uzman (agent) ekler, users.id döner.
    Aynı e-posta zaten varsa DatabaseIntegrityError (409) fırlatır."""
    try:
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
    except psycopg.errors.UniqueViolation as exc:
        logger.warning("Duplicate agent e-posta: %s", email)
        raise DatabaseIntegrityError(
            f"'{email}' e-postasıyla bir kullanıcı zaten mevcut."
        ) from exc


def create_category(
    category_key: str, aciklama: str, ekip_group_id: str, ekip_gorunum_adi: str | None,
) -> str:
    """Yeni bir sınıflandırma kategorisi ekler, id döner.
    Aynı category_key zaten varsa DatabaseIntegrityError (409) fırlatır."""
    try:
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
    except psycopg.errors.UniqueViolation as exc:
        logger.warning("Duplicate kategori: %s", category_key)
        raise DatabaseIntegrityError(
            f"'{category_key}' kategorisi zaten mevcut."
        ) from exc


def get_user_support_group_id(user_id: str) -> str | None:
    """Bir kullanıcının GERÇEK support_group_id'sini döner (varsa)."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT support_group_id FROM users WHERE id = %s", (user_id,))
        row = cur.fetchone()
    return str(row[0]) if row and row[0] else None


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


def get_category_hierarchy() -> list[tuple[str, str, str]]:
    """Prompt ve doğrulama için ust_kategori, kategori_grubu ve alt_kategori hiyerarşisini çeker."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            SELECT u.name, g.name, a.name
            FROM alt_kategoriler a
            JOIN kategori_gruplari g ON g.id = a.grup_id
            JOIN ust_kategoriler u ON u.id = g.ust_kategori_id
            WHERE a.is_active = true AND g.is_active = true AND u.is_active = true
            ORDER BY u.name, g.name, a.name
            """
        )
        return cur.fetchall()

def get_sap_modules() -> list[str]:
    with _connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT code FROM sap_modules ORDER BY code")
        return [r[0] for r in cur.fetchall()]

def get_alt_kategori_id(alt_kategori_name: str, kategori_grubu_name: str) -> str | None:
    if not alt_kategori_name or not kategori_grubu_name:
        return None
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            SELECT a.id
            FROM alt_kategoriler a
            JOIN kategori_gruplari g ON g.id = a.grup_id
            WHERE a.name = %s AND g.name = %s
            LIMIT 1
            """,
            (alt_kategori_name, kategori_grubu_name)
        )
        row = cur.fetchone()
        return str(row[0]) if row else None

def get_sap_module_id(code: str) -> str | None:
    if not code:
        return None
    with _connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT id FROM sap_modules WHERE code = %s LIMIT 1", (code,))
        row = cur.fetchone()
        return str(row[0]) if row else None

def create_ticket(
    customer_email: str, recipient_email: str, subject: str,
    raw_issue_description: str, extracted_category: str | None,
    region: str | None, status: str, priority: str,
    assigned_group_id: str | None,
    assigned_agent_id: str | None = None,
    sla_policy_id: str | None = None,
    response_deadline=None, workaround_deadline=None, resolution_deadline=None,
    sub_category_id: str | None = None,
    sap_module_id: str | None = None,
) -> tuple[str, int]:
    """Ticket oluşturur, (id, ticket_number) döner."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO tickets
                (customer_email, recipient_email, subject, raw_issue_description,
                 extracted_category, region, status, priority, assigned_group_id,
                 assigned_agent_id, sla_policy_id, response_deadline,
                 workaround_deadline, resolution_deadline, sub_category_id, sap_module_id)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            RETURNING id, ticket_number
            """,
            (customer_email, recipient_email, subject, raw_issue_description,
             extracted_category, region, status, priority, assigned_group_id,
             assigned_agent_id, sla_policy_id, response_deadline,
             workaround_deadline, resolution_deadline, sub_category_id, sap_module_id),
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


# ---- Geri bildirim -> doğrulanmış çözüm terfisi -----------------------

def get_ai_message(message_id: str) -> dict | None:
    """ai_bot mesajını (taslak + ait olduğu ticket) döner; yoksa None."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            SELECT ticket_id, sender_type, ai_generated_draft
            FROM ticket_messages WHERE id = %s
            """,
            (message_id,),
        )
        row = cur.fetchone()
    if not row:
        return None
    return {"ticket_id": str(row[0]), "sender_type": row[1], "ai_generated_draft": row[2]}


def get_ticket(ticket_id: str) -> dict | None:
    """Ticket'ın sorun metni + kategorisini döner; yoksa None."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT raw_issue_description, extracted_category FROM tickets WHERE id = %s",
            (ticket_id,),
        )
        row = cur.fetchone()
    if not row:
        return None
    return {"raw_issue_description": row[0], "extracted_category": row[1]}


def ticket_solution_exists(ticket_id: str) -> bool:
    """Bu ticket için zaten bir ticket_solutions kaydı var mı (tekrar eklememek için)."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT 1 FROM ticket_solutions WHERE ticket_id = %s LIMIT 1", (ticket_id,))
        return cur.fetchone() is not None


def solution_exists_for_harici_no(harici_no: str) -> bool:
    """metadata->>'harici_no' üzerinden daha önce içe aktarılmış mı kontrol eder
    — toplu import script'lerinin yarıda kesilip güvenle tekrar çalıştırılmasını
    (zaten işlenmiş kayıtları atlayarak) sağlar."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT 1 FROM ticket_solutions WHERE metadata->>'harici_no' = %s LIMIT 1",
            (harici_no,),
        )
        return cur.fetchone() is not None


def backfill_ticket_history(
    ticket_id: str, customer_id: str | None,
    created_at: datetime, resolved_at: datetime, sla_status: str,
) -> None:
    """Toplu/geçmiş veri importu için: create_ticket() her zaman 'şimdi
    açılan yeni ticket' varsayar (created_at=now, resolved_at=NULL). Geçmiş
    tarihli, zaten çözülmüş ticket'lar için bu alanları sonradan günceller."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            UPDATE tickets
            SET customer_id = %s, created_at = %s, updated_at = %s,
                resolved_at = %s, first_response_at = %s, sla_status = %s
            WHERE id = %s
            """,
            (customer_id, created_at, resolved_at, resolved_at, created_at, sla_status, ticket_id),
        )
        conn.commit()


def get_or_create_customer(email: str, full_name: str, region: str | None) -> str:
    """E-postadan müşteri users.id döner; yoksa role='customer' olarak oluşturur."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT id FROM users WHERE email = %s", (email,))
        row = cur.fetchone()
        if row:
            return str(row[0])
        cur.execute(
            """
            INSERT INTO users (email, full_name, role, region)
            VALUES (%s,%s,'customer',%s) RETURNING id
            """,
            (email, full_name, region),
        )
        uid = cur.fetchone()[0]
        conn.commit()
    return str(uid)


def create_ai_feedback(
    message_id: str, user_id: str, rating: int, feedback_text: str | None,
) -> str:
    """ai_feedbacks'e bir satır ekler, feedback_id döner."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO ai_feedbacks (message_id, user_id, rating, feedback_text)
            VALUES (%s,%s,%s,%s) RETURNING id
            """,
            (message_id, user_id, rating, feedback_text),
        )
        fid = cur.fetchone()[0]
        conn.commit()
    return str(fid)


def create_ticket_solution(
    ticket_id: str, category: str | None, problem_text: str, solution_text: str,
    embedding: list[float], metadata: dict,
) -> str:
    """Doğrulanmış bir sorun/çözüm çiftini ticket_solutions'a (RAG Katman 1)
    yazar — ileride benzer ticket'larda otomatik çözüm önerisi olarak bulunur.
    solution_id döner."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO ticket_solutions
                (ticket_id, category, problem_text, solution_text, embedding, metadata, is_verified)
            VALUES (%s,%s,%s,%s,%s,%s,true)
            RETURNING id
            """,
            (ticket_id, category, problem_text, solution_text, embedding,
             json.dumps(metadata, ensure_ascii=False)),
        )
        sid = cur.fetchone()[0]
        conn.commit()
    return str(sid)


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
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO attachment_vectors
                (attachment_id, ticket_id, source, chunk_index, chunk_content, embedding)
            VALUES (%s,%s,%s,0,%s,%s)
            """,
            (attachment_id, ticket_id, source, content, embedding),
        )
        conn.commit()
