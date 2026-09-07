"""
tickets_125.xlsx içindeki ticket'lara, artik silinecek olan sahte uzmanlar
yerine dogru_agentlar.txt'deki GERCEK uzmanlardan birini, ticket icerigine
(decision_factors.modul + subject + raw_issue_description) bakarak yeniden
atar.

Mantik router.py'deki gercek atama algoritmasini taklit eder:
  1) kategori (modul) -> uzman havuzu (uzman_kategorileri eslesmesi)
  2) IT-Donanim'da bolge onceligi (agent.region == ticket_region)
  3) havuz icinde en az is yuku olan (bu calisma icin: o ana kadar
     atanmis ticket sayisi, created_at sirasina gore simule edilir)

Icerik bazli override'lar (kategori etiketi yanlis/eksik oldugu icin):
  - "Outlook" gecen bireysel istemci sorunlari -> IT-Donanim
    (kullanicinin talebi: "Outlook kismini daha cok donanim olarak
    eklemeliyiz")
  - IT-Yazilim etiketli ama aslinda belirli bir SAP islem koduna
    (FBL5N, ME51N, VF01, VL01N, XD01, e-Fatura...) bagli talepler
    -> ilgili SAP modulu
  - "Donanim Arizasi" gecen sunucu/disk sorunu (SAP-Basis etiketli) -> IT-Donanim
  - Paylasim/izin talebi (SAP-Basis etiketli) -> SAP-Yetki
  - Yeni kullanici/yetki olusturma (IT-Ag etiketli) -> IT-Hesap
  - SAP-WM (uzmani yok) -> SAP-MM/EWM uzmanina (depo/stok ortak alani)
  - Kalan SAP-Basis (oturum/giris, yedekleme) -> Sistem Destek havuzu
    (IT-Hesap uzmanlari, en yakin baslik eslesmesi)

Cikti: tickets_125_yeniden_atanmis.xlsx (orijinalin yaninda, ayni klasorde
degil -> Desktop'a yazilir) + konsola ozet.
"""
import json
import re
from collections import defaultdict

import pandas as pd

SRC = r"C:\Users\eymen.altun\Desktop\tickets_125.xlsx"
OUT = r"C:\Users\eymen.altun\Desktop\tickets_125_yeniden_atanmis.xlsx"

# ---------------------------------------------------------------------------
# dogru_agentlar.txt icerigi (16 gercek uzman)
# ---------------------------------------------------------------------------
AGENTS = [
    dict(id="d452be79-656c-4651-817d-1a200da15727", email="omer.teknoloji@sirket.com",
         name="Ömer Teknoloji", region="Yozgat", group="e7d5dc65-8d42-4763-a249-4103927ff431",
         cats={"SAP-MM", "SAP-EWM"}),
    dict(id="8cfa7028-25a9-49ba-9532-b85f4c8be422", email="faruk.teknoloji@sirket.com",
         name="Faruk Teknoloji", region="Ankara", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2",
         cats={"IT-Donanim"}),
    dict(id="992aa8db-0eec-455c-acb0-1f75c2119bb7", email="salih.teknoloji@sirket.com",
         name="Salih Teknoloji", region="Yozgat", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2",
         cats={"IT-Donanim"}),
    dict(id="fe167612-09a1-4d39-9b5d-b66f3110d815", email="yucel.teknoloji@sirket.com",
         name="Yücel Teknoloji", region="Sakarya", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2",
         cats={"IT-Ag"}),
    dict(id="2a1a849e-9db9-4cf7-a0f9-a6b652f5fefb", email="gizem.teknoloji@sirket.com",
         name="Gizem Teknoloji", region="İstanbul", group="e7d5dc65-8d42-4763-a249-4103927ff431",
         cats={"SAP-SD"}),
    dict(id="8905071e-51f8-4c75-9e65-bd6e09ec63b1", email="emirhan.teknoloji@sirket.com",
         name="Emirhan Teknoloji", region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2",
         cats={"IT-Donanim"}),
    dict(id="9e25d672-0cf8-451d-981a-d10530a30c5b", email="ogulcan.teknoloji@sirket.com",
         name="Oğulcan Teknoloji", region="İstanbul", group="e7d5dc65-8d42-4763-a249-4103927ff431",
         cats={"SAP-FI"}),
    dict(id="fd71f8a2-7884-47be-b7e0-0624ec2aeb19", email="yusuf.teknoloji@sirket.com",
         name="Yusuf Teknoloji", region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2",
         cats={"IT-Donanim"}),
    dict(id="54195b9f-ad77-4780-8147-38559d459fc2", email="erdem.teknoloji@sirket.com",
         name="Erdem Teknoloji", region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2",
         cats={"SAP-CO"}),
    dict(id="f3144acb-ba7a-44b0-b1fc-ff5ed9185315", email="ramazan.teknoloji@sirket.com",
         name="Ramazan Teknoloji", region="İstanbul", group="e7d5dc65-8d42-4763-a249-4103927ff431",
         cats={"SAP-PP"}),
    dict(id="d3bdaa4e-c353-4fd5-b358-09ac5476b912", email="turgut.teknoloji@sirket.com",
         name="Turgut Teknoloji", region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2",
         cats={"IT-Guvenlik"}),
    dict(id="68f7cf53-5de5-41d5-a6f5-cfa527a96871", email="sena.teknoloji@sirket.com",
         name="Sena Teknoloji", region="İstanbul", group="e7d5dc65-8d42-4763-a249-4103927ff431",
         cats={"SAP-MM", "SAP-SD"}),
    dict(id="e6cf6373-04b2-440c-aebd-3e1767835110", email="yalman.gude@sirket.com",
         name="Yalman Teknoloji", region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2",
         cats={"IT-WebProjeleri"}),
    dict(id="64ac6896-d57d-43a1-b0b8-8e098acc470e", email="mustafa.teknoloji@sirket.com",
         name="Mustafa Teknoloji", region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2",
         cats={"IT-Hesap"}),
    dict(id="ee1245eb-bda3-4e19-8450-31173141f861", email="hakan.teknoloji@sirket.com",
         name="Hakan Teknoloji", region="İstanbul", group="e7d5dc65-8d42-4763-a249-4103927ff431",
         cats={"SAP-EODEME", "SAP-EIRSALIYE", "SAP-EFATURA", "SAP-EBANKA"}),
    dict(id="78cc4401-f73a-4447-9943-5a3bddec63dc", email="esra.teknoloji@sirket.com",
         name="Esra Teknoloji", region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2",
         cats={"IT-Hesap", "SAP-Yetki"}),
]
BY_EMAIL = {a["email"]: a for a in AGENTS}

