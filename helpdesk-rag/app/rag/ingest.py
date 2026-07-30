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
    """PDF'i dosya UZANTISINA değil, gerçek içeriğine (baştaki '%PDF' imzası)
    bakarak tespit eder — dosya adı uzantısız/yanlış gelse bile çalışır.
    Metin dosyalarında UTF-8 başarısız olursa yaygın Türkçe kodlamaları
    (Windows-1254, ISO-8859-9) dener, o da olmazsa latin-1'e düşer (asla
    hata vermez, en kötü ihtimalle bazı karakterler bozuk görünür)."""
    with open(path, "rb") as f:
        head = f.read(5)

    if head.startswith(b"%PDF"):
        reader = PdfReader(path)
        text = "\n".join((page.extract_text() or "") for page in reader.pages)
        return _sanitize(text)

    with open(path, "rb") as f:
        raw = f.read()
    for enc in ("utf-8", "cp1254", "iso-8859-9"):
        try:
            return _sanitize(raw.decode(enc))
        except UnicodeDecodeError:
            continue
    return _sanitize(raw.decode("latin-1"))


def _sanitize(text: str) -> str:
    """Postgres'in TEXT sütunlarının kabul etmediği NUL (0x00) baytlarını
    temizler. Bazı karmaşık/gömülü fontlu PDF'lerde pypdf bunları üretebiliyor."""
    return text.replace("\x00", "")


async def ingest_file(path: str, source: str, title: str) -> int:
    """Dokümanı parçalayıp attachment_vectors'e (RAG Katman 2) yazar.
    Eklenen parça sayısını döner."""
    raw = read_file(path)
    pieces = chunk_text(raw, settings.chunk_size, settings.chunk_overlap)
    embedded = [(p, await ollama_client.embed(p)) for p in pieces]
    return store.add_knowledge_chunks(source or title, embedded)
