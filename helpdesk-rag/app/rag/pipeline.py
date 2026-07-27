"""Çift katmanlı RAG: soru -> (çözümler + dokümanlar) -> Qwen -> kaynaklı cevap.

Katman 1 (ticket_solutions) net, doğrulanmış çözümlerdir.
Katman 2 (attachment_vectors) genel doküman bilgisidir.
"""
from __future__ import annotations

from app.config import settings
from app.rag import ollama_client, store

SYSTEM_PROMPT = (
    "Sen bir kurumsal help desk asistanısın. Her zaman Türkçe, kibar ve kısa "
    "yanıt ver.\n"
    "- Kullanıcının mesajı bir BİLGİ sorusuysa: DOĞRUDAN cevabı ver. Aşağıdaki "
    "bağlamı kullan. Gereksiz nezaket cümleleri veya kendini tanıtma ekleme.\n"
    "- Bağlamda cevap yoksa uydurma; sadece şunu yaz: 'Bu konuda elimde bilgi "
    "yok, lütfen bir yetkiliye yönlendireyim.'\n"
    "- SADECE mesaj tamamen bir selam/teşekkür ise kısa ve samimi karşılık ver."
)


async def answer(question: str) -> dict:
    q_emb = await ollama_client.embed(question)

    # İki katmanı birlikte getir; skora göre birleştir.
    hits = store.search_solutions(q_emb, settings.top_k)
    hits += store.search_knowledge(q_emb, settings.top_k)
    hits.sort(key=lambda h: h["score"], reverse=True)
    hits = hits[: settings.top_k]

    context = "\n\n".join(f"[Kaynak: {h['source']}]\n{h['content']}" for h in hits)
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": f"Bağlam:\n{context}\n\nSoru: {question}"},
    ]
    reply = await ollama_client.chat(messages)
    return {
        "answer": reply.get("content", ""),
        "sources": [{"source": h["source"], "score": h["score"], "tip": h["tip"]}
                    for h in hits],
    }
