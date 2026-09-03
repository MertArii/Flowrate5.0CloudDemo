"""Ticket metnini yapılandırılmış sınıflandırmaya çevirir (Qwen3.5, JSON).

İki bağımsız kategori sistemi birlikte çalışır:
  1) classification_categories (modul) — KİŞİ/EKİP ATAMASI için. router.py
     bunu kullanır, bu turda hiç değişmedi.
  2) ust_kategoriler -> kategori_gruplari -> alt_kategoriler (+ sap_modules,
     sadece kategori_grubu='SAP Problemleri' ise) — SADECE ETİKETLEME için,
     atamayla ilgisi yok. Bu fonksiyon sadece İSİM döner (id değil) —
     id çözümlemesi (store.get_alt_kategori_id / get_sap_module_id) ticket
     gerçekten oluşturulurken service.py tarafında yapılır.

Kategori listeleri DB'den gelir — elle tutulan dosya yok, ÖNBELLEK de yok:
her classify() çağrısında taze çekilir (önbellek yüzünden saatlerce fark
edilmeyen bir yanlış-sınıflandırma hatası yaşanmıştı, bkz. proje geçmişi).
"""
from __future__ import annotations

import json
import logging

from app.rag import ollama_client

logger = logging.getLogger(__name__)

# 'Diger' bilerek DB'de yok: gerçek bir ekibe atanabilir kategori değil,
# "belirsiz/eşleşmiyor -> insan triyajı" için sabit bir sinyal.
_DIGER = {"aciklama": "Yukarıdakilere uymayan / belirsiz talepler"}

_SAP_PROBLEMLERI_GRUBU = "SAP Problemleri"


def _get_kategoriler() -> dict[str, dict]:
    from app.rag import store  # geç import: DB tabloları hazır olmadan yüklenmesin
    return {**store.get_categories(), "Diger": _DIGER}


def _build_agac(hierarchy: list[tuple[str, str, str]]) -> dict[str, dict[str, list[str]]]:
    """store.get_category_hierarchy()'nin düz (ust, grup, alt) tuple listesini
    {ust: {grup: [alt, alt, ...]}} yapısına çevirir — hem prompt metni hem
    doğrulama için kullanılır."""
    agac: dict[str, dict[str, list[str]]] = {}
    for ust, grup, alt in hierarchy:
        agac.setdefault(ust, {}).setdefault(grup, []).append(alt)
    return agac


def _build_kategori_metni(kategoriler: dict[str, dict]) -> str:
    return "\n".join(f"- {k}: {v['aciklama']}" for k, v in kategoriler.items())


def _build_etiketleme_metni(agac: dict[str, dict[str, list[str]]]) -> str:
    satirlar = []
    for ust, gruplar in agac.items():
        satirlar.append(f"{ust}:")
        for grup, alt_liste in gruplar.items():
            satirlar.append(f"  {grup}: {', '.join(alt_liste)}")
    return "\n".join(satirlar)