# kategori -> aday havuzu (email listesi). Uzmani olmayan kategoriler icin
# icerik temelli fallback havuzu tanimlanir (asagida override ile cozulur).
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
    # uzmani olmayan kategoriler icin en yakin ekip (icerik override'lariyla
    # cogu ticket zaten daha dogru bir kategoriye tasinir; kalanlar buraya duser)
    "SAP-Basis": ["mustafa.teknoloji@sirket.com", "esra.teknoloji@sirket.com"],
    "SAP-WM": ["omer.teknoloji@sirket.com"],
    "IT-Yazilim": ["faruk.teknoloji@sirket.com", "salih.teknoloji@sirket.com",
                   "emirhan.teknoloji@sirket.com", "yusuf.teknoloji@sirket.com"],
}

BOLGE_ONCELIK_MODUL = "IT-Donanim"


def norm_region(r):
    if not isinstance(r, str):
        return None
    return r.strip().lower().replace("i̇", "i").replace("ı", "i")


def get_modul(decision_factors_str):
    try:
        d = json.loads(decision_factors_str)
        return d.get("siniflandirma", {}).get("modul")
    except Exception:
        return None


# ---------------------------------------------------------------------------
# icerik bazli override kurallari
# her kural: (fonksiyon(subject, desc, modul) -> yeni_modul veya None, aciklama)
# ---------------------------------------------------------------------------
def apply_content_overrides(subject, desc, modul):
    text = f"{subject} {desc}".lower()

    # 1) Outlook (bireysel istemci sorunu) -> IT-Donanim
    if "outlook" in text and modul in ("IT-Hesap",):
        return "IT-Donanim", "Outlook istemci sorunu -> kullanici talimatiyla Donanim ekibine yonlendirildi"

    # 2) SAP-Basis: acikca donanim arizasi
    if modul == "SAP-Basis" and ("donan" in text and "ar" in text):
        if "donanım arızası" in text or "donanim arizasi" in text or re.search(r"donan.m ar.zas", text):
            return "IT-Donanim", "Sunucu/disk donanim arizasi -> Donanim ekibi"

    # 3) SAP-Basis: paylasim/izin talebi -> SAP-Yetki
    if modul == "SAP-Basis" and (("payla" in text and "izn" in text) or "yetki" in text):
        return "SAP-Yetki", "Klasor paylasim/izin talebi -> Yetki (Esra) ekibi"

    # 4) IT-Ag: yeni kullanici / temel yetki olusturma -> IT-Hesap
    if modul == "IT-Ag" and ("yeni kullan" in text or "kullanıcı oluş" in text or "kullanici olus" in text):
        return "IT-Hesap", "Yeni kullanici/yetki olusturma -> Hesap (IT-Hesap) ekibi"

    # 5) IT-Yazilim -> belirli SAP islem kodlarina gore ilgili modul
    if modul == "IT-Yazilim":
        if "e-fatura" in text or "efatura" in text:
            return "SAP-EFATURA", "E-Fatura baglanti sorunu -> SAP E-Fatura (Hakan)"
        if "fbl5n" in text:
            return "SAP-FI", "FBL5N (Musteri Hesap Ekstresi) -> SAP-FI"
        if "me51n" in text or "me21n" in text or "migo" in text or "mmbe" in text or "mb52" in text:
            return "SAP-MM", "MM ekran kodu -> SAP-MM"
        if "vf01" in text or "vl01n" in text or "va01" in text or "xd01" in text:
            return "SAP-SD", "SD ekran kodu -> SAP-SD"
        # kalan (Excel, ekran karakter bozuklugu, yazilim kurulum talebi vb.)
        return "IT-Donanim", "Genel masaustu yazilim sorunu, ozel uzman yok -> Donanim ekibi (genel IT destek)"

    return None, None


