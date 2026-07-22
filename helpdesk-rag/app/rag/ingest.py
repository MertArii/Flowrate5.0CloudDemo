"""Doküman -> parçalama (chunking) -> embedding -> pgvector."""
from pypdf import PdfReader
from app.config import settings
from app.rag import ollama_client, store


def chunk_text(text: str, size: int, overlap: int) -> list[str]:
    """Basit karakter-tabanlı, örtüşmeli parçalama. İleride cümle/başlık
    farkındalıklı bir splitter ile değiştirilebilir."""
    text = " ".join(text.split())
    chunks, start = [], 0
    while start < len(text):
        end = start + size
        chunks.append(text[start:end])
        start = end - overlap
    return [c for c in chunks if c.strip()]


def read_file(path: str) -> str:
    if path.lower().endswith(".pdf"):
        reader = PdfReader(path)
        return "\n".join((page.extract_text() or "") for page in reader.pages)
    with open(path, encoding="utf-8") as f:
        return f.read()


async def ingest_file(path: str, source: str, title: str) -> int:
    raw = read_file(path)
    pieces = chunk_text(raw, settings.chunk_size, settings.chunk_overlap)
    embedded = [(p, await ollama_client.embed(p)) for p in pieces]
    return store.add_document(source, title, embedded)