def _build_system(
    kategoriler: dict[str, dict],
    agac: dict[str, dict[str, list[str]]],
    sap_moduller: list[str],
) -> str:
    kategori_metni = _build_kategori_metni(kategoriler)
    etiketleme_metni = _build_etiketleme_metni(agac)
    sap_modul_metni = ", ".join(sap_moduller)

    return (
        "Sen bir help desk ticket sınıflandırıcısısın. Verilen ticket metnini "
        "analiz et ve SADECE geçerli JSON döndür. Alanlar:\n"
        '  "modul": aşağıdaki KATEGORİLER listesinden TAM BİRİNİN anahtarı '
        "(bu, ticket'ı hangi ekip/uzmanın çözeceğini belirler),\n"
        '  "oncelik": "1" | "2" | "3" | "4" | "5",\n'
        '  "istek_turu": "olay" | "planli_talep",\n'
        '  "ust_kategori": aşağıdaki ETİKETLEME AĞACI\'ndaki üç üst başlıktan '
        "TAM BİRİ (ARIZALAR / TALEPLER / TİNDİSO BAKIM),\n"
        '  "kategori_grubu": seçtiğin ust_kategori\'nin ALTINDAKİ gruplardan TAM BİRİ,\n'
        '  "alt_kategori": seçtiğin kategori_grubu\'nun ALTINDAKİ maddelerden TAM BİRİ,\n'
        '  "sap_modulu": SADECE kategori_grubu = "SAP Problemleri" ise, aşağıdaki '
        "SAP MODÜLLERİ listesinden TAM BİRİ; DİĞER TÜM DURUMLARDA null,\n"
        '  "ozet": sorunun tek cümlelik Türkçe özeti,\n'
        '  "guven": 0.0-1.0 arası, sınıflandırmaya ne kadar emin olduğun.\n\n'
        "Öncelik (oncelik) — Uyar Holding BT Olay ve Talep Yönetimi Prosedürü'ndeki "
        "SLA önceliklendirme tablosuna göre KAPSAMA (kaç kişiyi/hangi süreci "
        "etkilediğine) bak, sadece kategoriye değil:\n"
        '  "1" (Kritik): Holding/şirket genelini veya kritik iş sürecini tamamen durduran '
        "(ör. SAP tamamen erişilemez, tüm e-posta çalışmıyor, firewall arızası, tüm "
        "internet kesildi, KRİTİK SUNUCU/DB arızası). Henüz gerçekleşmemiş, sadece "
        "ŞÜPHE bildirilen güvenlik olayları (ör. 'şüpheli bir mail aldım') bu seviyeye "
        "girmez, kapsamına göre 2 veya 3 ver.\n"
        '  "2" (Yüksek Öncelikli): Bir departmanı veya çok sayıda kullanıcıyı etkiliyor, tüm '
        "organizasyonu durdurmuyor (ör. bir departman SAP'e giremiyor, dosya sunucusuna "
        "erişilemiyor, gerçekleşmiş/doğrulanmış ama sınırlı kapsamlı bir güvenlik olayı).\n"
        '  "3" (Orta Öncelikli): Bireysel kullanıcılara ait, tek kullanıcının işini engelleyen sorun '
        "(ör. bilgisayar açılmıyor, yazıcı bağlantısı kopmuş, VPN çalışmıyor, tek bir "
        "kullanıcının bildirdiği şüpheli/phishing mail).\n"
        '  "4" (Düşük Öncelikli): İşi doğrudan durdurmayan, alternatifle devam edilebilen sorun '
        "(ör. bilgisayar yavaş, toner uyarısı, Excel makrosu hata veriyor, mobil e-posta "
        "senkronizasyonu hatası, masaüstü kısayolları görünmüyor, şifre değiştirme, "
        "YETKİ VE ERİŞİM TALEPLERİ — SAP dahil).\n"
        '  "5" (Planlı İş / Hizmet Talebi): Planlı, önceden talep edilen işler '
        "(ör. yeni çalışan için bilgisayar kurulumu, yeni yazılım kurulması, donanım sağlama).\n"
        "ÖZEL KURAL: Ticket bir GELİŞTİRME talebiyse (mevcut/yeni bir uygulamada "
        "değişiklik, yeni özellik veya entegrasyon geliştirme talebi), kapsamı ne "
        "olursa olsun oncelik HER ZAMAN '5'tir — prosedürün 4.1 maddesi gereği.\n\n"
        "ÖNEMLİ: Kullanıcılar gerçek kapsamı ne olursa olsun mailde/talepte sık sık "
        "'acil', 'ivedi', 'ASAP', çok sayıda ünlem işareti gibi kendi aciliyet "
        "iddiasını yazar. Bu ifadeleri YOK SAY — SADECE ticket metninde tarif "
        "edilen somut etki alanına bak.\n\n"
        "KONU TUZAĞI UYARISI: Bir ticket'ın konusu (örn. finans, ödeme, SAP) ile "
        "GERÇEK NİTELİĞİ (örn. güvenlik/phishing) farklı olabilir. Metinde phishing, "
        "oltalama, şüpheli gönderici/link/ek gibi GÜVENLİK ifadeleri varsa, konu "
        "başlığında finans/ödeme/SAP gibi terimler geçse bile modul='IT-Guvenlik' ve "
        "kategori_grubu='Güvenlik Arızaları' (ya da talepse 'Güvenlik Talepleri') "
        "seçilmelidir — SAP-FI gibi finans kategorisine sınıflandırma.\n\n"
        "İstek türü (istek_turu) — SADECE şunu ayırt eder: yeni bir şey mi "
        "TALEP ediliyor, yoksa var olan bir şey mi BOZUK/ARIZALI?\n"
        "  planli_talep: kullanıcı yeni bir şey istiyor — kurulum, yeni "
        "yazılım/donanım temini, yetki/erişim verilmesi, geliştirme talebi.\n"
        "  olay: var olan bir sistem/donanım/yazılım bozuk, yavaş, çalışmıyor "
        "veya hata veriyor.\n\n"
        "ETİKETLEME (ust_kategori / kategori_grubu / alt_kategori) — bu, kişi "
        "atamasıyla İLGİSİZ, sadece ticket'ın ne tür bir konu olduğunu etiketler. "
        "istek_turu='olay' ise ust_kategori genelde 'ARIZALAR', "
        "istek_turu='planli_talep' ise genelde 'TALEPLER' olur; işe giriş/çıkış "
        "ve kamera bakım süreçleri için 'TİNDİSO BAKIM' kullan. kategori_grubu ve "
        "alt_kategori SADECE aşağıdaki ağaçta GERÇEKTEN VAR OLAN bir kombinasyon "
        "olmalı, uydurma değer üretme:\n\n"
        f"{etiketleme_metni}\n\n"
        f'SAP MODÜLLERİ (sadece kategori_grubu="SAP Problemleri" ise kullanılır): '
        f"{sap_modul_metni}\n\n"
        f"KATEGORİLER (modul alanı için):\n{kategori_metni}\n\n"
        "Emin değilsen modul='Diger' ve düşük guven ver. Uydurma kategori kullanma."
    )