def fix_mojibake(s):
    """Kaynak dosyada tek bir satirda (subject/aciklama) UTF-8 metni yanlislikla
    Latin-1 olarak kodlanmis goruluyor (orn. 'Ã‡alÄ±ÅŸmÄ±yor'). Round-trip
    calisirsa duzeltilmis halini dondurur, aksi halde dokunmaz."""
    if not isinstance(s, str) or "Ã" not in s:
        return s
    try:
        fixed = s.encode("latin1").decode("utf-8")
    except (UnicodeDecodeError, UnicodeEncodeError):
        return s
    return fixed


def main():
    df = pd.read_excel(SRC)
    for col in ("subject", "raw_issue_description"):
        df[col] = df[col].apply(fix_mojibake)
    df["created_at_dt"] = pd.to_datetime(df["created_at"], errors="coerce", utc=True)
    df = df.sort_values("created_at_dt", kind="stable").reset_index(drop=False)
    # 'index' sutunu = orijinal excel satir sirasi (0-based)

    df["modul_orijinal"] = df["decision_factors"].apply(get_modul)

    open_count = defaultdict(int)  # email -> bu calismada simule edilen yuk

    assigned_email = [None] * len(df)
    assigned_modul_eff = [None] * len(df)
    assigned_reason = [None] * len(df)

    for pos, row in df.iterrows():
        modul0 = row["modul_orijinal"]
        subject = str(row.get("subject") or "")
        desc = str(row.get("raw_issue_description") or "")

        yeni_modul, override_sebep = apply_content_overrides(subject, desc, modul0)
        modul_eff = yeni_modul or modul0

        pool_emails = CATEGORY_POOL.get(modul_eff, [])
        if not pool_emails:
            # tanimsiz kategori: genel IT havuzuna (Donanim) dus
            pool_emails = CATEGORY_POOL["IT-Donanim"]
            if override_sebep is None:
                override_sebep = f"Tanimsiz kategori ({modul_eff}) -> genel Donanim havuzu"

        candidates = [BY_EMAIL[e] for e in pool_emails]

        bolge_not = None
        if modul_eff == BOLGE_ONCELIK_MODUL:
            treg = norm_region(row.get("ticket_region"))
            if treg:
                bolge_adaylar = [a for a in candidates if norm_region(a["region"]) == treg]
                if bolge_adaylar:
                    candidates = bolge_adaylar
                    bolge_not = f"bolge eslesti ({row.get('ticket_region')})"

        # en az is yuku (bu calismada simule edilen), esitlikte havuzdaki ilk sirada olan
        min_load = min(open_count[a["email"]] for a in candidates)
        secilen = next(a for a in candidates if open_count[a["email"]] == min_load)
        open_count[secilen["email"]] += 1

        reason_parts = [f"{modul0} -> {modul_eff}" if modul_eff != modul0 else modul_eff]
        if override_sebep:
            reason_parts.append(override_sebep)
        if bolge_not:
            reason_parts.append(bolge_not)
        reason_parts.append(f"secilen: {secilen['name']} (yuk={min_load})")

        assigned_email[pos] = secilen["email"]
        assigned_modul_eff[pos] = modul_eff
        assigned_reason[pos] = " | ".join(reason_parts)

    df["assigned_email_new"] = assigned_email
    df["modul_efektif"] = assigned_modul_eff
    df["atama_gerekcesi"] = assigned_reason

    df["assigned_agent_id"] = df["assigned_email_new"].map(lambda e: BY_EMAIL[e]["id"])
    df["assigned_agent_name"] = df["assigned_email_new"].map(lambda e: BY_EMAIL[e]["name"])
    df["assigned_group_id"] = df["assigned_email_new"].map(lambda e: BY_EMAIL[e]["group"])
    df["agent_region"] = df["assigned_email_new"].map(lambda e: BY_EMAIL[e]["region"])

    # orijinal satir sirasina geri don
    df = df.sort_values("index", kind="stable").drop(columns=["index", "created_at_dt", "modul_orijinal", "assigned_email_new"])

    df.to_excel(OUT, index=False)

    print("Yazildi:", OUT)
    print()
    print("--- Uzman basina atanan ticket sayisi ---")
    for email, cnt in sorted(open_count.items(), key=lambda x: -x[1]):
        print(f"{BY_EMAIL[email]['name']:20s} {email:30s} {cnt}")
    print()
    print("--- Efektif kategori dagilimi ---")
    print(df["modul_efektif"].value_counts())


if __name__ == "__main__":
    main()
