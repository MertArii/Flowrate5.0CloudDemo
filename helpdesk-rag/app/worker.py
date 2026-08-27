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
from app.logging_config import get_logger
from app.rag import ingest, store

logger = get_logger(__name__)


async def _on_startup(ctx):
    """Worker başlarken DB connection pool'u açar."""
    logger.info("Worker başlatılıyor — DB pool açılıyor.")
    store.open_pool()


async def _on_shutdown(ctx):
    """Worker kapanırken DB connection pool'u kapatır."""
    logger.info("Worker kapatılıyor — DB pool kapatılıyor.")
    store.close_pool()


async def ingest_file_task(ctx, path: str, source: str, title: str) -> dict:
    """Bir dosyayı indeksler ve geçici kopyayı siler."""
    logger.info("Ingest başladı", extra={"source": source, "path": path})
    try:
        parca = await ingest.ingest_file(path, source=source, title=title)
        logger.info(
            "Ingest tamamlandı",
            extra={"source": source, "parca_sayisi": parca},
        )
        return {"parca_sayisi": parca, "source": source}
    except Exception:
        logger.exception("Ingest sırasında hata", extra={"source": source, "path": path})
        raise
    finally:
        if os.path.exists(path):
            os.unlink(path)
            logger.debug("Geçici dosya silindi", extra={"path": path})


class WorkerSettings:
    functions = [ingest_file_task]
    on_startup = _on_startup
    on_shutdown = _on_shutdown
    redis_settings = RedisSettings.from_dsn(settings.redis_url)
    job_timeout = 3600
    max_jobs = 2
    keep_result = 86400