def _normalize_oncelik(value) -> str:
    """'1', 1, '1.0' gibi varyasyonları tek haneli '1'..'5' string'ine indirger."""
    text = str(value).strip()
    if "." in text:
        text = text.split(".", 1)[0]
    return text


def _dogrula_etiketleme(data: dict, agac: dict[str, dict[str, list[str]]], sap_moduller: list[str]) -> dict:
    """ust_kategori/kategori_grubu/alt_kategori/sap_modulu alanlarını DB'deki
    gerçek ağaca göre doğrular. Sadece İSİM doğrular, id çözmez — id
    çözümlemesi service.py'de store.get_alt_kategori_id/get_sap_module_id
    ile yapılır. Geçersiz/uydurma kombinasyonlarda, geçerli olan en geniş
    kademeyi koruyarak None'a düşer (tamamen atmak yerine)."""
    ust = data.get("ust_kategori")
    gruplar = agac.get(ust)
    if gruplar is None:
        return {"ust_kategori": None, "kategori_grubu": None, "alt_kategori": None, "sap_modulu": None}

    grup = data.get("kategori_grubu")
    alt_liste = gruplar.get(grup)
    if alt_liste is None:
        return {"ust_kategori": ust, "kategori_grubu": None, "alt_kategori": None, "sap_modulu": None}

    alt_ad = data.get("alt_kategori")
    if alt_ad not in alt_liste:
        return {"ust_kategori": ust, "kategori_grubu": grup, "alt_kategori": None, "sap_modulu": None}

    sap_kod = None
    if grup == _SAP_PROBLEMLERI_GRUBU:
        aday = data.get("sap_modulu")
        if aday in sap_moduller:
            sap_kod = aday

    return {"ust_kategori": ust, "kategori_grubu": grup, "alt_kategori": alt_ad, "sap_modulu": sap_kod}


async def classify(ticket_text: str) -> dict:
    from app.rag import store  # geç import

    kategoriler = _get_kategoriler()
    agac = _build_agac(store.get_category_hierarchy())
    sap_moduller = store.get_sap_modules()
    system = _build_system(kategoriler, agac, sap_moduller)

    msg = await ollama_client.chat(
        [
            {"role": "system", "content": system},
            {"role": "user", "content": ticket_text},
        ],
        fmt="json",
    )
    raw = (msg.get("content") or "{}").strip()
    if raw.startswith("```"):
        raw = raw.strip("`")
        if raw.startswith("json"):
            raw = raw[4:]
        raw = raw.strip()

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        logger.warning(
            "classify(): model çıktısı JSON parse edilemedi, varsayılanlara düşülüyor. raw=%r",
            raw,
        )
        data = {}

    modul = data.get("modul")
    if modul not in kategoriler:
        modul = "Diger"
    oncelik = _normalize_oncelik(data.get("oncelik", "3"))
    if oncelik not in ("1", "2", "3", "4", "5"):
        oncelik = "3"
    istek_turu = data.get("istek_turu", "olay")
    if istek_turu not in ("olay", "planli_talep"):
        istek_turu = "olay"
    try:
        guven = float(data.get("guven", 0.0))
    except (TypeError, ValueError):
        guven = 0.0
    guven = max(0.0, min(1.0, guven))

    etiketleme = _dogrula_etiketleme(data, agac, sap_moduller)

    return {
        "modul": modul,
        "oncelik": oncelik,
        "istek_turu": istek_turu,
        **etiketleme,  # ust_kategori, kategori_grubu, alt_kategori, sap_modulu (hepsi isim, id değil)
        "ozet": data.get("ozet", ""),
        "guven": guven,
    }