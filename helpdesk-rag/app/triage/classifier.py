"""Ticket metnini yapılandırılmış sınıflandırmaya çevirir (Qwen3.5, JSON).

Kategori listesi DB'den (classification_categories) gelir — elle tutulan
dosya yok. İlk classify() çağrısında çekilip önbelleğe alınır (uygulama
başlarken DB henüz hazır olmayabileceği için import anında değil, ilk
kullanımda yüklenir)."""
from __future__ import annotations

import json

from app.rag import ollama_client

# 'Diger' bilerek DB'de yok: gerçek bir ekibe atanabilir kategori değil,
# "belirsiz/eşleşmiyor -> insan triyajı" için sabit bir sinyal.
_DIGER = {"aciklama": "Yukarıdakilere uymayan / belirsiz talepler"}

_kategoriler_cache: dict[str, dict] | None = None


def _get_kategoriler() -> dict[str, dict]:
    global _kategoriler_cache
    if _kategoriler_cache is None:
        from app.rag import store  # geç import: DB tabloları hazır olmadan yüklenmesin
        _kategoriler_cache = {**store.get_categories(), "Diger": _DIGER}
    return _kategoriler_cache


def invalidate_cache() -> None:
    """Yeni bir kategori eklendiğinde çağrılır (bkz. /admin/categories) —
    container'ı yeniden başlatmadan güncel listeyi bir sonraki çağrıda
    tazeler."""
    global _kategoriler_cache
    _kategoriler_cache = None


def _build_system(kategoriler: dict[str, dict]) -> str:
    kategori_listesi = "\n".join(f"- {k}: {v['aciklama']}" for k, v in kategoriler.items())
    return (
        "Sen bir help desk ticket sınıflandırıcısısın. Verilen ticket metnini "
        "analiz et ve SADECE geçerli JSON döndür. Alanlar:\n"
        '  "modul": aşağıdaki kategorilerden TAM BİRİNİN anahtarı,\n'
        '  "oncelik": "dusuk" | "orta" | "yuksek" | "kritik",\n'
        '  "ozet": sorunun tek cümlelik Türkçe özeti,\n'
        '  "guven": 0.0-1.0 arası, sınıflandırmaya ne kadar emin olduğun.\n\n'
        f"Kategoriler:\n{kategori_listesi}\n\n"
        "Emin değilsen modul='Diger' ve düşük guven ver. Uydurma kategori kullanma."
    )


async def classify(ticket_text: str) -> dict:
    kategoriler = _get_kategoriler()
    system = _build_system(kategoriler)

    msg = await ollama_client.chat(
        [
            {"role": "system", "content": system},
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
    if modul not in kategoriler:
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
