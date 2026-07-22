"""Host'ta çalışan Ollama'ya ince bir istemci (embedding + chat)."""
from __future__ import annotations

import httpx
from app.config import settings


async def embed(text: str) -> list[float]:
    async with httpx.AsyncClient(timeout=60) as client:
        r = await client.post(
            f"{settings.ollama_base_url}/api/embeddings",
            json={"model": settings.embed_model, "prompt": text},
        )
        r.raise_for_status()
        return r.json()["embedding"]


async def chat(
    messages: list[dict],
    tools: list[dict] | None = None,
    fmt: str | None = None,
) -> dict:
    """Qwen3.5 native tool-calling destekler. tools verilirse model
    tool_calls döndürebilir; döndürmezse düz 'content' gelir.
    fmt='json' verilirse model geçerli JSON döndürmeye zorlanır."""
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
    async with httpx.AsyncClient(timeout=300) as client:
        r = await client.post(f"{settings.ollama_base_url}/api/chat", json=payload)
        r.raise_for_status()
        msg = r.json()["message"]
        # Nadiren model her şeyi 'thinking'e yazıp content'i boş bırakır; yedek.
        if not msg.get("content") and msg.get("thinking"):
            msg["content"] = msg["thinking"]
        return msg
