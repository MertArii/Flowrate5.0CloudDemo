"""Host'ta çalışan Ollama'ya ince bir istemci (embedding + chat).

Dayanıklılık:
  - Bağlantı hatalarında otomatik retry (exponential backoff, max 3 deneme)
  - Timeout'larda anlamlı hata mesajı
  - HTTP 4xx/5xx hatalarında model/payload ayrımı
  - Her hata durumunda yapılandırılmış loglama
"""
from __future__ import annotations

import asyncio

import httpx
from langfuse import observe

from app.config import settings
from app.exceptions import (
    OllamaModelError,
    OllamaTimeoutError,
    OllamaUnavailableError,
)
from app.logging_config import get_logger

logger = get_logger(__name__)

# Retry ayarları
_MAX_RETRIES = 3
_BACKOFF_BASE = 1.0  # saniye — 1s, 2s, 4s


async def _request_with_retry(
    method: str,
    url: str,
    *,
    json: dict,
    timeout: int,
    operation: str,
) -> dict:
    """Ollama'ya HTTP isteği gönderir; geçici hatalarda retry uygular.

    Kalıcı hatalar (4xx) retry'lanmaz — modelin/payload'ın yanlış
    olduğu durumlarda tekrar denemek anlamsız ve kaynak israfıdır.
    """
    last_exc: Exception | None = None

    for attempt in range(1, _MAX_RETRIES + 1):
        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                r = await client.request(method, url, json=json)
                r.raise_for_status()
                return r.json()

        except httpx.ConnectError as exc:
            last_exc = exc
            if attempt < _MAX_RETRIES:
                wait = _BACKOFF_BASE * (2 ** (attempt - 1))
                logger.warning(
                    "Ollama bağlantı hatası, %d/%d deneme — %.1fs sonra tekrar",
                    attempt,
                    _MAX_RETRIES,
                    wait,
                    extra={"operation": operation},
                )
                await asyncio.sleep(wait)
            else:
                logger.error(
                    "Ollama'ya bağlanılamadı (%d deneme sonra)",
                    _MAX_RETRIES,
                    extra={"operation": operation, "url": url},
                )
                raise OllamaUnavailableError(
                    f"Ollama sunucusuna bağlanılamıyor ({url}). "
                    f"Sunucu çalışıyor mu? ({exc})"
                ) from exc

        except httpx.TimeoutException as exc:
            last_exc = exc
            if attempt < _MAX_RETRIES:
                wait = _BACKOFF_BASE * (2 ** (attempt - 1))
                logger.warning(
                    "Ollama zaman aşımı, %d/%d deneme — %.1fs sonra tekrar",
                    attempt,
                    _MAX_RETRIES,
                    wait,
                    extra={"operation": operation},
                )
                await asyncio.sleep(wait)
            else:
                logger.error(
                    "Ollama zaman aşımı (%d deneme sonra)",
                    _MAX_RETRIES,
                    extra={"operation": operation, "timeout": timeout},
                )
                raise OllamaTimeoutError(
                    f"Ollama {timeout}s içinde yanıt vermedi ({operation}). "
                    f"Model çok yüklü olabilir."
                ) from exc

        except httpx.HTTPStatusError as exc:
            # 4xx → kalıcı hata, retry anlamsız
            status = exc.response.status_code
            body = exc.response.text[:500]
            logger.error(
                "Ollama HTTP %d hatası — %s",
                status,
                body,
                extra={"operation": operation, "status_code": status},
            )
            if 400 <= status < 500:
                raise OllamaModelError(
                    f"Ollama hatası (HTTP {status}): {body}"
                ) from exc
            # 5xx → sunucu hatası, retry denenebilir
            last_exc = exc
            if attempt < _MAX_RETRIES:
                wait = _BACKOFF_BASE * (2 ** (attempt - 1))
                logger.warning(
                    "Ollama sunucu hatası (HTTP %d), %d/%d deneme",
                    status,
                    attempt,
                    _MAX_RETRIES,
                    extra={"operation": operation},
                )
                await asyncio.sleep(wait)
            else:
                raise OllamaModelError(
                    f"Ollama sunucu hatası (HTTP {status}): {body}"
                ) from exc

    # Bu noktaya ulaşılmamalı ama savunma amaçlı:
    raise OllamaUnavailableError(
        f"Ollama isteği {_MAX_RETRIES} denemeden sonra başarısız oldu."
    ) from last_exc


@observe(name="ollama_embed")
async def embed(text: str) -> list[float]:
    """Metin → embedding vektörü. Ollama hatalarında retry uygular."""
    data = await _request_with_retry(
        "POST",
        f"{settings.ollama_base_url}/api/embeddings",
        json={"model": settings.embed_model, "prompt": text},
        timeout=60,
        operation="embed",
    )
    embedding = data.get("embedding")
    if not embedding:
        logger.error("Ollama embedding boş döndü", extra={"model": settings.embed_model})
        raise OllamaModelError(
            f"Ollama embedding boş döndü. Model '{settings.embed_model}' yüklü mü?"
        )
    return embedding


@observe(as_type="generation", name="ollama_chat")
async def chat(
    messages: list[dict],
    tools: list[dict] | None = None,
    fmt: str | None = None,
    images_b64: list[str] | None = None,
) -> dict:
    """Qwen3.5 native tool-calling destekler. tools verilirse model
    tool_calls döndürebilir; döndürmezse düz 'content' gelir.
    fmt='json' verilirse model geçerli JSON döndürmeye zorlanır.
    images_b64 verilirse (base64 string listesi) Qwen3.5'in multimodal
    desteğiyle görseli doğrudan okur — ayrı bir OCR adımı gerekmez."""
    payload: dict = {
        "model": settings.llm_model,
        "messages": messages,
        "stream": False,
        # Help desk için "thinking" modu kapalı: hızlı ve güvenilir düz cevap.
        # (Faz 2 tool-calling'de gerekirse açılabilir.)
        "think": False,
    }
    if tools:
        payload["tools"] = tools
    if fmt:
        payload["format"] = fmt
    if images_b64:
        # Ollama'da görsel, son user mesajının 'images' alanına eklenir.
        for m in reversed(payload["messages"]):
            if m["role"] == "user":
                m["images"] = images_b64
                break

    data = await _request_with_retry(
        "POST",
        f"{settings.ollama_base_url}/api/chat",
        json=payload,
        timeout=300,
        operation="chat",
    )
    msg = data.get("message", {})
    # Nadiren model her şeyi 'thinking'e yazıp content'i boş bırakır; yedek.
    if not msg.get("content") and msg.get("thinking"):
        msg["content"] = msg["thinking"]
    return msg
