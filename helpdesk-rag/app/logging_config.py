"""Merkezi loglama yapılandırması.

Uygulama genelinde tutarlı, yapılandırılmış loglama sağlar. Her modül
kendi logger'ını `get_logger(__name__)` ile alır — log çıktısında
modül adı görünür, sorun kaynağını bulmak kolaylaşır.

Ortam değişkeni:
    LOG_LEVEL=INFO   (varsayılan; DEBUG/WARNING/ERROR da kabul eder)
    LOG_FORMAT=json  (varsayılan; "text" olarak değiştirilebilir)

JSON formatı production ortamında (Docker/Cloud Logging) makine
tarafından okunabilir loglar üretir. Text formatı geliştirme ortamında
insan tarafından okunabilir loglar üretir.
"""
from __future__ import annotations

import logging
import os
import sys
import json as json_module
from datetime import datetime, timezone


# ---- JSON Formatter ---------------------------------------------------------

class JSONFormatter(logging.Formatter):
    """Yapılandırılmış JSON log satırları üretir.

    Her satır tek bir JSON nesnesidir — Cloud Logging, Datadog, ELK gibi
    araçlar tarafından doğrudan ayrıştırılabilir.
    """

    def format(self, record: logging.LogRecord) -> str:
        log_entry = {
            "timestamp": datetime.fromtimestamp(
                record.created, tz=timezone.utc
            ).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if record.exc_info and record.exc_info[0] is not None:
            log_entry["exception"] = self.formatException(record.exc_info)
        # Extra fields (request_id, ticket_id, vb.)
        for key in ("request_id", "ticket_id", "endpoint", "method",
                     "status_code", "duration_ms", "error_type"):
            value = getattr(record, key, None)
            if value is not None:
                log_entry[key] = value
        return json_module.dumps(log_entry, ensure_ascii=False)


# ---- Text Formatter ---------------------------------------------------------

class TextFormatter(logging.Formatter):
    """Geliştirme ortamı için okunabilir log formatı."""

    FORMAT = "%(asctime)s [%(levelname)-8s] %(name)s: %(message)s"

    def __init__(self):
        super().__init__(self.FORMAT, datefmt="%Y-%m-%d %H:%M:%S")


# ---- Setup -------------------------------------------------------------------

_configured = False


def setup_logging() -> None:
    """Uygulama başlangıcında bir kez çağrılır. Birden fazla çağrı güvenlidir."""
    global _configured
    if _configured:
        return
    _configured = True

    level_name = os.getenv("LOG_LEVEL", "INFO").upper()
    level = getattr(logging, level_name, logging.INFO)

    log_format = os.getenv("LOG_FORMAT", "json").lower()

    root = logging.getLogger()
    root.setLevel(level)

    # Mevcut handler'ları temizle (uvicorn'un varsayılanları ile çakışmasın)
    root.handlers.clear()

    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(level)

    if log_format == "text":
        handler.setFormatter(TextFormatter())
    else:
        handler.setFormatter(JSONFormatter())

    root.addHandler(handler)

    # Gürültülü kütüphanelerin seviyesini yükselt
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)
    logging.getLogger("watchfiles").setLevel(logging.WARNING)


def get_logger(name: str) -> logging.Logger:
    """Modül logger'ı döner. setup_logging() henüz çağrılmamışsa otomatik
    çağırır (import sırasında logger alan modüller için güvenli)."""
    if not _configured:
        setup_logging()
    return logging.getLogger(name)
