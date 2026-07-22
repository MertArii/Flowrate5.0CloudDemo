"""Docker'SIZ hızlı yerel test — Mac mini gelmeden pipeline'ı denemek için.

Vektörleri Postgres yerine bellekte/JSON dosyasında tutar. Aynı ingest ->
retrieve -> Qwen3.5 -> kaynaklı cevap akışını çalıştırır. Prod'da store.py
(pgvector) kullanılacak; bu sadece hızlı deneme içindir.

Kurulum (kendi makinende, Docker gerekmez):
    python3 -m venv .venv && source .venv/bin/activate
    pip install httpx pypdf numpy
    ollama serve            # açık olmalı
    ollama pull qwen3.5     # zaten kurulu
    ollama pull bge-m3      # embedding

Kullanım:
    python local_demo.py ingest data/docs/sss.pdf
    python local_demo.py ask "İzin talebi nasıl açılır?"
"""
import json
import sys
from pathlib import Path

import httpx
import numpy as np
from pypdf import PdfReader

OLLAMA = "http://localhost:11434"
LLM_MODEL = "qwen3.5"
EMBED_MODEL = "bge-m3"
CHUNK_SIZE, CHUNK_OVERLAP, TOP_K = 800, 120, 5
STORE_PATH = Path("local_store.json")

SYSTEM_PROMPT = (
    "Sen bir kurumsal help desk asistanısın. SADECE verilen bağlamı kullanarak "
    "Türkçe cevap ver. Bağlamda cevap yoksa 'Bu konuda elimde bilgi yok, lütfen "
    "bir yetkiliye yönlendireyim.' de. Uydurma bilgi verme."
)


def embed(text: str) -> list[float]:
    r = httpx.post(f"{OLLAMA}/api/embeddings",
                   json={"model": EMBED_MODEL, "prompt": text}, timeout=60)
    r.raise_for_status()
    return r.json()["embedding"]


def chat(messages: list[dict]) -> str:
    r = httpx.post(f"{OLLAMA}/api/chat",
                   json={"model": LLM_MODEL, "messages": messages, "stream": False},
                   timeout=300)
    r.raise_for_status()
    return r.json()["message"]["content"]


def chunk_text(text: str) -> list[str]:
    text = " ".join(text.split())
    out, start = [], 0
    while start < len(text):
        out.append(text[start:start + CHUNK_SIZE])
        start += CHUNK_SIZE - CHUNK_OVERLAP
    return [c for c in out if c.strip()]


def read_file(path: str) -> str:
    if path.lower().endswith(".pdf"):
        return "\n".join((p.extract_text() or "") for p in PdfReader(path).pages)
    return Path(path).read_text(encoding="utf-8")


def load_store() -> list[dict]:
    return json.loads(STORE_PATH.read_text()) if STORE_PATH.exists() else []


def cmd_ingest(path: str):
    store = load_store()
    for i, piece in enumerate(chunk_text(read_file(path))):
        store.append({"source": Path(path).name, "content": piece,
                      "embedding": embed(piece)})
    STORE_PATH.write_text(json.dumps(store))
    print(f"OK: {Path(path).name} indekslendi. Toplam chunk: {len(store)}")


def cmd_ask(question: str):
    store = load_store()
    if not store:
        print("Önce 'ingest' ile doküman ekle."); return
    q = np.array(embed(question))
    mat = np.array([s["embedding"] for s in store])
    sims = mat @ q / (np.linalg.norm(mat, axis=1) * np.linalg.norm(q) + 1e-9)
    top = sims.argsort()[::-1][:TOP_K]

    context = "\n\n".join(f"[Kaynak: {store[i]['source']}]\n{store[i]['content']}"
                          for i in top)
    answer = chat([
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": f"Bağlam:\n{context}\n\nSoru: {question}"},
    ])
    print("\n=== CEVAP ===\n" + answer)
    print("\n=== KAYNAKLAR ===")
    for i in top:
        print(f"  - {store[i]['source']}  (benzerlik: {sims[i]:.3f})")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(1)
    cmd, arg = sys.argv[1], sys.argv[2]
    {"ingest": cmd_ingest, "ask": cmd_ask}[cmd](arg)
