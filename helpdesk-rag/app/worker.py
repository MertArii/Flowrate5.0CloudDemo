"""Arka plan worker'ı (arq + Redis).

Büyük dokümanların ingest'i uzun sürer (her parça için embedding üretilir).
Bu işi API isteğinden ayırmak, kullanıcı isteklerinin bloke olmasını ve
timeout'a düşmesini engeller.

Çalıştırma:  arq app.worker.WorkerSettings
"""
from __future__ import annotations

import os

from arq.connections import RedisSettings

from app.config import settings
from app.rag import ingest


async def ingest_file_task(ctx, path: str, source: str, title: str) -> dict:
    """Bir dosyayı indeksler ve geçici kopyayı siler."""
    try:
        doc_id = await ingest.ingest_file(path, source=source, title=title)
    finally:
        if os.path.exists(path):
            os.unlink(path)
    return {"document_id": doc_id, "source": source}


class WorkerSettings:
    functions = [ingest_file_task]
    redis_settings = RedisSettings.from_dsn(settings.redis_url)
    # Büyük PDF'ler uzun sürebilir; cömert bir sınır.
    job_timeout = 3600
    max_jobs = 2          # Ollama'yı embedding istekleriyle boğmamak için
    keep_result = 86400   # sonuçlar 24 saat sorgulanabilir
