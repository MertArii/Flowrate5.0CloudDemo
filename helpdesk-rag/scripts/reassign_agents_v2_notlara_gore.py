"""
tickets_125_yeniden_atanmis.xlsx (arkadasin NOTLAR: sutununu eklediği hali)
uzerinden IKINCI atama turu.

V1'den (reassign_agents_tickets125.py) farklari:
  1) Bolge evreni daraltildi: SADECE Istanbul, Ankara, Yozgat, Sakarya
     gercek. ticket_region kolonu buyuk olcude guvenilmez (notlar bunu
     defalarca dogruluyor: alandaki sehir ile metindeki sehir uyusmuyor).
     "Gercek bolge" su oncelikle belirlenir:
       a) notta acik bir bolge duzeltmesi varsa o
       b) metinde "Halkali" / "Merkez Ofis" geciyorsa -> Istanbul
          (bu ikisi Istanbul HQ'nun baska adlari, notlarda dogrulandi)
       c) ticket_region zaten 4 gercek isimden biriyse (normalize edilmis) -> o
       d) yoksa bolge bilinmiyor -> bolge onceligi uygulanmaz, sadece
          en az is yukune gore atama yapilir
  2) Yucel artik SADECE Ag degil, Sakarya bolgesinde Donanim rolunu de
     ustleniyor (not: "Yucel Sakaryadaki donanimci ve network"). IT-Donanim
     bolge havuzuna Sakarya -> Yucel eklendi.
  3) 52 ticket'taki NOTLAR: tek tek okunup, ya kategori/uzman/bolge override'i
     ya da "silme onerisi" / "belirsiz, degisiklik yok" notu olarak islendi
     (asagidaki NOTE_OVERRIDES ve DELETE_FLAGGED / BELIRSIZ listelerine bakin).
  4) Notlarda ayni sablonun ETIKETLENMEMIS ama ayni hatayi tasiyan tek bir
     baska ornegi bulunduysa (orn. "X Departmani SAP'a Erisemiyor" sablonunda
     idx35'in idx74 ile ayni sekilde SAP-FI'a yanlis etiketlenmis olmasi),
     o da tutarlilik icin ayni sekilde duzeltildi -- bu durumlar asagida
     GENELLESTIRILEN_DUZELTME olarak ayrica isaretlendi.

Cikti: tickets_125_notlara_gore_guncel.xlsx (Desktop'a yazilir).
"""
import json
import re
from collections import defaultdict

import pandas as pd

SRC = r"C:\Users\eymen.altun\Desktop\tickets_125_yeniden_atanmis.xlsx"
OUT = r"C:\Users\eymen.altun\Desktop\tickets_125_notlara_gore_guncel.xlsx"

