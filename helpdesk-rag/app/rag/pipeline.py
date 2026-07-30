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


async def answer(
    question: str,
    min_score: float | None = None,
    extra_context: str | None = None,
    images_b64: list[str] | None = None,
) -> dict:
    """extra_context: eklenen dosyadan çıkarılan metin (görsel açıklaması/
    doküman içeriği), bu tek cevap için bağlama eklenir.
    images_b64: verilirse Qwen3.5 görseli bu cevapta doğrudan da okur
    (multimodal) — extra_context'teki açıklamaya ek bir doğrulama katmanı."""
    q_emb = await ollama_client.embed(question)

    # İki katmanı birlikte getir; skora göre birleştir.
    hits = store.search_solutions(q_emb, settings.top_k)
    hits += store.search_knowledge(q_emb, settings.top_k)
    hits.sort(key=lambda h: h["score"], reverse=True)

    # Eşik: istekte gelen min_score önceliklidir; yoksa sunucu varsayılanı.
    esik = min_score if min_score is not None else settings.min_score

    # Opsiyonel eşik: altındaki parçaları ele. Hiçbiri geçemezse, modele hiç
    # sormadan reddet (hem hızlı hem uydurmayı garantili engeller).
    if esik > 0:
        hits = [h for h in hits if h["score"] >= esik]
        if not hits:
            return {
                "answer": "Bu konuda elimde bilgi yok, lütfen bir yetkiliye "
                          "yönlendireyim.",
                "sources": [],
            }
    hits = hits[: settings.top_k]

    context = "\n\n".join(f"[Kaynak: {h['source']}]\n{h['content']}" for h in hits)
    if extra_context:
        context += f"\n\n[Kaynak: eklenen dosya]\n{extra_context}"

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": f"Bağlam:\n{context}\n\nSoru: {question}"},
    ]
    reply = await ollama_client.chat(messages, images_b64=images_b64)
    return {
        "answer": reply.get("content", ""),
        "sources": [{"source": h["source"], "score": h["score"], "tip": h["tip"],
                     "ticket_id": h.get("ticket_id"),
                     "harici_ticket_no": h.get("harici_ticket_no")}
                    for h in hits],
    }
