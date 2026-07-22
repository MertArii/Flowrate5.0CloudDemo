"""Ticket metnini yapılandırılmış sınıflandırmaya çevirir (Qwen3.5, JSON)."""
from __future__ import annotations

import json
from pathlib import Path

from app.rag import ollama_client

RULES = json.loads((Path(__file__).parent / "routing_rules.json").read_text())
KATEGORILER = {k: v["aciklama"] for k, v in RULES["kategoriler"].items()}

_kategori_listesi = "\n".join(f"- {k}: {a}" for k, a in KATEGORILER.items())

SYSTEM = (
    "Sen bir help desk ticket sınıflandırıcısısın. Verilen ticket metnini "
    "analiz et ve SADECE geçerli JSON döndür. Alanlar:\n"
    '  "modul": aşağıdaki kategorilerden TAM BİRİNİN anahtarı,\n'
    '  "oncelik": "dusuk" | "orta" | "yuksek" | "kritik",\n'
    '  "ozet": sorunun tek cümlelik Türkçe özeti,\n'
    '  "guven": 0.0-1.0 arası, sınıflandırmaya ne kadar emin olduğun.\n\n'
    f"Kategoriler:\n{_kategori_listesi}\n\n"
    "Emin değilsen modul='Diger' ve düşük guven ver. Uydurma kategori kullanma."
)


async def classify(ticket_text: str) -> dict:
    msg = await ollama_client.chat(
        [
            {"role": "system", "content": SYSTEM},
            {"role": "user", "content": ticket_text},
        ],
        fmt="json",
    )
    raw = msg.get("content") or "{}"
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        data = {}

    # Güvenli varsayılanlar + doğrulama
    modul = data.get("modul")
    if modul not in KATEGORILER:
        modul = "Diger"
    oncelik = data.get("oncelik", "orta")
    if oncelik not in ("dusuk", "orta", "yuksek", "kritik"):
        oncelik = "orta"
    try:
        guven = float(data.get("guven", 0.0))
    except (TypeError, ValueError):
        guven = 0.0
    guven = max(0.0, min(1.0, guven))

    return {
        "modul": modul,
        "oncelik": oncelik,
        "ozet": data.get("ozet", ""),
        "guven": guven,
    }
