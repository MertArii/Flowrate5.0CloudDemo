"""Qwen3.5'in multimodal desteğiyle görselden metin/açıklama çıkarır.
Ayrı bir OCR aracı gerekmez — model görseli doğrudan okur."""
from __future__ import annotations

from app.rag import ollama_client

_PROMPT = (
    "Bu görseldeki tüm metni (hata mesajları, kod, ekran içeriği vb.) ve "
    "önemli görsel detayları eksiksiz, Türkçe olarak açıkla. Sadece "
    "gördüklerini yaz, yorum katma."
)


async def describe_image(image_b64: str) -> str:
    msg = await ollama_client.chat(
        [{"role": "user", "content": _PROMPT}],
        images_b64=[image_b64],
    )
    return msg.get("content", "")
