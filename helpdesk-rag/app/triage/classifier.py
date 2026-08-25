"""Ticket metnini yapılandırılmış sınıflandırmaya çevirir (Qwen3.5, JSON).

Kategori listesi DB'den (classification_categories) gelir — elle tutulan
dosya yok, ÖNBELLEK de yok: her classify() çağrısında taze çekilir. Bu VM'de
bile DB sorgusu milisaniyeler sürer, model çağrısının (saniyeler) yanında
ihmal edilebilir — buna karşılık yeni eklenen bir kategori restart
beklemeden anında devreye girer (eskiden önbellek yüzünden saatlerce fark
edilmeyen bir yanlış-sınıflandırma hatasına yol açmıştı)."""
from __future__ import annotations

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
        '  "oncelik": "dusuk" | "orta" | "yuksek" | "kritik" (aşağıdaki kapsam '
        'kriterlerine göre),\n'
        '  "istek_turu": "olay" | "planli_talep",\n'
        '  "ozet": sorunun tek cümlelik Türkçe özeti,\n'
        '  "guven": 0.0-1.0 arası, sınıflandırmaya ne kadar emin olduğun.\n\n'
        "Öncelik (oncelik) — Uyar Holding BT Olay ve Talep Yönetimi Prosedürü'ndeki "
        "SLA önceliklendirme tablosuna göre KAPSAMA (kaç kişiyi/hangi süreci "
        "etkilediğine) bak, sadece kategoriye değil:\n"
        "  kritik: Holding/şirket genelini veya kritik iş sürecini tamamen durduran "
        "(ör. SAP tamamen erişilemez, tüm e-posta çalışmıyor, siber saldırı).\n"
        "  yuksek: Bir departmanı veya çok sayıda kullanıcıyı etkiliyor, tüm "
        "organizasyonu durdurmuyor (ör. bir departman SAP'e giremiyor, dosya "
        "sunucusuna bölgesel erişilemiyor).\n"
        "  orta: Tek bir kullanıcının üretim/iş yapmasını engelleyen sorun (ör. "
        "bilgisayar açılmıyor, yazıcı bağlantısı kopmuş).\n"
        "  dusuk: İşi doğrudan durdurmayan, alternatifle devam edilebilen sorun "
        "(ör. bilgisayar yavaş, toner uyarısı, makro hatası).\n"
        "ÖNEMLİ: Kullanıcılar gerçek kapsamı ne olursa olsun mailde/talepte sık sık "
        "'acil', 'ivedi', 'ASAP', çok sayıda ünlem işareti gibi kendi aciliyet "
        "iddiasını yazar. Bu ifadeleri YOK SAY — SADECE ticket metninde tarif "
        "edilen somut etki alanına (kaç kişi/hangi sistem/hangi süreç etkileniyor) "
        "bak. Kullanıcı 'acil, bilgisayarım açılmıyor' derse ve bu tek bir kişiyi "
        "etkiliyorsa oncelik yine 'orta'dır, kullanıcı 'acil' dedi diye 'kritik' "
        "verme. Tersi de geçerli: kullanıcı 'acelesi yok' dese bile kapsam şirket "
        "genelini durduruyorsa 'kritik' ver.\n\n"
        "İstek türü (istek_turu) — SADECE şunu ayırt eder: yeni bir şey mi "
        "TALEP ediliyor, yoksa var olan bir şey mi BOZUK/ARIZALI? Metindeki "
        "aciliyet ifadesiyle (acelesi yok / acil vb.) KARIŞTIRMA — 'acelesi "
        "yok' demek düşük öncelik demektir, planlı talep demek DEĞİLDİR.\n"
        "  planli_talep: kullanıcı yeni bir şey istiyor — kurulum, yeni "
        "yazılım/donanım temini, yetki/erişim verilmesi, geliştirme talebi "
        "(ör. 'yeni çalışan için bilgisayar kurulumu', 'X yazılımı kurulsun', "
        "'bu klasöre erişim yetkisi istiyorum').\n"
        "  olay: var olan bir sistem/donanım/yazılım bozuk, yavaş, çalışmıyor "
        "veya hata veriyor — aciliyeti düşük olsa bile (ör. 'bilgisayarım "
        "yavaş, acelesi yok' → olay + dusuk, planli_talep DEĞİL).\n\n"
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
