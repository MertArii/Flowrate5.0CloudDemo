"""Sınıflandırma sonucunu ekip/uzmana yönlendirir.

Atama sırası:
  1. KESİN UZMANLIK ŞARTI: Uzmanın profilindeki "uzman_kategorileri" içinde modül açıkça bulunmalıdır veya geçmişte çözmüş olmalıdır. Eşleşme yoksa atama yapılmaz.
  2. Donanım'a özel (SAP'de asla) — bölge isteği varsa, aday havuzu içinde aynı bölgedeki uzmana öncelik verilir (İstanbul/Halkalı normalizasyonu uygulanır).
  3. Kalan adaylar arasında EN AZ İŞ YÜKÜ olan seçilir (açık ticket sayısı).
  4. Eşitlik varsa rastgele.
"""
from __future__ import annotations

import random

from app.config import settings
from app.logging_config import get_logger

logger = get_logger(__name__)

# Bölge eşleşmesi SADECE bu kategoride uygulanır (donanım = sahaya çıkan iş).
# SAP kategorilerinde asla uygulanmaz — SAP desteği bölgeden bağımsızdır.
BOLGE_ESLESMESI_UYGULANAN_MODUL = "IT-Donanim"


def _normalize_region(region: str | None) -> str | None:
    """Bölge ismindeki harf ve karakter farklarını giderir, Halkalı'yı İstanbul'a eşitler."""
    if not region:
        return None
    r = region.strip().lower().replace("i̇", "i").replace("ı", "i")
    if "halkal" in r or "istanbul" in r:
        return "istanbul"
    return r


def _get_kategoriler() -> dict[str, dict]:
    from app.rag import store  # geç import: DB tabloları hazır olmadan yüklenmesin
    return store.get_categories()


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
            "ekip_gorunum_adi": "Triyaj Kuyruğu",
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
    ekip_gorunum = kat["ekip_gorunum_adi"] if kat else None
    if not ekip:
        return {
            "ekip": "Triyaj Kuyruğu",
            "ekip_gorunum_adi": "Triyaj Kuyruğu",
            "atanan_uzman": None,
            "uzman_adaylari": [],
            "otomatik_atandi": False,
            "sebep": f"{modul} için tanımlı/bağlı ekip yok — insan triyajı gerekiyor.",
            "istenen_bolge": region,
            "bolge_eslesti": None,
            "uzmanlik_eslesti": None,
        }

    # 1) KESİN UZMANLIK ŞARTI
    uzman_havuzu = store.get_agents_in_group(ekip)
    
    # Kişinin özelliklerinde bu kategori tanımlı mı kontrol et (Öncelikli)
    pool = [a for a in uzman_havuzu if modul in (a.get("uzman_kategorileri") or [])]
    
    # Eğer özel atama yoksa, veritabanından geçmiş kayıtlara göre kontrol et
    if not pool:
        pool = store.get_agents_by_category(modul, ekip)
        
    uzmanlik_eslesti = bool(pool)

    # Eski koddaki "hiç uzman yoksa uzman_havuzu'na (tüm ekibe) düş" mantığı İPTAL edildi.
    if not pool:
        return {
            "ekip": ekip,
            "ekip_gorunum_adi": ekip_gorunum,
            "atanan_uzman": None,
            "uzman_adaylari": uzman_havuzu,
            "otomatik_atandi": False,
            "sebep": f"{ekip} grubu içinde {modul} modülü için atanmış bir uzman bulunamadı — insan triyajı gerekiyor.",
            "istenen_bolge": region,
            "bolge_eslesti": None,
            "uzmanlik_eslesti": False,
        }

    # 2) Donanım'a özel bölge önceliği (Halkalı ve İstanbul normalizasyonu ile)
    bolge_eslesti = None
    if modul == BOLGE_ESLESMESI_UYGULANAN_MODUL and region:
        region_norm = _normalize_region(region)
        bolge_adaylari = [
            a for a in pool
            if a.get("region") and _normalize_region(a.get("region")) == region_norm
        ]
        if bolge_adaylari:
            pool = bolge_adaylari
            bolge_eslesti = True
        else:
            bolge_eslesti = False

    # 3-4) Kalan adaylar arasında en az iş yükü olan; eşitlikte rastgele.
    secilen = _en_az_yuklu(store, pool)

    sebep = f"{modul} -> {ekip} (güven {guven:.2f}) | uzmanlık eşleşti: evet (kesin)"
    if bolge_eslesti is not None:
        sebep += f" | bölge eşleşti: {'evet' if bolge_eslesti else 'hayır'}"

    return {
        "ekip": ekip,
        "ekip_gorunum_adi": ekip_gorunum,
        "atanan_uzman": secilen["email"],
        "uzman_adaylari": uzman_havuzu,
        "otomatik_atandi": True,
        "sebep": sebep,
        "istenen_bolge": region,
        "bolge_eslesti": bolge_eslesti,
        "uzmanlik_eslesti": True,
    }