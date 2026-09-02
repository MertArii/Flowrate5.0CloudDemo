"""Ticket metnini yapılandırılmış sınıflandırmaya çevirir (Qwen3.5, JSON).

Kategori listesi DB'den (classification_categories) gelir — elle tutulan
dosya yok, ÖNBELLEK de yok: her classify() çağrısında taze çekilir. Bu VM'de
bile DB sorgusu milisaniyeler sürer, model çağrısının (saniyeler) yanında
ihmal edilebilir — buna karşılık yeni eklenen bir kategori restart
beklemeden anında devreye girer (eskiden önbellek yüzünden saatlerce fark
edilmeyen bir yanlış-sınıflandırma hatasına yol açmıştı)."""
from __future__ import annotations
from langfuse import observe
import json

from app.logging_config import get_logger
from app.rag import ollama_client

logger = get_logger(__name__)

# 'Diger' bilerek DB'de yok: gerçek bir ekibe atanabilir kategori değil,
# "belirsiz/eşleşmiyor -> insan triyajı" için sabit bir sinyal.
_DIGER = {"aciklama": "Yukarıdakilere uymayan / belirsiz talepler"}


def _get_kategoriler() -> dict[str, dict]:
    from app.rag import store  # geç import: DB tabloları hazır olmadan yüklenmesin
    return {**store.get_categories(), "Diger": _DIGER}


def _build_system(kategoriler: dict[str, dict], hierarchy: list[tuple[str, str, str]], sap_modules: list[str]) -> str:
    kategori_listesi = "\n".join(f"- {k}: {v['aciklama']}" for k, v in kategoriler.items())
    hierarchy_listesi = "\n".join(f"- {u} > {g} > {a}" for u, g, a in hierarchy)
    sap_listesi = ", ".join(sap_modules)

    return (
        "Sen bir help desk ticket sınıflandırıcısısın. Verilen ticket metnini "
        "analiz et ve SADECE geçerli JSON döndür. Alanlar:\n"
        '  "modul": aşağıdaki Ana Kategoriler listesinden TAM BİRİNİN anahtarı,\n'
        '  "ust_kategori": "ARIZALAR" | "TALEPLER" | "TİNDİSO BAKIM",\n'
        '  "kategori_grubu": alt kategori hiyerarşisinden uygun grup,\n'
        '  "alt_kategori": seçilen gruba ait, hiyerarşi listesinde tam olarak geçen uygun alt kategori,\n'
        f'  "sap_modulu": sadece kategori_grubu "SAP Problemleri" ise şu listeden biri: {sap_listesi}. Aksi halde null,\n'
        '  "oncelik": "1" | "2" | "3" | "4" | "5",\n'
        '  "istek_turu": "olay" | "planli_talep",\n'
        '  "ozet": sorunun tek cümlelik Türkçe özeti,\n'
        '  "guven": 0.0-1.0 arası, sınıflandırmaya ne kadar emin olduğun.\n\n'
        "Öncelik (oncelik) — Uyar Holding BT Olay ve Talep Yönetimi Prosedürü'ndeki "
        "SLA önceliklendirme tablosuna göre KAPSAMA (kaç kişiyi/hangi süreci "
        "etkilediğine) bak, sadece kategoriye değil[cite: 1]:\n"
        '  "1" (Kritik): Holding/şirket genelini veya kritik iş sürecini tamamen durduran '
        "(ör. SAP tamamen erişilemez, tüm e-posta çalışmıyor, siber saldırı, firewall arızası)[cite: 1].\n"
        '  "2" (Yüksek Öncelikli): Bir departmanı veya çok sayıda kullanıcıyı etkiliyor, tüm '
        "organizasyonu durdurmuyor (ör. bir departman SAP'e giremiyor, dosya sunucusuna erişilemiyor)[cite: 1].\n"
        '  "3" (Orta Öncelikli): Bireysel kullanıcılara ait, tek kullanıcının işini engelleyen sorun '
        "(ör. bilgisayar açılmıyor, yazıcı bağlantısı kopmuş, VPN çalışmıyor)[cite: 1].\n"
        '  "4" (Düşük Öncelikli): İşi doğrudan durdurmayan, alternatifle devam edilebilen sorun '
        "(ör. bilgisayar yavaş, toner uyarısı, şifre değiştirme, yetki ve erişim talepleri)[cite: 1].\n"
        '  "5" (Planlı İş / Hizmet Talebi): Planlı, önceden talep edilen işler '
        "(ör. yeni çalışan için bilgisayar kurulumu, yeni yazılım kurulması, donanım sağlama)[cite: 1].\n"
        "ÖNEMLİ: Kullanıcılar gerçek kapsamı ne olursa olsun mailde/talepte sık sık "
        "'acil', 'ivedi', 'ASAP', çok sayıda ünlem işareti gibi kendi aciliyet "
        "iddiasını yazar[cite: 1]. Bu ifadeleri YOK SAY — SADECE ticket metninde tarif "
        "edilen somut etki alanına bak[cite: 1]. Kullanıcı 'acil, bilgisayarım açılmıyor' derse ve bu tek "
        "bir kişiyi etkiliyorsa oncelik yine '3'tür, kullanıcı 'acil' dedi diye '1' "
        "verme[cite: 1]. Tersi de geçerli: kullanıcı 'acelesi yok' dese bile kapsam şirket "
        "genelini durduruyorsa '1' ver[cite: 1].\n\n"
        "İstek türü (istek_turu) — SADECE şunu ayırt eder: yeni bir şey mi "
        "TALEP ediliyor, yoksa var olan bir şey mi BOZUK/ARIZALI[cite: 1]? Metindeki "
        "aciliyet ifadesiyle KARIŞTIRMA[cite: 1].\n"
        "  planli_talep: kullanıcı yeni bir şey istiyor — kurulum, yeni "
        "yazılım/donanım temini, yetki/erişim verilmesi, geliştirme talebi[cite: 1].\n"
        "  olay: var olan bir sistem/donanım/yazılım bozuk, yavaş, çalışmıyor "
        "veya hata veriyor[cite: 1].\n\n"
        "Özel Yönlendirme Kuralları:\n"
        "1. Güvenlik Tespiti: E-posta/dosya içeriğinde phishing, oltalama, şüpheli gönderici/link/ek gibi güvenlik ifadeleri varsa, "
        "konu başlığında finans/ödeme/SAP gibi terimler geçse bile ilgili SAP/Finans kategorisine değil, mutlaka Güvenlik kategorilerine "
        "sınıflandır (ör. modul='IT-Guvenlik', ust_kategori='ARIZALAR', kategori_grubu='Güvenlik Arızaları')[cite: 1].\n"
        "2. TİNDİSO BAKIM: İşe giriş, işten çıkış işlemleri veya kamera periyodik bakımı ile ilgili rutin talepleri kesinlikle "
        "'TİNDİSO BAKIM' üst kategorisi altındaki ilgili hiyerarşiye oturt.\n\n"
        f"Geçerli Alt Kategori Hiyerarşisi (ust_kategori > kategori_grubu > alt_kategori):\n{hierarchy_listesi}\n\n"
        f"Ana Kategoriler (modul için):\n{kategori_listesi}\n\n"
        "Emin değilsen veya tam hiyerarşik eşleşme bulamadıysan modul='Diger', alt_kategori=null ve düşük guven ver[cite: 1]. Uydurma kategori kullanma[cite: 1]."
    )


