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
                   1 - (embedding <=> %s::vector) AS score
            FROM ticket_solutions
            WHERE embedding IS NOT NULL
            ORDER BY embedding <=> %s::vector
            LIMIT %s
            """,
            (query_embedding, query_embedding, top_k),
        )
        rows = cur.fetchall()
    return [{"content": f"Sorun: {r[0]}\nÇözüm: {r[1]}", "source": f"cozum:{r[2]}",
             "score": float(r[3]), "tip": "cozum"} for r in rows]


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


def create_ticket(
    customer_email: str, recipient_email: str, subject: str,
    raw_issue_description: str, extracted_category: str | None,
    region: str | None, status: str, priority: str,
    assigned_group_id: str | None,
) -> tuple[str, int]:
    """Ticket oluşturur, (id, ticket_number) döner."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO tickets
                (customer_email, recipient_email, subject, raw_issue_description,
                 extracted_category, region, status, priority, assigned_group_id)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
            RETURNING id, ticket_number
            """,
            (customer_email, recipient_email, subject, raw_issue_description,
             extracted_category, region, status, priority, assigned_group_id),
        )
        tid, tno = cur.fetchone()
        conn.commit()
    return str(tid), tno


def create_routing_log(
    ticket_id: str, decision_factors: dict,
    assigned_group_id: str | None, confidence_score: float,
) -> None:
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO routing_logs
                (ticket_id, decision_factors, assigned_group_id, confidence_score)
            VALUES (%s, %s, %s, %s)
            """,
            (ticket_id, json.dumps(decision_factors, ensure_ascii=False),
             assigned_group_id, confidence_score),
        )
        conn.commit()
