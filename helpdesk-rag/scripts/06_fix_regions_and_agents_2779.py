"""
tickets_2779.xlsx -- region + outlook + agent duzeltme gecisi.

Kullanicinin istegi (2026-09-08):
  1) region sadece Istanbul, Ankara, Yozgat, Sakarya olmali. Bunun disindaki
     (Halkali, Bursa, Fabrika, Depo-1, Antalya, Konya, ... 20+ sahte/gercek
     sehir adi) her ticket duzeltilmeli.
  2) Eger o (eski, gecersiz) konum adi subject/description icinde de
     geciyorsa, metindeki o gecis de yeni bolgeyle guncellenmeli.
  3) Region duzeldikten sonra, gerekiyorsa assigned agent da
     dogru_agentlar.txt'e gore guncellenmeli.
  4) Outlook ile ilgili ticketlar once donanim (IT-Donanim) ekibine gitmeli.

Bulgu (kullaniciya AskUserQuestion ile soruldu, onaylandi):
  2136/2779 (%77) ticket'ta region gecersiz. Bunlarin sadece 59'unda
  subject/description icinde gercek bir bolge adi (Istanbul/Ankara/Yozgat/
  Sakarya, Halkali/Merkez Ofis = Istanbul) geciyor. Kalan ~2077 ticket icin
  metinde hicbir ipucu yok (repo'daki reassign_agents_v2_notlara_gore.py'de
  ayni sorun 125 ticket'lik kucuk sette elle/not ile cozulmustu -- 2779'da
  bu mumkun degil). Kullanici "esit dagit (yuk dengeleme)" secti: ipucu
  olmayanlar 4 bolgeye sayica en dengeli sekilde round-robin dagitilir.

Agent gercegi: assigned_agent_id/assigned_group_id mevcut haliyle kategoriyle
(decision_factors.siniflandirma.modul) ORANTISIZ/rastgele dagilmis (IT-Donanim
ticketlarinin SAP-FI uzmanina atanmis olmasi gibi) -- yani "gerekiyorsa"
agent guncellemesi pratikte NEREDEYSE HER ticket'ta gerekiyor. Bu yuzden
tam bir kategori+bolge bazli yeniden atama yapiliyor (mevcut atama zaten
dogru havuzdaysa DOKUNULMUYOR, degilse en az yuklu dogru uzmana atanıyor).

Cikti: Desktop'a tickets_2779_duzeltilmis.xlsx
"""
import json
import re
from collections import defaultdict
from datetime import datetime, timezone

import pandas as pd

SRC = r"C:\Users\eymen.altun\Desktop\tickets_2779.xlsx"
OUT = r"C:\Users\eymen.altun\Desktop\tickets_2779_duzeltilmis.xlsx"

NOW_ISO = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")

