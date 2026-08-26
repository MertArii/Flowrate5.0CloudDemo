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

from app.rag import ollama_client

# 'Diger' bilerek DB'de yok: gerçek bir ekibe atanabilir kategori değil,
# "belirsiz/eşleşmiyor -> insan triyajı" için sabit bir sinyal.
_DIGER = {"aciklama": "Yukarıdakilere uymayan / belirsiz talepler"}


def _get_kategoriler() -> dict[str, dict]:
    from app.rag import store  # geç import: DB tabloları hazır olmadan yüklenmesin
    return {**store.get_categories(), "Diger": _DIGER}


def _build_system(kategoriler: dict[str, dict]) -> str:
    kategori_listesi = "\n".join(f"- {k}: {v['aciklama']}" for k, v in kategoriler.items())
    return (
        "Sen bir help desk ticket sınıflandırıcısısın. Verilen ticket metnini "
        "analiz et ve SADECE geçerli JSON döndür. Alanlar:\n"
        '  "modul": aşağıdaki kategorilerden TAM BİRİNİN anahtarı,\n'
        '  "oncelik": "1" | "2" | "3" | "4" | "5",\n'
        '  "istek_turu": "olay" | "planli_talep",\n'
        '  "ozet": sorunun tek cümlelik Türkçe özeti,\n'
        '  "guven": 0.0-1.0 arası, sınıflandırmaya ne kadar emin olduğun.\n\n'
        "Öncelik (oncelik) — Uyar Holding BT Olay ve Talep Yönetimi Prosedürü'ndeki "
        "SLA önceliklendirme tablosuna göre KAPSAMA (kaç kişiyi/hangi süreci "
        "etkilediğine) bak, sadece kategoriye değil:\n"
        '  "1" (Kritik): Holding/şirket genelini veya kritik iş sürecini tamamen durduran '
        "(ör. SAP tamamen erişilemez, tüm e-posta çalışmıyor, siber saldırı, firewall arızası).\n"
        '  "2" (Yüksek Öncelikli): Bir departmanı veya çok sayıda kullanıcıyı etkiliyor, tüm '
        "organizasyonu durdurmuyor (ör. bir departman SAP'e giremiyor, dosya sunucusuna erişilemiyor).\n"
        '  "3" (Orta Öncelikli): Bireysel kullanıcılara ait, tek kullanıcının işini engelleyen sorun '
        "(ör. bilgisayar açılmıyor, yazıcı bağlantısı kopmuş, VPN çalışmıyor).\n"
        '  "4" (Düşük Öncelikli): İşi doğrudan durdurmayan, alternatifle devam edilebilen sorun '
        "(ör. bilgisayar yavaş, toner uyarısı, şifre değiştirme, yetki ve erişim talepleri).\n"
        '  "5" (Planlı İş / Hizmet Talebi): Planlı, önceden talep edilen işler '
        "(ör. yeni çalışan için bilgisayar kurulumu, yeni yazılım kurulması, donanım sağlama).\n"
        "ÖNEMLİ: Kullanıcılar gerçek kapsamı ne olursa olsun mailde/talepte sık sık "
        "'acil', 'ivedi', 'ASAP', çok sayıda ünlem işareti gibi kendi aciliyet "
        "iddiasını yazar. Bu ifadeleri YOK SAY — SADECE ticket metninde tarif "
        "edilen somut etki alanına bak. Kullanıcı 'acil, bilgisayarım açılmıyor' derse ve bu tek "
        "bir kişiyi etkiliyorsa oncelik yine '3'tür, kullanıcı 'acil' dedi diye '1' "
        "verme. Tersi de geçerli: kullanıcı 'acelesi yok' dese bile kapsam şirket "
        "genelini durduruyorsa '1' ver.\n\n"
        "İstek türü (istek_turu) — SADECE şunu ayırt eder: yeni bir şey mi "
        "TALEP ediliyor, yoksa var olan bir şey mi BOZUK/ARIZALI? Metindeki "
        "aciliyet ifadesiyle KARIŞTIRMA.\n"
        "  planli_talep: kullanıcı yeni bir şey istiyor — kurulum, yeni "
        "yazılım/donanım temini, yetki/erişim verilmesi, geliştirme talebi.\n"
        "  olay: var olan bir sistem/donanım/yazılım bozuk, yavaş, çalışmıyor "
        "veya hata veriyor.\n\n"
        f"Kategoriler:\n{kategori_listesi}\n\n"
        "Emin değilsen modul='Diger' ve düşük guven ver. Uydurma kategori kullanma."
    )


@observe(name="classify_ticket")
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
    oncelik = str(data.get("oncelik", "3"))
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

    return {
        "modul": modul,
        "oncelik": oncelik,
        "istek_turu": istek_turu,
        "ozet": data.get("ozet", ""),
        "guven": guven,
    }
