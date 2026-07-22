"""Sınıflandırma sonucunu ekip/uzmana yönlendirir (kural tabanlı)."""
from __future__ import annotations

from app.triage.classifier import RULES

GUVEN_ESIGI = RULES.get("guven_esigi", 0.6)
KATEGORILER = RULES["kategoriler"]


def route(classification: dict) -> dict:
    """classification -> yönlendirme kararı.
    Güven eşiğin altındaysa otomatik atama yapılmaz, insan triyajına düşer."""
    modul = classification["modul"]
    guven = classification["guven"]
    kat = KATEGORILER.get(modul, KATEGORILER["Diger"])

    dusuk_guven = guven < GUVEN_ESIGI
    belirsiz = modul == "Diger"

    if dusuk_guven or belirsiz:
        return {
            "ekip": "Triyaj Kuyruğu",
            "atanan_uzman": None,
            "otomatik_atandi": False,
            "sebep": (
                f"Güven düşük ({guven:.2f} < {GUVEN_ESIGI})"
                if dusuk_guven else "Kategori belirsiz (Diger)"
            ) + " — insan triyajı gerekiyor.",
        }

    uzmanlar = kat.get("uzmanlar", [])
    # Basit seçim: ilk uzman. (Sonraki adım: iş yükü/müsaitlik dengeleme.)
    atanan = uzmanlar[0] if uzmanlar else None
    return {
        "ekip": kat["ekip"],
        "atanan_uzman": atanan,
        "otomatik_atandi": atanan is not None,
        "sebep": f"{modul} -> {kat['ekip']} (güven {guven:.2f})",
    }
