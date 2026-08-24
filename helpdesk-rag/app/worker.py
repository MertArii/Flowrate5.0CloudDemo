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
from app.rag import ingest , store


async def ingest_file_task(ctx, path: str, source: str, title: str) -> dict:
    """Bir dosyayı indeksler ve geçici kopyayı siler."""
async def _on_startup(ctx):
    store.open_pool()


async def _on_shutdown(ctx):
    store.close_pool()
    try:
        parca = await ingest.ingest_file(path, source=source, title=title)
    finally:
        if os.path.exists(path):
            os.unlink(path)
    return {"parca_sayisi": parca, "source": source}


class WorkerSettings:
    functions = [ingest_file_task]
    on_startup = _on_startup
    on_shutdown = _on_shutdown
    redis_settings = RedisSettings.from_dsn(settings.redis_url)
    job_timeout = 3600
    max_jobs = 2
    keep_result = 86400