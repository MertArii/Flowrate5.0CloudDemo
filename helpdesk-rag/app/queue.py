"""Kuyruk erişimi (arq/Redis) — Redis yoksa zarifçe devre dışı kalır.

Geliştirme ortamında Redis çalışmıyor olabilir; bu durumda enqueue_ingest
None döner ve API senkron indekslemeye düşer.

Havuz önbelleğe alınır: her istekte yeniden bağlanmak (ve Redis yoksa her
seferinde yeniden denemeyi beklemek) pahalıdır.
"""
from __future__ import annotations

import time

from arq import create_pool
from arq.connections import RedisSettings
from arq.jobs import Job

from app.config import settings

# Redis yoksa istekleri uzun süre bekletmemek için kısa deneme/zaman aşımı.
_REDIS_SETTINGS = RedisSettings.from_dsn(settings.redis_url)
_REDIS_SETTINGS.conn_retries = 1
_REDIS_SETTINGS.conn_timeout = 2

_pool_cache = None
_son_hata_zamani = 0.0
_HATA_BEKLEME = 30.0  # başarısızlıktan sonra bu kadar saniye yeniden deneme


async def get_pool():
    """Önbellekli Redis havuzu; erişilemezse None."""
    global _pool_cache, _son_hata_zamani
    if _pool_cache is not None:
        return _pool_cache
    if time.monotonic() - _son_hata_zamani < _HATA_BEKLEME:
        return None  # yakın zamanda başarısız oldu, boşuna bekletme
    try:
        _pool_cache = await create_pool(_REDIS_SETTINGS)
        return _pool_cache
    except Exception:
        _son_hata_zamani = time.monotonic()
        return None


async def close_pool() -> None:
    global _pool_cache
    if _pool_cache is not None:
        await _pool_cache.aclose()
        _pool_cache = None


async def enqueue_ingest(path: str, source: str, title: str) -> str | None:
    """İşi kuyruğa alır, job_id döner. Redis yoksa None."""
    pool = await get_pool()
    if pool is None:
        return None
    job = await pool.enqueue_job("ingest_file_task", path, source, title)
    return job.job_id if job else None


async def job_status(job_id: str) -> dict | None:
    """İşin durumu ve (bittiyse) sonucu. Redis yoksa None."""
    pool = await get_pool()
    if pool is None:
        return None
    job = Job(job_id, pool)
    durum = await job.status()
    sonuc = None
    if durum == "complete":
        try:
            sonuc = await job.result(timeout=1)
        except Exception as e:
            sonuc = {"hata": str(e)}
    return {"job_id": job_id, "durum": durum, "sonuc": sonuc}