AGENTS = [
    dict(id="d452be79-656c-4651-817d-1a200da15727", email="omer.teknoloji@sirket.com",
         name="Ömer Teknoloji", region="Yozgat", group="e7d5dc65-8d42-4763-a249-4103927ff431"),
    dict(id="8cfa7028-25a9-49ba-9532-b85f4c8be422", email="faruk.teknoloji@sirket.com",
         name="Faruk Teknoloji", region="Ankara", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    dict(id="992aa8db-0eec-455c-acb0-1f75c2119bb7", email="salih.teknoloji@sirket.com",
         name="Salih Teknoloji", region="Yozgat", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    dict(id="fe167612-09a1-4d39-9b5d-b66f3110d815", email="yucel.teknoloji@sirket.com",
         name="Yücel Teknoloji", region="Sakarya", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    dict(id="2a1a849e-9db9-4cf7-a0f9-a6b652f5fefb", email="gizem.teknoloji@sirket.com",
         name="Gizem Teknoloji", region="İstanbul", group="e7d5dc65-8d42-4763-a249-4103927ff431"),
    dict(id="8905071e-51f8-4c75-9e65-bd6e09ec63b1", email="emirhan.teknoloji@sirket.com",
         name="Emirhan Teknoloji", region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    dict(id="9e25d672-0cf8-451d-981a-d10530a30c5b", email="ogulcan.teknoloji@sirket.com",
         name="Oğulcan Teknoloji", region="İstanbul", group="e7d5dc65-8d42-4763-a249-4103927ff431"),
    dict(id="fd71f8a2-7884-47be-b7e0-0624ec2aeb19", email="yusuf.teknoloji@sirket.com",
         name="Yusuf Teknoloji", region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    dict(id="54195b9f-ad77-4780-8147-38559d459fc2", email="erdem.teknoloji@sirket.com",
         name="Erdem Teknoloji", region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    dict(id="f3144acb-ba7a-44b0-b1fc-ff5ed9185315", email="ramazan.teknoloji@sirket.com",
         name="Ramazan Teknoloji", region="İstanbul", group="e7d5dc65-8d42-4763-a249-4103927ff431"),
    dict(id="d3bdaa4e-c353-4fd5-b358-09ac5476b912", email="turgut.teknoloji@sirket.com",
         name="Turgut Teknoloji", region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    dict(id="68f7cf53-5de5-41d5-a6f5-cfa527a96871", email="sena.teknoloji@sirket.com",
         name="Sena Teknoloji", region="İstanbul", group="e7d5dc65-8d42-4763-a249-4103927ff431"),
    dict(id="e6cf6373-04b2-440c-aebd-3e1767835110", email="yalman.gude@sirket.com",
         name="Yalman Teknoloji", region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    dict(id="64ac6896-d57d-43a1-b0b8-8e098acc470e", email="mustafa.teknoloji@sirket.com",
         name="Mustafa Teknoloji", region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    dict(id="ee1245eb-bda3-4e19-8450-31173141f861", email="hakan.teknoloji@sirket.com",
         name="Hakan Teknoloji", region="İstanbul", group="e7d5dc65-8d42-4763-a249-4103927ff431"),
    dict(id="78cc4401-f73a-4447-9943-5a3bddec63dc", email="esra.teknoloji@sirket.com",
         name="Esra Teknoloji", region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
]
BY_EMAIL = {a["email"]: a for a in AGENTS}

CATEGORY_POOL = {
    "SAP-MM": ["omer.teknoloji@sirket.com", "sena.teknoloji@sirket.com"],
    "SAP-EWM": ["omer.teknoloji@sirket.com"],
    "SAP-SD": ["gizem.teknoloji@sirket.com", "sena.teknoloji@sirket.com"],
    "SAP-FI": ["ogulcan.teknoloji@sirket.com"],
    "SAP-CO": ["erdem.teknoloji@sirket.com"],
    "SAP-PP": ["ramazan.teknoloji@sirket.com"],
    "SAP-EFATURA": ["hakan.teknoloji@sirket.com"],
    "SAP-EODEME": ["hakan.teknoloji@sirket.com"],
    "SAP-EIRSALIYE": ["hakan.teknoloji@sirket.com"],
    "SAP-EBANKA": ["hakan.teknoloji@sirket.com"],
    "SAP-Yetki": ["esra.teknoloji@sirket.com"],
    "IT-Donanim": ["faruk.teknoloji@sirket.com", "salih.teknoloji@sirket.com",
                   "emirhan.teknoloji@sirket.com", "yusuf.teknoloji@sirket.com"],
    "IT-Ag": ["yucel.teknoloji@sirket.com"],
    "IT-Hesap": ["mustafa.teknoloji@sirket.com", "esra.teknoloji@sirket.com"],
    "IT-Guvenlik": ["turgut.teknoloji@sirket.com"],
    "IT-WebProjeleri": ["yalman.gude@sirket.com"],
    "SAP-Basis": ["mustafa.teknoloji@sirket.com", "esra.teknoloji@sirket.com"],
    "SAP-WM": ["omer.teknoloji@sirket.com"],
    "IT-Yazilim": ["faruk.teknoloji@sirket.com", "salih.teknoloji@sirket.com",
                   "emirhan.teknoloji@sirket.com", "yusuf.teknoloji@sirket.com"],
}

# IT-Donanim icin bolge -> aday(lar) haritasi. Sakarya = Yucel (not: "Yucel
# Sakaryadaki donanimci ve network" -- Sakarya'da ayri bir Donanim uzmani yok,
# bu rolu de Yucel ustleniyor).
DONANIM_BOLGE_ADAYLARI = {
    "ankara": ["faruk.teknoloji@sirket.com"],
    "yozgat": ["salih.teknoloji@sirket.com"],
    "i̇stanbul": ["emirhan.teknoloji@sirket.com", "yusuf.teknoloji@sirket.com"],
    "istanbul": ["emirhan.teknoloji@sirket.com", "yusuf.teknoloji@sirket.com"],
    "sakarya": ["yucel.teknoloji@sirket.com"],
}

REAL_REGIONS = {"i̇stanbul", "istanbul", "ankara", "yozgat", "sakarya"}
REAL_REGION_DISPLAY = {
    "i̇stanbul": "İstanbul", "istanbul": "İstanbul",
    "ankara": "Ankara", "yozgat": "Yozgat", "sakarya": "Sakarya",
}


def norm_region(r):
    if not isinstance(r, str):
        return None
    return r.strip().lower().replace("i̇", "i").replace("ı", "i")


def fix_mojibake(s):
    if not isinstance(s, str) or "Ã" not in s:
        return s
    try:
        return s.encode("latin1").decode("utf-8")
    except (UnicodeDecodeError, UnicodeEncodeError):
        return s


def get_modul(decision_factors_str):
    try:
        d = json.loads(decision_factors_str)
        return d.get("siniflandirma", {}).get("modul")
    except Exception:
        return None


# ---------------------------------------------------------------------------
# V1'deki icerik bazli override'lar (aynen korunuyor -- NOT override'lari
# asagida bunun UZERINE uygulanir ve kazanir)
# ---------------------------------------------------------------------------
def apply_content_overrides(subject, desc, modul):
    text = f"{subject} {desc}".lower()

    if "outlook" in text and modul in ("IT-Hesap",):
        return "IT-Donanim", "Outlook istemci sorunu -> Donanim ekibi"

    if modul == "SAP-Basis" and re.search(r"donan.m ar.zas", text):
        return "IT-Donanim", "Sunucu/disk donanim arizasi -> Donanim ekibi"

    if modul == "SAP-Basis" and (("payla" in text and "izn" in text) or "yetki" in text):
        return "SAP-Yetki", "Klasor paylasim/izin talebi -> Yetki (Esra) ekibi"

    if modul == "IT-Ag" and ("yeni kullan" in text or "kullanıcı oluş" in text or "kullanici olus" in text):
        return "IT-Hesap", "Yeni kullanici/yetki olusturma -> Hesap (IT-Hesap) ekibi"

    if modul == "IT-Yazilim":
        if "e-fatura" in text or "efatura" in text:
            return "SAP-EFATURA", "E-Fatura baglanti sorunu -> SAP E-Fatura (Hakan)"
        if "fbl5n" in text:
            return "SAP-FI", "FBL5N (Musteri Hesap Ekstresi) -> SAP-FI"
        if "me51n" in text or "me21n" in text or "migo" in text or "mmbe" in text or "mb52" in text:
            return "SAP-MM", "MM ekran kodu -> SAP-MM"
        if "vf01" in text or "vl01n" in text or "va01" in text or "xd01" in text:
            return "SAP-SD", "SD ekran kodu -> SAP-SD"
        return "IT-Donanim", "Genel masaustu yazilim sorunu, ozel uzman yok -> Donanim ekibi"

    return None, None


# ---------------------------------------------------------------------------
# Notlardan cikan, index'e ozel duzeltmeler.
# category: yeni modul_efektif (None = degismiyor)
# agent:    dogrudan atanacak email (None = havuz/bolge mantigina birak)
# region:   gercek bolge duzeltmesi (None = otomatik tespite birak)
# flag:     "silme_onerisi" | "belirsiz" | None
# not_ozeti: rapor icin kisa aciklama
# ---------------------------------------------------------------------------
NOTE_OVERRIDES = {
    0:   dict(category=None, agent=None, region=None, flag="belirsiz",
              ozet="Arkadas 'sorulacak' demis -- netlesmeden degistirilmedi."),
    1:   dict(category=None, agent="mustafa.teknoloji@sirket.com", region="ankara", flag=None,
              ozet="Ortak sunucu erisimi -> Mustafa (not ile)."),
    2:   dict(category="IT-Hesap", agent=None, region="sakarya", flag=None,
              ozet="Antalya yok -> Sakarya; kategori IT-Hesap'a cekildi (not ile)."),
    4:   dict(category=None, agent=None, region="yozgat", flag="belirsiz",
              ozet="'Lojistik Merkez ? Yozgat mi' -- soru isaretli, Yozgat varsayildi."),
    6:   dict(category="IT-Donanim", agent=None, region=None, flag=None,
              ozet="Ag sorunu once fiziki/donanim kontrolu gerektiriyor (not ile)."),
    7:   dict(category=None, agent=None, region="ankara", flag="belirsiz",
              ozet="'Fabrika diyorda Ankara mi' -- soru isaretli, Ankara varsayildi."),
    11:  dict(category="IT-Donanim", agent=None, region=None, flag=None,
              ozet="Kablo sorunu -> once donanimci, sonra Ag (not ile)."),
    12:  dict(category=None, agent=None, region=None, flag="belirsiz",
              ozet="Sadece bolge uyusmazligi notu (Halkali/Sanliurfa) -- kategori/uzman degismedi."),
    13:  dict(category=None, agent=None, region="sakarya", flag=None,
              ozet="Bursa yanlis -> Sakarya; Yucel zaten atanmisti, dogrulandi."),
    15:  dict(category="SAP-CO", agent="erdem.teknoloji@sirket.com", region=None, flag=None,
              ozet="CO01 -> SAP-CO, Erdem CO danismani (not ile)."),
    17:  dict(category=None, agent=None, region=None, flag="belirsiz",
              ozet="Sadece dil (Ingilizce) sorusu -- atama degismedi."),
    18:  dict(category="IT-Donanim", agent=None, region=None, flag=None,
              ozet="Yazici kurulumu -> Donanim (not ile; diger yazici ticketlarinin cogu zaten Donanim)."),
    22:  dict(category=None, agent=None, region=None, flag="belirsiz",
              ozet="Not sadece 'region' yaziyor, somut talimat yok -- degismedi."),
    23:  dict(category=None, agent=None, region=None, flag=None,
              ozet="Zaten Donanim -- not bunu dogruluyor, degisiklik yok."),
    25:  dict(category=None, agent=None, region=None, flag="belirsiz",
              ozet="Aciklama eksik -- veri kalitesi notu, atama degismedi."),
    26:  dict(category=None, agent=None, region=None, flag="belirsiz",
              ozet="Ticket 25 ile ayni (olasi kopya) -- atama degismedi, birlestirme onerilir."),
    29:  dict(category="SAP-FI", agent="ogulcan.teknoloji@sirket.com", region=None, flag=None,
              ozet="FB60 -> SAP FI, Ogulcan (not ile)."),
    30:  dict(category="SAP-FI", agent="ogulcan.teknoloji@sirket.com", region=None, flag=None,
              ozet="FB60 -> SAP FI, Ogulcan (not ile)."),
    34:  dict(category="IT-Donanim", agent=None, region="i̇stanbul", flag=None,
              ozet="'Merkez Ofis' = Halkali = Istanbul; once fiziki kontrol icin Donanim (not ile)."),
    36:  dict(category=None, agent=None, region=None, flag="belirsiz",
              ozet="'Gaziantep olmaz' -- hedef bolge verilmemis, atama degismedi."),
    37:  dict(category=None, agent=None, region=None, flag="belirsiz",
              ozet="Tekrar ticket (olasi kopya) -- atama degismedi, birlestirme onerilir."),
    38:  dict(category="IT-Donanim", agent=None, region="i̇stanbul", flag=None,
              ozet="'Merkez Ofis' = Halkali = Istanbul; once fiziki kontrol icin Donanim (not ile)."),
    41:  dict(category=None, agent=None, region="yozgat", flag=None,
              ozet="Izmir yok -> Yozgat; Salih zaten atanmisti, dogrulandi."),
    42:  dict(category="IT-Donanim", agent=None, region=None, flag="belirsiz",
              ozet="'Samsun olmaz, neresi?' -- bolge belirsiz, once Donanim bakmali (not ile)."),
    44:  dict(category=None, agent=None, region="yozgat", flag=None,
              ozet="Kayseri yok -> Yozgat; Salih zaten atanmisti, dogrulandi."),
    47:  dict(category=None, agent=None, region=None, flag="belirsiz",
              ozet="'Kocaeli olmaz' -- hedef bolge verilmemis, atama degismedi."),
    48:  dict(category=None, agent=None, region=None, flag="belirsiz",
              ozet="'Konya olmaz' -- hedef bolge verilmemis, atama degismedi."),
    49:  dict(category="SAP-Basis", agent=None, region=None, flag=None,
              ozet="SAP Basis -> Mustafa/Esra havuzu (not ile; DB sunucu sorunu Donanim'dan geri alindi)."),
    51:  dict(category="IT-Donanim", agent=None, region=None, flag=None,
              ozet="Once donanimci fiziki kontrol (not ile)."),
    54:  dict(category=None, agent=None, region=None, flag="belirsiz",
              ozet="'Malatya olmaz' -- hedef bolge verilmemis, atama degismedi."),
    57:  dict(category=None, agent="sena.teknoloji@sirket.com", region=None, flag=None,
              ozet="Omer dogru ama yuk dengelemek icin Sena'ya (not ile)."),
    65:  dict(category="IT-Donanim", agent=None, region="i̇stanbul", flag=None,
              ozet="Merkez=Halkali=Istanbul; once donanim fiziki kontrol, sonra Yucel'e (not ile; ilk adim Donanim)."),
    71:  dict(category="IT-Donanim", agent=None, region=None, flag=None,
              ozet="Mobil senkron sorunu -> Donanim (not ile; Outlook kuraliyla tutarli)."),
    73:  dict(category="IT-Donanim", agent=None, region=None, flag=None,
              ozet="Once fiziki kontrolu donanimci yapacak (not ile)."),
    74:  dict(category="SAP-Basis", agent=None, region=None, flag=None,
              ozet="SAP Basis -> Mustafa/Esra havuzu (not ile; departman SAP giris sorunu)."),
    76:  dict(category="IT-Donanim", agent=None, region="ankara", flag=None,
              ozet="Metin 'Ankara ofisinde' diyor (gercek bolge); once fiziki kontrol donanimci (not ile)."),
    83:  dict(category=None, agent="yucel.teknoloji@sirket.com", region="sakarya", flag=None,
              ozet="Yucel Sakarya'nin hem donanim hem network kisisi (not ile)."),
    84:  dict(category=None, agent=None, region=None, flag="belirsiz",
              ozet="'Samsun olmaz, tekillesmeli, benzer cok ticket var' -- dedup onerisi, atama degismedi."),
    86:  dict(category=None, agent=None, region=None, flag="silme_onerisi",
              ozet="Cok benzer talep oldu, silinmeli (not ile)."),
    87:  dict(category=None, agent=None, region=None, flag="silme_onerisi",
              ozet="Cok benzer talep oldu, silinmeli (not ile)."),
    88:  dict(category=None, agent=None, region=None, flag="silme_onerisi",
              ozet="Cok benzer talep oldu, silinmeli (not ile)."),
    90:  dict(category="IT-Donanim", agent=None, region=None, flag=None,
              ozet="Sirket telefonu mail sorunu -> Donanim (not ile)."),
    91:  dict(category=None, agent=None, region=None, flag="silme_onerisi",
              ozet="Iki modul birden var, karisiklik yaratabilir -- silinmeli (not ile)."),
    92:  dict(category="IT-Guvenlik", agent="turgut.teknoloji@sirket.com", region=None, flag=None,
              ozet="Fidye yazilimi uyarisi -> Guvenlik, Turgut (not ile)."),
    94:  dict(category=None, agent=None, region=None, flag="silme_onerisi",
              ozet="Ayni ticket'in tekrari, silinebilir (not ile)."),
    95:  dict(category=None, agent=None, region=None, flag="belirsiz",
              ozet="3 secenek verilmis (Yozgat/Salih, Sakarya/Yucel, Ankara/Faruk) -- en az yuklu olana atandi, asagida belirtildi."),
    96:  dict(category="IT-Donanim", agent=None, region="sakarya", flag=None,
              ozet="Bolge alani zaten Sakarya (gercek); once bolgedeki donanimci (not ile) -> Yucel."),
    97:  dict(category="IT-Donanim", agent=None, region="yozgat", flag=None,
              ozet="Bolge alani zaten Yozgat (gercek); once donanimci olmali (not ile) -> Salih."),
    98:  dict(category=None, agent=None, region=None, flag="silme_onerisi",
              ozet="Silinsin ticket (not ile)."),
    99:  dict(category=None, agent=None, region=None, flag="silme_onerisi",
              ozet="Silinsin ticket (not ile)."),
    107: dict(category="SAP-FI", agent="ogulcan.teknoloji@sirket.com", region=None, flag=None,
              ozet="VF01 -> Ogulcan (not ile)."),
    114: dict(category="SAP-FI", agent="ogulcan.teknoloji@sirket.com", region=None, flag=None,
              ozet="XD01 -> Ogulcan (not ile)."),
    # --- GENELLESTIRILEN DUZELTME: idx74 ile AYNI sablon (X Departmani SAP'a
    # Erisemiyor), ayni sekilde SAP-FI'a yanlis etiketlenmis, notlanmamis
    # ama tutarlilik icin ayni kurala tabi tutuldu ---
    35:  dict(category="SAP-Basis", agent=None, region=None, flag=None,
              ozet="GENELLESTIRME: idx74 ile ayni sablon (departman SAP giris sorunu, SAP-FI'a yanlis etiketlenmis) -> SAP Basis / Mustafa-Esra."),
}

# idx 95'in 3 secenegi (en az yuklu olana gore secilecek)
IDX95_SECENEKLER = [
    ("yozgat", "salih.teknoloji@sirket.com", "Salih/Yozgat"),
    ("sakarya", "yucel.teknoloji@sirket.com", "Yücel/Sakarya"),
    ("ankara", "faruk.teknoloji@sirket.com", "Faruk/Ankara"),
]


def derive_real_region(subject, desc, ticket_region, note_region):
    if note_region:
        return note_region
    text = f"{subject} {desc}"
    if re.search(r"halkal", text, re.IGNORECASE) or re.search(r"merkez ofis", text, re.IGNORECASE):
        return "i̇stanbul"
    tr = norm_region(ticket_region)
    if tr in REAL_REGIONS:
        return tr
    return None


def main():
    df = pd.read_excel(SRC)
    for col in ("subject", "raw_issue_description"):
        df[col] = df[col].apply(fix_mojibake)

    df["created_at_dt"] = pd.to_datetime(df["created_at"], errors="coerce", utc=True)
    df = df.sort_values("created_at_dt", kind="stable").reset_index(drop=False)
    # 'index' = orijinal 0-based satir sirasi (notlardaki idx ile ayni)

    df["modul_kaynak"] = df["decision_factors"].apply(get_modul)

    open_count = defaultdict(int)

    out_email = [None] * len(df)
    out_modul = [None] * len(df)
    out_reason = [None] * len(df)
    out_region = [None] * len(df)
    out_flag = [None] * len(df)

    for pos, row in df.iterrows():
        idx = row["index"]
        modul0 = row["modul_kaynak"]
        subject = str(row.get("subject") or "")
        desc = str(row.get("raw_issue_description") or "")
        ticket_region = row.get("ticket_region")

        # 1) V1 icerik override'lari (taban)
        v1_modul, v1_reason = apply_content_overrides(subject, desc, modul0)
        modul = v1_modul or modul0
        reason_parts = [f"{modul0} -> {modul}" if modul != modul0 else modul]
        if v1_reason:
            reason_parts.append(v1_reason)

        note = NOTE_OVERRIDES.get(idx)
        note_region = None
        forced_agent = None
        flag = None

        if note:
            if note["category"] and note["category"] != modul:
                reason_parts.append(f"NOT: {modul} -> {note['category']}")
                modul = note["category"]
            note_region = note["region"]
            forced_agent = note["agent"]
            flag = note["flag"]
            reason_parts.append(f"NOT: {note['ozet']}")

        real_region = derive_real_region(subject, desc, ticket_region, note_region)

        if forced_agent:
            secilen = BY_EMAIL[forced_agent]
            open_count[secilen["email"]] += 1
            reason_parts.append(f"secilen (not ile dogrudan): {secilen['name']} (yuk={open_count[secilen['email']]})")
        elif idx == 95:
            # 3 secenekten en az yuklu olan
            best = min(IDX95_SECENEKLER, key=lambda o: open_count[o[1]])
            secilen = BY_EMAIL[best[1]]
            open_count[secilen["email"]] += 1
            real_region = best[0]
            reason_parts.append(
                f"secilen (3 secenekten en az yuklu): {secilen['name']} "
                f"(diger secenekler: {', '.join(o[2] for o in IDX95_SECENEKLER if o[1] != best[1])})"
            )
        else:
            pool_emails = CATEGORY_POOL.get(modul, CATEGORY_POOL["IT-Donanim"])
            candidates = [BY_EMAIL[e] for e in pool_emails]

            if modul == "IT-Donanim" and real_region and real_region in DONANIM_BOLGE_ADAYLARI:
                bolge_adaylari = [BY_EMAIL[e] for e in DONANIM_BOLGE_ADAYLARI[real_region]]
                candidates = bolge_adaylari
                reason_parts.append(f"bolge eslesti: {real_region}")

            min_load = min(open_count[a["email"]] for a in candidates)
            secilen = next(a for a in candidates if open_count[a["email"]] == min_load)
            open_count[secilen["email"]] += 1
            reason_parts.append(f"secilen: {secilen['name']} (yuk={min_load})")

        out_email[pos] = secilen["email"]
        out_modul[pos] = modul
        out_region[pos] = real_region
        out_flag[pos] = flag
        out_reason[pos] = " | ".join(reason_parts)

    df["assigned_email_new"] = out_email
    df["modul_efektif"] = out_modul
    df["gercek_bolge"] = [REAL_REGION_DISPLAY.get(r, r) for r in out_region]
    df["silme_onerisi"] = out_flag
    df["atama_gerekcesi"] = out_reason

    df["assigned_agent_id"] = df["assigned_email_new"].map(lambda e: BY_EMAIL[e]["id"])
    df["assigned_agent_name"] = df["assigned_email_new"].map(lambda e: BY_EMAIL[e]["name"])
    df["assigned_group_id"] = df["assigned_email_new"].map(lambda e: BY_EMAIL[e]["group"])
    df["agent_region"] = df["assigned_email_new"].map(lambda e: BY_EMAIL[e]["region"])

    df = df.sort_values("index", kind="stable").drop(
        columns=["index", "created_at_dt", "modul_kaynak", "assigned_email_new"]
    )

    df.to_excel(OUT, index=False)

    print("Yazildi:", OUT)
    print()
    print("--- Uzman basina atanan ticket sayisi ---")
    for email, cnt in sorted(open_count.items(), key=lambda x: -x[1]):
        print(f"{BY_EMAIL[email]['name']:20s} {email:30s} {cnt}")
    print()
    print("--- Efektif kategori dagilimi ---")
    print(df["modul_efektif"].value_counts())
    print()
    print("--- Silme onerisi isaretli ticket sayisi ---")
    print(df["silme_onerisi"].value_counts(dropna=False))


if __name__ == "__main__":
    main()
