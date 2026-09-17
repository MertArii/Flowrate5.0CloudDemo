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
    {ust: {grup: [alt, alt, ...]}} yapısına çevirir — SADECE prompt metni
    için kullanılır (orijinal, kullanıcıya/modele gösterilen yazımıyla)."""
    agac: dict[str, dict[str, list[str]]] = {}
    for ust, grup, alt in hierarchy:
        agac.setdefault(ust, {}).setdefault(grup, []).append(alt)
    return agac


def _normalize(deger: str | None) -> str | None:
    """Türkçe büyük/küçük harf ve baştaki/sondaki boşluk farklarına karşı
    dayanıklı karşılaştırma anahtarı üretir (router.py'deki bölge
    normalizasyonuyla aynı prensip). Model 'ARIZALAR', 'Arızalar' veya
    sonunda boşlukla 'ARIZALAR ' döndürse bile aynı anahtara düşer."""
    if not deger:
        return None
    d = deger.strip()
    d = d.replace("İ", "i").replace("I", "i").replace("ı", "i")
    return d.casefold()


def _build_agac_norm(
    agac: dict[str, dict[str, list[str]]],
) -> dict[str, tuple[str, dict[str, tuple[str, dict[str, str]]]]]:
    """agac'ı normalize edilmiş anahtarlarla indeksler:
    {norm(ust): (orijinal_ust, {norm(grup): (orijinal_grup, {norm(alt): orijinal_alt})})}
    Doğrulama SADECE bu yapı üzerinden yapılır; orijinal yazım (DB'deki
    gerçek değer) sonuçta hep korunur, sadece arama normalize edilir."""
    agac_norm: dict[str, tuple[str, dict[str, tuple[str, dict[str, str]]]]] = {}
    for ust, gruplar in agac.items():
        _, grup_map = agac_norm.setdefault(_normalize(ust), (ust, {}))
        for grup, alt_liste in gruplar.items():
            _, alt_map = grup_map.setdefault(_normalize(grup), (grup, {}))
            for alt in alt_liste:
                alt_map[_normalize(alt)] = alt
    return agac_norm


def _build_sap_norm(sap_moduller: list[str]) -> dict[str, str]:
    return {_normalize(s): s for s in sap_moduller}


def _build_kategori_metni(kategoriler: dict[str, dict]) -> str:
    return "\n".join(f"- {k}: {v['aciklama']}" for k, v in kategoriler.items())


def _build_etiketleme_metni(agac: dict[str, dict[str, list[str]]]) -> str:
    satirlar = []
    for ust, gruplar in agac.items():
        satirlar.append(f"{ust}:")
        for grup, alt_liste in gruplar.items():
            satirlar.append(f"  {grup}: {', '.join(alt_liste)}")
    return "\n".join(satirlar)


def _build_topic_system(
    agac: dict[str, dict[str, list[str]]],
    sap_moduller: list[str],
) -> str:
    """Aşama 1: yalnızca ticket konusu/etiketleme sınıflandırması."""
    etiketleme_metni = _build_etiketleme_metni(agac)
    sap_modul_metni = ", ".join(sap_moduller)

    return (
        "You are an IT help desk topic classifier. "
        "Analyze the ticket and return ONLY valid JSON. No markdown.\n\n"
        'OUTPUT: {"istek_turu":"olay|planli_talep",'
        '"ust_kategori":"...", "kategori_grubu":"...", '
        '"alt_kategori":"...", "sap_modulu":"..."|null}\n\n'
        "REQUEST TYPE:\n"
        "- olay = an existing system, hardware, software or service is "
        "broken, unavailable, slow, or gives an error.\n"
        "- planli_talep = something new is requested: installation, "
        "provisioning, access/authorization, new hardware/software, "
        "or development.\n\n"
        "TAGGING:\n"
        "- olay normally uses ust_kategori='ARIZALAR'.\n"
        "- planli_talep normally uses ust_kategori='TALEPLER'.\n"
        "- Use 'TINDISO BAKIM' for onboarding/offboarding and "
        "camera-maintenance processes.\n"
        "- kategori_grubu and alt_kategori MUST exactly exist in the tree.\n"
        "- alt_kategori MUST NEVER be null.\n\n"
        "SECURITY OVERRIDE:\n"
        "If the ticket concerns phishing, oltalama, suspicious sender, "
        "suspicious link, or suspicious attachment:\n"
        "- olay -> kategori_grubu='Guvenlik Arizalari'\n"
        "- planli_talep -> kategori_grubu='Guvenlik Talepleri'\n\n"
        "USB / PORT / DATA TRANSFER:\n"
        "Requests for USB access, port unlocking, or data-transfer "
        "permissions MUST use kategori_grubu='Güvenlik Talepleri' and "
        "alt_kategori='Dosya Paylaşımı (DLP) Talebi'.\n\n"
        "SAP:\n"
        "If kategori_grubu='SAP Problemleri', sap_modulu MUST be one "
        "of the SAP MODULES below. Otherwise sap_modulu MUST be null.\n"
        "- cost/expense center, controlling, budget -> SAP-CO\n"
        "- invoice, payment, accounting -> SAP-FI\n"
        "- purchasing, inventory, goods receipt -> SAP-MM\n\n"
        "Do not let the subject override the actual meaning of the ticket.\n"
        "Never invent a category.\n\n"
        f"TAGGING TREE:\n{etiketleme_metni}\n\n"
        f"SAP MODULES:\n{sap_modul_metni}"
    )


def _build_routing_system(
    kategoriler: dict[str, dict],
) -> str:
    """Aşama 2: sorumlu modul ve routing için gerekli bilgiler."""
    kategori_metni = _build_kategori_metni(kategoriler)

    return (
        "You are an IT help desk routing classifier. "
        "Analyze the ticket and Stage 1 classification. "
        "Return ONLY valid JSON. No markdown.\n\n"
        'OUTPUT: {"modul":"...", "scope":"company|department|large_group|individual|access_request", "blocked":true|false, "development":true|false, "ozet":"...", "guven":0.0}\n\n'
        "MODUL:\n"
        "- Select exactly one value from CATEGORIES.\n"
        "- modul is the team/specialist responsible for resolving the ticket.\n"
        "- If genuinely unclear, use 'Diger'.\n\n"
        "SECURITY:\n"
        "If the ticket contains phishing, oltalama, suspicious sender, "
        "suspicious link, or suspicious attachment, the responsible "
        "modul MUST be 'IT-Guvenlik'.\n"
        "USB access, port unlocking, and data-transfer permission requests "
        "also belong to 'IT-Guvenlik'.\n\n"
        "Use the actual technical/business meaning, not merely the subject.\n"
        "The Stage 1 result is the topic classification and should be used "
        "as context, not replaced without evidence.\n\n"
        f"CATEGORIES:\n{kategori_metni}\n\n"
        "SCOPE: determine the concrete impact described by the ticket: "
        "company = entire organization/critical process; "
        "department = department or large group; "
        "large_group = many users; "
        "individual = one user; "
        "access_request = new authorization/access request.\n"
        "blocked=true only when the affected work/process is actually blocked.\n"
        "development=true for application change, new feature, or integration development.\n"
        "Do not infer scope from words such as acil/ivedi/ASAP.\n\n"
        "Return guven between 0.0 and 1.0. "
        "ozet must be exactly one sentence in Turkish."
    )



def _normalize_oncelik(value) -> str:
    """'1', 1, '1.0' gibi varyasyonları tek haneli '1'..'5' string'ine indirger."""
    text = str(value).strip()
    if "." in text:
        text = text.split(".", 1)[0]
    return text


