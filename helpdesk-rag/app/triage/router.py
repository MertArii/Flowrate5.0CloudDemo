"""Sınıflandırma sonucunu ekip/uzmana yönlendirir.

Atama sırası (hepsi DB'den, elle tutulan liste yok):
  1. ZORUNLU — kategori uyuşması: geçmişte bu kategoriyi gerçek çözmüş
     uzmanlar arasından seçilir. Hiç geçmiş yoksa tüm ekibe düşülür.
  2. Donanım'a özel (SAP'de asla) — bölge isteği varsa, aday havuzu içinde
     aynı bölgedeki uzmana öncelik verilir.
  3. Kalan adaylar arasında EN AZ İŞ YÜKÜ olan seçilir (açık ticket sayısı,
     kapananlar sayılmaz).
  4. Eşitlik varsa rastgele.
"""
from __future__ import annotations

import random

from app.config import settings

# Bölge eşleşmesi SADECE bu kategoride uygulanır (donanım = sahaya çıkan iş).
# SAP kategorilerinde asla uygulanmaz — SAP desteği bölgeden bağımsızdır.
BOLGE_ESLESMESI_UYGULANAN_MODUL = "IT-Donanim"

_kategoriler_cache: dict[str, dict] | None = None


def _get_kategoriler() -> dict[str, dict]:
    global _kategoriler_cache
    if _kategoriler_cache is None:
        from app.rag import store  # geç import: DB tabloları hazır olmadan yüklenmesin
        _kategoriler_cache = store.get_categories()
    return _kategoriler_cache


def _en_az_yuklu(store, adaylar: list[dict]) -> dict:
    """adaylar içinden en az açık ticket'ı olanı seçer; eşitlikte rastgele."""
    sayilar = store.get_open_ticket_counts([a["id"] for a in adaylar])
    min_sayi = min(sayilar.get(a["id"], 0) for a in adaylar)
    en_az = [a for a in adaylar if sayilar.get(a["id"], 0) == min_sayi]
    return random.choice(en_az)


def route(classification: dict, region: str | None = None) -> dict:
    """classification (+ opsiyonel region) -> yönlendirme kararı.
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
            "istenen_bolge": region,
            "bolge_eslesti": None,
            "uzmanlik_eslesti": None,
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
            "istenen_bolge": region,
            "bolge_eslesti": None,
            "uzmanlik_eslesti": None,
        }

    # 1) ZORUNLU: kategori uyuşması. Geçmişte bu kategoriyi çözmüş uzman
    # yoksa tüm ekibe düş (boş bırakmamak için).
    uzman_havuzu = store.get_agents_in_group(ekip)
    uzmanlik_eslesenler = store.get_agents_by_category(modul, ekip)
    uzmanlik_eslesti = bool(uzmanlik_eslesenler)
    pool = uzmanlik_eslesenler if uzmanlik_eslesti else uzman_havuzu

    if not pool:
        return {
            "ekip": ekip,
            "atanan_uzman": None,
            "uzman_adaylari": [],
            "otomatik_atandi": False,
            "sebep": f"{ekip} içinde uzman bulunamadı — insan triyajı gerekiyor.",
            "istenen_bolge": region,
            "bolge_eslesti": None,
            "uzmanlik_eslesti": uzmanlik_eslesti,
        }

    # 2) Donanım'a özel bölge önceliği (SAP'de asla uygulanmaz).
    bolge_eslesti = None
    if modul == BOLGE_ESLESMESI_UYGULANAN_MODUL and region:
        bolge_adaylari = [a for a in pool if a["region"] == region]
        if bolge_adaylari:
            pool = bolge_adaylari
            bolge_eslesti = True
        else:
            bolge_eslesti = False

    # 3-4) Kalan adaylar arasında en az iş yükü olan; eşitlikte rastgele.
    secilen = _en_az_yuklu(store, pool)

    sebep = f"{modul} -> {ekip} (güven {guven:.2f})"
    sebep += f" | uzmanlık eşleşti: {'evet' if uzmanlik_eslesti else 'hayır (tüm ekip)'}"
    if bolge_eslesti is not None:
        sebep += f" | bölge eşleşti: {'evet' if bolge_eslesti else 'hayır'}"

    return {
        "ekip": ekip,
        "atanan_uzman": secilen["email"],
        "uzman_adaylari": uzman_havuzu,  # tam ekip listesi (transparanlık için)
        "otomatik_atandi": True,
        "sebep": sebep,
        "istenen_bolge": region,
        "bolge_eslesti": bolge_eslesti,
        "uzmanlik_eslesti": uzmanlik_eslesti,
    }
