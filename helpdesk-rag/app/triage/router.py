"""Sınıflandırma sonucunu ekip/uzmana yönlendirir.

Kategori->ekip eşlemesi DB'den (classification_categories), aday uzman
listesi de DB'den (gerçek support_group üyeliği) gelir — elle tutulan liste
yok. Güven eşiği bir ayar olduğu için config'te (MIN_SCORE ile aynı mantık).
"""
from __future__ import annotations

from app.config import settings

_kategoriler_cache: dict[str, dict] | None = None


def _get_kategoriler() -> dict[str, dict]:
    global _kategoriler_cache
    if _kategoriler_cache is None:
        from app.rag import store  # geç import: DB tabloları hazır olmadan yüklenmesin
        _kategoriler_cache = store.get_categories()
    return _kategoriler_cache


def route(classification: dict) -> dict:
    """classification -> yönlendirme kararı.
    Güven eşiğin altındaysa veya kategori tanımsızsa otomatik atama
    yapılmaz, insan triyajına düşer."""
    from app.rag import store  # geç import

    modul = classification["modul"]
    guven = classification["guven"]
    esik = settings.triage_guven_esigi

    dusuk_guven = guven < esik
    belirsiz = modul == "Diger"

    if dusuk_guven or belirsiz:
        return {
            "ekip": "Triyaj Kuyruğu",
            "atanan_uzman": None,
            "uzman_adaylari": [],
            "otomatik_atandi": False,
            "sebep": (
                f"Güven düşük ({guven:.2f} < {esik})"
                if dusuk_guven else "Kategori belirsiz (Diger)"
            ) + " — insan triyajı gerekiyor.",
        }

    kat = _get_kategoriler().get(modul)
    ekip = kat["ekip"] if kat else None
    if not ekip:
        return {
            "ekip": "Triyaj Kuyruğu",
            "atanan_uzman": None,
            "uzman_adaylari": [],
            "otomatik_atandi": False,
            "sebep": f"{modul} için tanımlı/bağlı ekip yok — insan triyajı gerekiyor.",
        }

    # Adaylar = o ekibin GERÇEK üyeleri (DB), region bilgisiyle birlikte.
    # Varsayılan seçim: alfabetik ilk. Bölge eşleşmesi (donanım için)
    # service.py'de bu listenin region alanı üzerinden yapılır.
    adaylar = store.get_agents_in_group(ekip)
    atanan = adaylar[0]["email"] if adaylar else None
    return {
        "ekip": ekip,
        "atanan_uzman": atanan,
        "uzman_adaylari": adaylar,   # [{email, id, region}, ...]
        "otomatik_atandi": atanan is not None,
        "sebep": f"{modul} -> {ekip} (güven {guven:.2f})",
    }