def _dogrula_etiketleme(
    data: dict,
    agac_norm: dict[str, tuple[str, dict[str, tuple[str, dict[str, str]]]]],
    sap_moduller_norm: dict[str, str],
) -> dict:
    """ust_kategori/kategori_grubu/alt_kategori/sap_modulu alanlarını DB'deki
    gerçek ağaca göre, NORMALİZE karşılaştırmayla doğrular. Her seviye
    BAĞIMSIZ değerlendirilir — üst seviyede tam string eşleşmemesi (case/
    boşluk farkı gibi) alt seviyelerdeki geçerli bir eşleşmeyi SİLMEZ:

      1) ust_kategori normalize eşleşirse -> o daldan devam.
      2) Eşleşmezse ama alt_kategori ağacın HERHANGİ bir yerinde normalize
         eşleşiyorsa -> ust_kategori/kategori_grubu o eşleşmeden GERİ
         KURTARILIR (model üst kategoriyi yanlış/farklı yazmış ama alt
         kategoriyi doğru vermiş olabilir).
      3) Hiçbiri eşleşmezse -> hepsi None (gerçek belirsizlik / uydurma).

    Sadece İSİM doğrular, id çözmez — id çözümlemesi service.py'de
    store.get_alt_kategori_id/get_sap_module_id ile yapılır."""
    bos = {"ust_kategori": None, "kategori_grubu": None, "alt_kategori": None, "sap_modulu": None}

    def _sap_coz(grup_adi: str) -> str | None:
        if grup_adi != _SAP_PROBLEMLERI_GRUBU:
            return None
        
        sap_val = data.get("sap_modulu")
        modul_val = data.get("modul")
    
    # Failsafe: sap_modulu boşsa ve modul "SAP-" ile başlıyorsa değerini oradan kopar
        if not sap_val and modul_val and modul_val.startswith("SAP-"):
            sap_val = modul_val.replace("SAP-", "")
        
    # Çıkarılan veya LLM'in kendi verdiği değeri normalleştirerek sözlükte eşleştir
        return sap_moduller_norm.get(_normalize(sap_val))

    ust_norm = _normalize(data.get("ust_kategori"))
    ust_eslesme = agac_norm.get(ust_norm)

    if ust_eslesme is None:
        # (2) Kurtarma: ust eşleşmedi ama alt_kategori ağacın bir yerinde
        # eşleşiyor mu diye tüm ağacı tara (SAP Problemleri hem grup hem
        # alt_kategori adı olarak geçtiği için bu tarama alt_kategori'nin
        # kendi grup_id'sine bağlı kalınarak yapılır, isim çakışması riski
        # yok — çünkü alt_map zaten o grubun İÇİNDEKİ alt kategorilerden
        # oluşuyor).
        alt_norm = _normalize(data.get("alt_kategori"))
        if alt_norm:
            for orijinal_ust, grup_map in agac_norm.values():
                for orijinal_grup, alt_map in grup_map.values():
                    if alt_norm in alt_map:
                        return {
                            "ust_kategori": orijinal_ust,
                            "kategori_grubu": orijinal_grup,
                            "alt_kategori": alt_map[alt_norm],
                            "sap_modulu": _sap_coz(orijinal_grup),
                        }
        return bos

    orijinal_ust, grup_map = ust_eslesme
    grup_norm = _normalize(data.get("kategori_grubu"))
    grup_eslesme = grup_map.get(grup_norm)
    if grup_eslesme is None:
        return {**bos, "ust_kategori": orijinal_ust}

    orijinal_grup, alt_map = grup_eslesme
    alt_norm = _normalize(data.get("alt_kategori"))
    orijinal_alt = alt_map.get(alt_norm)
    if orijinal_alt is None:
        return {**bos, "ust_kategori": orijinal_ust, "kategori_grubu": orijinal_grup}

    return {
        "ust_kategori": orijinal_ust,
        "kategori_grubu": orijinal_grup,
        "alt_kategori": orijinal_alt,
        "sap_modulu": _sap_coz(orijinal_grup),
    }


