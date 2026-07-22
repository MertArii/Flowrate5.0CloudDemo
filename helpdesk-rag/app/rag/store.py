"""pgvector üzerinde doküman/chunk saklama ve benzerlik araması."""
import psycopg
from pgvector.psycopg import register_vector
from app.config import settings


def _connect() -> psycopg.Connection:
    conn = psycopg.connect(settings.database_url)
    register_vector(conn)
    return conn


def add_document(source: str, title: str, chunks: list[tuple[str, list[float]]]) -> int:
    """chunks: [(içerik, embedding), ...] -> document_id döner."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO documents (source, title) VALUES (%s, %s) RETURNING id",
            (source, title),
        )
        doc_id = cur.fetchone()[0]
        for i, (content, emb) in enumerate(chunks):
            cur.execute(
                "INSERT INTO chunks (document_id, chunk_index, content, embedding) "
                "VALUES (%s, %s, %s, %s)",
                (doc_id, i, content, emb),
            )
        conn.commit()
    return doc_id


def search(query_embedding: list[float], top_k: int) -> list[dict]:
    """Cosine mesafesine göre en yakın chunk'ları döner."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            SELECT c.content, d.source, d.title,
                   1 - (c.embedding <=> %s::vector) AS score
            FROM chunks c
            JOIN documents d ON d.id = c.document_id
            ORDER BY c.embedding <=> %s::vector
            LIMIT %s
            """,
            (query_embedding, query_embedding, top_k),
        )
        rows = cur.fetchall()
    return [
        {"content": r[0], "source": r[1], "title": r[2], "score": float(r[3])}
        for r in rows
    ]