@observe(name="classify_ticket")
async def classify(ticket_text: str) -> dict:
    from app.rag import store
    
    kategoriler = _get_kategoriler()
    hierarchy = store.get_category_hierarchy()
    sap_modules = store.get_sap_modules()
    
    system = _build_system(kategoriler, hierarchy, sap_modules)

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
        logger.warning("Classify JSON parse hatası — ham çıktı: %s", raw[:200])
        data = {}

    modul = data.get("modul")
    if modul not in kategoriler:
        modul = "Diger"
        
    oncelik = str(data.get("oncelik", "3"))
    if oncelik not in ("1", "2", "3", "4", "5"):
        oncelik = "3"
        
    istek_turu = data.get("istek_turu", "olay")
    if istek_turu not in ("olay", "planli_talep"):
        istek_turu = "olay"
        
    ust_kategori = data.get("ust_kategori")
    kategori_grubu = data.get("kategori_grubu")
    alt_kategori = data.get("alt_kategori")
    sap_modulu = data.get("sap_modulu")
    
    try:
        guven = float(data.get("guven", 0.0))
    except (TypeError, ValueError):
        guven = 0.0

    # Modelin uydurmasını engellemek için Hiyerarşi Doğrulaması
    is_valid_hierarchy = any(
        u == ust_kategori and g == kategori_grubu and a == alt_kategori 
        for u, g, a in hierarchy
    )
    
    if not is_valid_hierarchy:
        alt_kategori = None
        guven = min(guven, 0.3)

    if kategori_grubu != "SAP Problemleri":
        sap_modulu = None
    elif sap_modulu not in sap_modules:
        sap_modulu = None

    guven = max(0.0, min(1.0, guven))

    return {
        "modul": modul,
        "ust_kategori": ust_kategori,
        "kategori_grubu": kategori_grubu,
        "alt_kategori": alt_kategori,
        "sap_modulu": sap_modulu,
        "oncelik": oncelik,
        "istek_turu": istek_turu,
        "ozet": data.get("ozet", ""),
        "guven": guven,
    }