async def classify(ticket_text: str) -> dict:
    """
    İki aşamalı sınıflandırma:
      1) Konu / tagging / SAP
      2) Sorumlu modul / özet / güven

    Priority, Stage 1 ve Stage 2 sonuçlarından sonra deterministik olarak
    Python tarafında hesaplanır.
    """
    from app.rag import store  # geç import

    # DB'den her çağrıda taze veriyi al.
    kategoriler = _get_kategoriler()
    agac = _build_agac(store.get_category_hierarchy())
    agac_norm = _build_agac_norm(agac)
    sap_moduller = store.get_sap_modules()
    sap_moduller_norm = _build_sap_norm(sap_moduller)

    # ============================================================
    # AŞAMA 1 — TOPIC / TAGGING
    # ============================================================
    topic_system = _build_topic_system(agac, sap_moduller)

    topic_msg = await ollama_client.chat(
        [
            {"role": "system", "content": topic_system},
            {"role": "user", "content": ticket_text},
        ],
        fmt="json",
    )

    topic_raw = (topic_msg.get("content") or "{}").strip()
    if topic_raw.startswith("```"):
        topic_raw = topic_raw.strip("`")
        if topic_raw.startswith("json"):
            topic_raw = topic_raw[4:]
        topic_raw = topic_raw.strip()

    try:
        topic_data = json.loads(topic_raw)
    except json.JSONDecodeError:
        logger.warning(
            "classify(): Stage 1 JSON parse edilemedi. raw=%r",
            topic_raw,
        )
        topic_data = {}

    logger.debug("classify() Stage 1 ham çıktı: %r", topic_data)

    istek_turu = topic_data.get("istek_turu", "olay")
    if istek_turu not in ("olay", "planli_talep"):
        istek_turu = "olay"

    # Stage 1 tagging'i mevcut güvenli DB doğrulamasından geçir.
    etiketleme = _dogrula_etiketleme(
        topic_data,
        agac_norm,
        sap_moduller_norm,
    )

    # ============================================================
    # AŞAMA 2 — ROUTING / MODUL
    # ============================================================
    # Stage 2'ye yalnızca doğrulanmış topic sonucu gönderilir.
    topic_for_routing = {
        "istek_turu": istek_turu,
        **etiketleme,
    }

    routing_system = _build_routing_system(kategoriler)

    routing_user = (
        "TICKET:\n"
        f"{ticket_text}\n\n"
        "STAGE 1 CLASSIFICATION:\n"
        f"{json.dumps(topic_for_routing, ensure_ascii=False)}"
    )

    routing_msg = await ollama_client.chat(
        [
            {"role": "system", "content": routing_system},
            {"role": "user", "content": routing_user},
        ],
        fmt="json",
    )

    routing_raw = (routing_msg.get("content") or "{}").strip()
    if routing_raw.startswith("```"):
        routing_raw = routing_raw.strip("`")
        if routing_raw.startswith("json"):
            routing_raw = routing_raw[4:]
        routing_raw = routing_raw.strip()

    try:
        routing_data = json.loads(routing_raw)
    except json.JSONDecodeError:
        logger.warning(
            "classify(): Stage 2 JSON parse edilemedi. raw=%r",
            routing_raw,
        )
        routing_data = {}

    logger.debug("classify() Stage 2 ham çıktı: %r", routing_data)

    # Modul doğrulaması Python tarafında.
    modul = routing_data.get("modul")
    if modul not in kategoriler:
        modul = "Diger"

    # ============================================================
    # İSTEK TÜRÜNE DAYALI DETERMINISTIC PRIORITY
    # ============================================================
    #
    # LLM'den priority istemiyoruz. Çünkü "acil", "ASAP", "!!!" gibi
    # kelimeler priority'yi yanlış yükseltebilir.
    #
    # Scope bilgisini Stage 2 çıktısında istemek yerine, mevcut ticket
    # metninden güvenli varsayılanı 3/4/5 üzerinden belirlemek için
    # aşağıdaki kurallar uygulanır.
    #
    # NOT: Department/company-wide scope gibi semantik bilgiler henüz
    # ayrı bir Stage 2 alanı olarak modellenmediği için, bu sürümde
    # priority'nin 1/2 ayrımı için LLM'den explicit "scope" alınır.
    #
    # Bu nedenle routing prompt'una scope eklenmiştir ve aşağıda okunur.
    scope = routing_data.get("scope", "individual")
    blocked = bool(routing_data.get("blocked", False))
    development = bool(routing_data.get("development", False))

    if development:
        oncelik = "5"
    elif istek_turu == "planli_talep":
        # Yetkilendirme/access talepleri prosedürde 4;
        # planlı provisioning/service request 5 olarak ayrılır.
        if scope == "access_request":
            oncelik = "4"
        else:
            oncelik = "5"
    elif scope == "company" and blocked:
        oncelik = "1"
    elif scope == "department" and blocked:
        oncelik = "2"
    elif scope == "large_group" and blocked:
        oncelik = "2"
    elif scope == "individual" and blocked:
        oncelik = "3"
    else:
        oncelik = "4"

    try:
        guven = float(routing_data.get("guven", 0.0))
    except (TypeError, ValueError):
        guven = 0.0
    guven = max(0.0, min(1.0, guven))

    return {
        "modul": modul,
        "oncelik": oncelik,
        "istek_turu": istek_turu,
        **etiketleme,
        "ozet": routing_data.get("ozet", ""),
        "guven": guven,
    }