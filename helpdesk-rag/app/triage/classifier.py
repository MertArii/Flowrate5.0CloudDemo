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


def _build_system(
    kategoriler: dict[str, dict],
    agac: dict[str, dict[str, list[str]]],
    sap_moduller: list[str],
) -> str:
    kategori_metni = _build_kategori_metni(kategoriler)
    etiketleme_metni = _build_etiketleme_metni(agac)
    sap_modul_metni = ", ".join(sap_moduller)

    return (
    "You are a help desk ticket classifier. Analyze the given ticket "
    "text and return ONLY valid JSON. Fields:\n"
    '  "modul": exactly ONE key from the CATEGORIES list below (this '
    "determines which team/specialist will resolve the ticket),\n"
    '  "oncelik": "1" | "2" | "3" | "4" | "5",\n'
    '  "istek_turu": "olay" | "planli_talep",\n'
    '  "ust_kategori": exactly ONE of the three top-level headings in '
    "the TAGGING TREE below (ARIZALAR / TALEPLER / TINDISO BAKIM),\n"
    '  "kategori_grubu": exactly ONE of the groups UNDER the chosen '
    "ust_kategori,\n"
    '  "alt_kategori": exactly ONE of the items UNDER the chosen '
    "kategori_grubu,\n"
    '  "sap_modulu": ONLY if kategori_grubu = "SAP Problemleri", '
    "exactly ONE value from the SAP MODULES list below; null in ALL "
    "other cases,\n"
    '  "ozet": a one-sentence summary of the issue, WRITTEN IN '
    "TURKISH,\n"
    '  "guven": a number between 0.0 and 1.0 indicating how confident '
    "you are in the classification.\n\n"
    "Priority (oncelik) — follow the SLA prioritization table from the "
    "Uyar Holding IT Incident and Request Management Procedure. Base "
    "the priority on SCOPE (how many people / which process is "
    "affected), not just on the category:\n"
    '  "1" (Critical): an incident that completely stops the entire '
    "Holding/company or a critical business process and requires "
    "immediate action. Examples: SAP is completely inaccessible; the "
    "entire company's email is down; a critical network device "
    "(firewall, router, or switch) has failed; all internet "
    "connectivity is down; a confirmed cyberattack, data breach, or "
    "ransomware incident; hardware failure on a critical server (DC, "
    "DNS, DB servers, etc.). Security incidents that have NOT actually "
    "happened yet and are only SUSPECTED (e.g. 'I received a "
    "suspicious email') do NOT belong at this level — give them '2' or "
    "'3' depending on scope instead.\n"
    '  "2" (High): affects a specific department or a large number of '
    "users, without stopping the whole organization. Examples: a "
    "department cannot log into SAP; the accounting department cannot "
    "connect to the e-invoice system; a file server is unreachable "
    "(regionally or department-wide); a critical piece of software has "
    "an error (e.g. the stock-control module is down); the backup "
    "system has failed (active business continuity is at risk); a "
    "confirmed/verified but limited-scope security incident.\n"
    '  "3" (Medium): affects an individual user and blocks that one '
    "user's work. Examples: a single employee's computer won't turn "
    "on; Outlook isn't sending email (webmail still works); a printer "
    "connection is lost; a network access issue affecting only one "
    "user; VPN not working for one user; a single user reporting a "
    "suspicious/phishing email.\n"
    '  "4" (Low): does not directly stop work and a workaround exists. '
    "Examples: a slow computer; a low-toner warning; an Excel macro "
    "error; mobile email sync errors; missing desktop shortcuts; "
    "password-change requests; ACCESS/AUTHORIZATION REQUESTS "
    "(including for SAP).\n"
    '  "5" (Planned Work / Service Request): planned, pre-requested '
    "work. Examples: setting up a computer and opening an email "
    "account for a new employee; installing new software for a user; "
    "setting up a new printer and its network connection; granting "
    "share permissions on a specific file/folder; a request for "
    "technical/equipment support for a training session or meeting "
    "room; software purchase or development requests.\n\n"
    "SPECIAL RULE: if the ticket is a DEVELOPMENT request (a change to "
    "an existing or new application, a new feature, or an integration "
    "development request), oncelik is ALWAYS '5' regardless of scope — "
    "per section 4.1 of the procedure.\n\n"
    "IMPORTANT: users frequently state their own claimed urgency in "
    "the email/request — words like 'acil' (urgent), 'ivedi', 'ASAP', "
    "or lots of exclamation marks — regardless of the actual scope. "
    "IGNORE these claims — base the priority ONLY on the concrete "
    "impact described in the ticket text.\n\n"
    "TOPIC-TRAP WARNING: a ticket's stated subject (e.g. finance, "
    "payment, SAP) can differ from its TRUE nature (e.g. "
    "security/phishing). If the text contains SECURITY language — "
    "phishing, oltalama (phishing), a suspicious sender/link/"
    "attachment — you MUST classify it as modul='IT-Guvenlik' and "
    "kategori_grubu='Guvenlik Arizalari' (or 'Guvenlik Talepleri' if "
    "it's a request), even if the subject line mentions terms like "
    "finance/payment/SAP — do NOT classify it under a finance category "
    "like SAP-FI.\n\n"
    "Request type (istek_turu) — this ONLY distinguishes whether "
    "something NEW is being requested, or whether something that "
    "already exists is BROKEN:\n"
    "  planli_talep: the user wants something new — an installation, "
    "new software/hardware provisioning, granting of access/"
    "authorization, or a development request.\n"
    "  olay: an existing system/hardware/software is broken, slow, not "
    "working, or throwing an error.\n\n"
    "TAGGING (ust_kategori / kategori_grubu / alt_kategori) — this is "
    "UNRELATED to who the ticket is assigned to; it only tags what "
    "kind of topic the ticket is about. If istek_turu='olay', "
    "ust_kategori is usually 'ARIZALAR'; if istek_turu='planli_talep', "
    "it is usually 'TALEPLER'; use 'TINDISO BAKIM' for "
    "onboarding/offboarding and camera-maintenance processes. "
    "kategori_grubu and alt_kategori MUST be a combination that "
    "ACTUALLY EXISTS in the tree below — never invent a value:\n\n"
    f"{etiketleme_metni}\n\n"
    f'SAP MODULES (used only when kategori_grubu="SAP Problemleri"): '
    f"{sap_modul_metni}\n\n"
    f"CATEGORIES (for the modul field):\n{kategori_metni}\n\n"
    "If you are not sure, use modul='Diger' and give a low guven "
    "score. Never invent a category that doesn't exist in the lists "
    "above."
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
        return sap_moduller_norm.get(_normalize(data.get("sap_modulu")))

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
    from app.rag import store  # geç import

    kategoriler = _get_kategoriler()
    agac = _build_agac(store.get_category_hierarchy())
    agac_norm = _build_agac_norm(agac)  # doğrulama bunun üzerinden yapılır
    sap_moduller = store.get_sap_modules()
    sap_moduller_norm = _build_sap_norm(sap_moduller)
    system = _build_system(kategoriler, agac, sap_moduller)  # prompt metni orijinal yazımla

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

    # Parse başarılı olsa bile modelin TAM olarak ne döndürdüğünü görebilmek
    # için ham çıktıyı her zaman logla (önceden sadece parse hatasında
    # loglanıyordu — doğrulamanın neyi neden reddettiğini teşhis etmek
    # imkansızdı).
    logger.debug("classify() ham model çıktısı: %r", data)

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

    etiketleme = _dogrula_etiketleme(data, agac_norm, sap_moduller_norm)
    if data.get("ust_kategori") and not etiketleme["ust_kategori"]:
        logger.info(
            "classify(): model ust_kategori=%r verdi ama ağaçta hiçbir seviye "
            "eşleşmedi (normalize sonrası bile) — etiketleme boş kaldı. "
            "kategori_grubu=%r alt_kategori=%r",
            data.get("ust_kategori"), data.get("kategori_grubu"), data.get("alt_kategori"),
        )

    return {
        "modul": modul,
        "oncelik": oncelik,
        "istek_turu": istek_turu,
        **etiketleme,  # ust_kategori, kategori_grubu, alt_kategori, sap_modulu (hepsi isim, id değil)
        "ozet": data.get("ozet", ""),
        "guven": guven,
    }