# ---------------------------------------------------------------------------
# Agent tablosu (dogru_agentlar.txt)
# ---------------------------------------------------------------------------
AGENTS = {
    "omer":    dict(id="d452be79-656c-4651-817d-1a200da15727", name="Ömer Teknoloji",
                     region="Yozgat",   group="e7d5dc65-8d42-4763-a249-4103927ff431"),
    "faruk":   dict(id="8cfa7028-25a9-49ba-9532-b85f4c8be422", name="Faruk Teknoloji",
                     region="Ankara",   group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    "salih":   dict(id="992aa8db-0eec-455c-acb0-1f75c2119bb7", name="Salih Teknoloji",
                     region="Yozgat",   group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    "yucel":   dict(id="fe167612-09a1-4d39-9b5d-b66f3110d815", name="Yücel Teknoloji",
                     region="Sakarya",  group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    "gizem":   dict(id="2a1a849e-9db9-4cf7-a0f9-a6b652f5fefb", name="Gizem Teknoloji",
                     region="İstanbul", group="e7d5dc65-8d42-4763-a249-4103927ff431"),
    "emirhan": dict(id="8905071e-51f8-4c75-9e65-bd6e09ec63b1", name="Emirhan Teknoloji",
                     region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    "ogulcan": dict(id="9e25d672-0cf8-451d-981a-d10530a30c5b", name="Oğulcan Teknoloji",
                     region="İstanbul", group="e7d5dc65-8d42-4763-a249-4103927ff431"),
    "yusuf":   dict(id="fd71f8a2-7884-47be-b7e0-0624ec2aeb19", name="Yusuf Teknoloji",
                     region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    "erdem":   dict(id="54195b9f-ad77-4780-8147-38559d459fc2", name="Erdem Teknoloji",
                     region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    "ramazan": dict(id="f3144acb-ba7a-44b0-b1fc-ff5ed9185315", name="Ramazan Teknoloji",
                     region="İstanbul", group="e7d5dc65-8d42-4763-a249-4103927ff431"),
    "turgut":  dict(id="d3bdaa4e-c353-4fd5-b358-09ac5476b912", name="Turgut Teknoloji",
                     region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    "sena":    dict(id="68f7cf53-5de5-41d5-a6f5-cfa527a96871", name="Sena Teknoloji",
                     region="İstanbul", group="e7d5dc65-8d42-4763-a249-4103927ff431"),
    "yalman":  dict(id="e6cf6373-04b2-440c-aebd-3e1767835110", name="Yalman Teknoloji",
                     region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    "mustafa": dict(id="64ac6896-d57d-43a1-b0b8-8e098acc470e", name="Mustafa Teknoloji",
                     region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
    "hakan":   dict(id="ee1245eb-bda3-4e19-8450-31173141f861", name="Hakan Teknoloji",
                     region="İstanbul", group="e7d5dc65-8d42-4763-a249-4103927ff431"),
    "esra":    dict(id="78cc4401-f73a-4447-9943-5a3bddec63dc", name="Esra Teknoloji",
                     region="İstanbul", group="8cd82ed0-91f8-4b33-9e6d-f55af97f43f2"),
}

# Kategori -> uzman havuzu (IT-Donanim haric; o asagida bolgeye gore ayrilir)
CATEGORY_POOL = {
    "SAP-MM": ["omer", "sena"],
    "SAP-EWM": ["omer"],
    "SAP-WM": ["omer"],
    "SAP-SD": ["gizem", "sena"],
    "SAP-FI": ["ogulcan"],
    "SAP-CO": ["erdem"],
    "SAP-PP": ["ramazan"],
    "SAP-EFATURA": ["hakan"], "SAP-EODEME": ["hakan"],
    "SAP-EIRSALIYE": ["hakan"], "SAP-EBANKA": ["hakan"],
    "SAP-Yetki": ["esra"],
    "SAP-Basis": ["mustafa", "esra"],
    "SAP-Genel": ["omer", "gizem", "ogulcan", "ramazan", "hakan", "sena", "erdem", "esra"],
    "IT-Ag": ["yucel"],
    "IT-Hesap": ["mustafa", "esra"],
    "IT-Guvenlik": ["turgut"],
    "IT-WebProjeleri": ["yalman"],
}

# IT-Donanim: bolgeye gore havuz. Sakarya'da ayri donanimci yok; Yucel
# (Sakarya/Ag) bu rolu de ustleniyor -- onceki proje notuyla dogrulanmis
# ayni kural (bkz. reassign_agents_v2_notlara_gore.py).
DONANIM_BOLGE_POOL = {
    "Ankara": ["faruk"],
    "Yozgat": ["salih"],
    "İstanbul": ["emirhan", "yusuf"],
    "Sakarya": ["yucel"],
}

VALID_REGIONS = {"İstanbul", "Ankara", "Yozgat", "Sakarya"}


def norm_existing_region(raw):
    if not isinstance(raw, str):
        return None
    s = raw.strip()
    if s.lower() == "istanbul":
        return "İstanbul"
    if s in VALID_REGIONS:
        return s
    return None  # gecersiz/sahte konum


REGION_TEXT_PATTERNS = [
    ("İstanbul", re.compile(r"halkal[ıi]|merkez ofis|istanbul", re.IGNORECASE)),
    ("Ankara", re.compile(r"ankara", re.IGNORECASE)),
    ("Yozgat", re.compile(r"yozgat", re.IGNORECASE)),
    ("Sakarya", re.compile(r"sakarya", re.IGNORECASE)),
]


def derive_region_from_text(text):
    for region, pat in REGION_TEXT_PATTERNS:
        if pat.search(text):
            return region
    return None


def parse_decision_factors(s):
    if not isinstance(s, str):
        return {}
    try:
        d = json.loads(s)
        if isinstance(d, str):
            d = json.loads(d)
        return d if isinstance(d, dict) else {}
    except Exception:
        return {}


def get_raw_category(parsed):
    if "siniflandirma" in parsed:
        return parsed["siniflandirma"].get("modul")
    return parsed.get("kategori")


RAW_KATEGORI_MAP = {
    "Donanım": "IT-Donanim",
    "Hesap/E-posta": "IT-Hesap",
    "Ağ": "IT-Ag",
}


def content_override_module(text_lower):
    if "e-fatura" in text_lower or "efatura" in text_lower:
        return "SAP-EFATURA"
    if "fbl5n" in text_lower:
        return "SAP-FI"
    if any(k in text_lower for k in ("me51n", "me21n", "migo", "mmbe", "mb52")):
        return "SAP-MM"
    if any(k in text_lower for k in ("vf01", "vl01n", "va01", "xd01")):
        return "SAP-SD"
    return None


def resolve_category(raw_modul, text_lower):
    modul = RAW_KATEGORI_MAP.get(raw_modul, raw_modul)

    if modul == "IT-Yazilim":
        override = content_override_module(text_lower)
        modul = override or "IT-Donanim"
    elif modul == "SAP-SD/MM":
        override = content_override_module(text_lower)
        modul = override  # None ise asagida ozel havuzla ele alinacak
    elif modul == "Genel-BT":
        modul = "IT-Donanim"

    if "outlook" in text_lower:
        modul = "IT-Donanim"

    return modul


def main():
    df = pd.read_excel(SRC)
    df["subject"] = df["subject"].astype(object)
    df["raw_issue_description"] = df["raw_issue_description"].astype(object)

    load = defaultdict(int)   # agent_key -> kac ticket'a atandi (denge icin)
    region_count = defaultdict(int)

    # --- 1. gecis: region'lari coz (metinden belirleneni ayirt et, kalanlari topla) ---
    resolved_region = [None] * len(df)
    needs_balance = []

    for i, row in df.iterrows():
        old_region_raw = row["ticket_region"]
        valid = norm_existing_region(old_region_raw)
        if valid:
            resolved_region[i] = valid
            region_count[valid] += 1
            continue

        text = f"{row.get('subject') or ''} {row.get('raw_issue_description') or ''}"
        found = derive_region_from_text(text)
        if found:
            resolved_region[i] = found
            region_count[found] += 1
        else:
            needs_balance.append(i)

    # Metinde ipucu olmayanlari 4 bolgeye sayica dengeli dagit (round-robin,
    # her adimda o ana kadar en az ticket'i olan bolgeyi sec).
    for i in needs_balance:
        target = min(VALID_REGIONS, key=lambda r: region_count[r])
        resolved_region[i] = target
        region_count[target] += 1

    # --- 2. gecis: her satiri isle (metin tutarliligi + kategori + agent) ---
    out_region = [None] * len(df)
    out_subject = [None] * len(df)
    out_desc = [None] * len(df)
    out_agent_id = [None] * len(df)
    out_agent_name = [None] * len(df)
    out_group_id = [None] * len(df)
    out_agent_region = [None] * len(df)
    out_updated_at = [None] * len(df)
    out_note = [None] * len(df)

    n_region_changed = 0
    n_text_fixed = 0
    n_agent_changed = 0
    n_outlook = 0
    n_diger_unassigned = 0

    for i, row in df.iterrows():
        notes = []
        old_region_raw = row["ticket_region"]
        old_region_str = old_region_raw.strip() if isinstance(old_region_raw, str) else None
        new_region = resolved_region[i]
        region_changed = (old_region_str != new_region)
        if region_changed:
            n_region_changed += 1
            notes.append(f"region: {old_region_raw!r} -> {new_region}")

        subject = row.get("subject") or ""
        desc = row.get("raw_issue_description") or ""
        new_subject, new_desc = subject, desc
        if region_changed and old_region_str and old_region_str.lower() not in ("nan",):
            pat = re.compile(re.escape(old_region_str), re.IGNORECASE)
            new_subject, n1 = pat.subn(new_region, subject)
            new_desc, n2 = pat.subn(new_region, desc)
            if n1 or n2:
                n_text_fixed += 1
                notes.append(f"metin duzeltildi: '{old_region_str}' -> '{new_region}' ({n1+n2} yer)")

        parsed = parse_decision_factors(row["decision_factors"])
        raw_modul = get_raw_category(parsed)
        text_lower = f"{new_subject} {new_desc}".lower()
        category = resolve_category(raw_modul, text_lower)
        if "outlook" in text_lower:
            n_outlook += 1
            notes.append("outlook -> IT-Donanim'e yonlendirildi")

        # havuzu belirle
        if category == "IT-Donanim":
            pool_keys = DONANIM_BOLGE_POOL.get(new_region, [])
        elif category is None:
            # SAP-SD/MM belirsiz kaldi (icerikte ekran kodu yok)
            pool_keys = ["gizem", "sena", "omer"]
        elif category == "Diger":
            pool_keys = []
        else:
            pool_keys = CATEGORY_POOL.get(category, [])

        current_agent_name = row.get("assigned_agent_name")
        current_key = None
        for k, a in AGENTS.items():
            if a["name"] == current_agent_name:
                current_key = k
                break

        if not pool_keys:
            # Diger / kategori belirsiz -> insan triyaj kuyrugu, agent atanmaz
            chosen_key = None
            if pd.notna(current_agent_name):
                notes.append(f"kategori={category}: agent kaldirildi (insan triyaji gerekiyor)")
            n_diger_unassigned += 1
        elif current_key in pool_keys:
            chosen_key = current_key  # zaten dogru havuzda, degistirme
        else:
            chosen_key = min(pool_keys, key=lambda k: load[k])
            notes.append(
                f"agent: {current_agent_name!r} -> {AGENTS[chosen_key]['name']} (kategori={category})"
            )
            n_agent_changed += 1

        if chosen_key:
            load[chosen_key] += 1
            a = AGENTS[chosen_key]
            out_agent_id[i] = a["id"]
            out_agent_name[i] = a["name"]
            out_group_id[i] = a["group"]
            out_agent_region[i] = a["region"]
        else:
            out_agent_id[i] = None
            out_agent_name[i] = None
            out_group_id[i] = None
            out_agent_region[i] = None

        out_region[i] = new_region
        out_subject[i] = new_subject
        out_desc[i] = new_desc
        changed_anything = bool(notes)
        out_updated_at[i] = NOW_ISO if changed_anything else row["updated_at"]
        out_note[i] = " | ".join(notes) if notes else "degisiklik yok"

    df["ticket_region"] = out_region
    df["subject"] = out_subject
    df["raw_issue_description"] = out_desc
    df["assigned_agent_id"] = out_agent_id
    df["assigned_agent_name"] = out_agent_name
    df["assigned_group_id"] = out_group_id
    df["agent_region"] = out_agent_region
    df["updated_at"] = out_updated_at
    df["duzeltme_notu"] = out_note

    df.to_excel(OUT, index=False)

    print("Yazildi:", OUT)
    print()
    print(f"Toplam ticket: {len(df)}")
    print(f"Region degisen: {n_region_changed}")
    print(f"  -- metinde de ({old_region_str!r} gibi) gecen ve duzeltilen: {n_text_fixed}")
    print(f"Outlook -> IT-Donanim yonlendirilen: {n_outlook}")
    print(f"Agent degisen: {n_agent_changed}")
    print(f"Diger/belirsiz kategori -> agent atanmadi: {n_diger_unassigned}")
    print()
    print("--- Yeni region dagilimi ---")
    print(pd.Series(out_region).value_counts())
    print()
    print("--- Uzman basina yuk ---")
    for k, cnt in sorted(load.items(), key=lambda x: -x[1]):
        print(f"{AGENTS[k]['name']:20s} {cnt}")


if __name__ == "__main__":
    main()
