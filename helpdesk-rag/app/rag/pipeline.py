"""RAG sorgu akışı: soru -> retrieve -> Qwen3.5 -> kaynaklı cevap."""
from app.config import settings
from app.rag import ollama_client, store

SYSTEM_PROMPT = (
    "Sen bir kurumsal help desk asistanısın. Her zaman Türkçe, kibar ve kısa "
    "yanıt ver.\n"
    "- Kullanıcının mesajı bir BİLGİ sorusuysa: DOĞRUDAN cevabı ver. Aşağıdaki "
    "bağlamı kullan. Cevabı hemen ver; 'yardımcı olabilirim', 'başka bir konu' "
    "gibi gereksiz nezaket cümleleri, soruyu geri sorma veya kendini tanıtma "
    "EKLEME. Sadece sorulanı yanıtla.\n"
    "- Bağlamda cevap yoksa uydurma; sadece şunu yaz: 'Bu konuda elimde bilgi "
    "yok, lütfen bir yetkiliye yönlendireyim.'\n"
    "- SADECE mesaj tamamen bir selam/teşekkür ise (ör. yalnızca 'merhaba', "
    "'nasılsın', 'teşekkürler') kısa ve samimi karşılık ver. Bunun dışında her "
    "mesajı bilgi sorusu olarak ele al ve doğrudan cevapla."
)


async def answer(question: str) -> dict:
    q_emb = await ollama_client.embed(question)
    hits = store.search(q_emb, settings.top_k)

    context = "\n\n".join(
        f"[Kaynak: {h['source']}]\n{h['content']}" for h in hits
    )
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": f"Bağlam:\n{context}\n\nSoru: {question}"},
    ]
    reply = await ollama_client.chat(messages)
    return {
        "answer": reply.get("content", ""),
        "sources": [{"source": h["source"], "score": h["score"]} for h in hits],
    }
