import os
import re
import json
import joblib
import pandas as pd
from PIL import Image
import pytesseract
from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.preprocessing import MultiLabelBinarizer
from sklearn.base import BaseEstimator, TransformerMixin
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.ensemble import RandomForestClassifier
from sklearn.calibration import CalibratedClassifierCV
from sklearn.metrics import classification_report

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

DOSYA_ADI = os.path.join(BASE_DIR, 'emails_sla_seviyeli.json')
MODEL_DOSYASI = os.path.join(BASE_DIR, 'model.pkl')
JSON_SOZLUK_YOLU = os.path.join(BASE_DIR, 'knowledge_base', 'modul_sozlugu.json')

def veriyi_maskele(metin):
    text = str(metin)
    text = re.sub(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', '[IP_MASKELENDI]', text)
    text = re.sub(r'[\w\.-]+@[\w\.-]+', '[MAIL_MASKELENDI]', text)
    text = re.sub(r'\b0\d{3}\s?\d{3}\s?\d{2}\s?\d{2}\b', '[TEL_MASKELENDI]', text)
    text = re.sub(r'\b[1-9][0-9]{10}\b', '[TC_MASKELENDI]', text)
    text = re.sub(r'\b(?:TR|tr)\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{2}\b', '[IBAN_MASKELENDI]', text)
    text = re.sub(r'\b[A-Z]{2,4}[-\s]?\d{3,6}\b', '[BELGE_MASKELENDI]', text)
    return text


def sozluk_yukle():
    if os.path.exists(JSON_SOZLUK_YOLU):
        with open(JSON_SOZLUK_YOLU, 'r', encoding='utf-8') as f:
            return json.load(f)
    else:
        print(f"Uyarı: '{JSON_SOZLUK_YOLU}' bulunamadı! Boş sözlük kullanılacak.")
        return {}

SAP_SOZLUK = sozluk_yukle()

def sap_modul_analizi(metin):
    metin_upper = metin.upper()

    sap_kurallari = {
        "SD_Modulu": r'\b(VA\d{2}[A-Z]*|VL\d{2}[A-Z]*|VF\d{2}[A-Z]*)\b',
        "MM_Modulu": r'\b(ME\d{2}[A-Z]*|MI[A-Z]{2}|MB\d{2})\b',
        "FI_Modulu": r'\b(FB\d{2}[A-Z]*|F-\d{2}|FS\d{2})\b',
        "CO_Modulu": r'\b(CK\d{2}[A-Z]*|CO\d{2}[A-Z]*|KS\d{2})\b',
        "BASIS_Modulu": r'\b(SU\d{2}|PFCG|SM\d{2})\b'
    }

    for modul_adi, regex_kurali in sap_kurallari.items():
        if re.search(regex_kurali, metin_upper):
            return modul_adi

    if any(k in metin_upper for k in ["SİPARİŞ", "TESLİMAT", "FATURA", "SD BELGESİ"]):
        return "SD_Modulu"
    elif any(k in metin_upper for k in ["MALZEME", "STOK", "MAL GİRİŞİ", "ÜRETİM YERİ", "SATINALMA"]):
        return "MM_Modulu"
    elif any(k in metin_upper for k in ["MALİYET", "KONTROL", "TEYİDİ"]):
        return "CO_Modulu"

    return "modul_yok"


DEPARTMAN_GENELI_ISARETLERI = [
    "departmanı", "departmanında", "departmanındaki", "birimindeki",
    "ekibi", "ekibinde", "ekibindeki", "birden fazla kullanıcı",
    "tüm kullanıcılar", "bütün kullanıcılar", "herkes", "hiç kimse",
    "toplu", "tüm şirket", "tüm ofis", "tüm lokasyon", "bütün ekip"
]

BIREYSEL_ISARETLER = [
    "sadece ben", "sadece bende", "benim bilgisayarım", "kendi ekranımda",
    "bireysel", "benim hesabım", "sadece benim", "yanımdaki", "bende açılmıyor",
    "kendi işlemlerimi"
]
GURULTU_KELIMELER = [
    "merhaba", "merhabalar", "selam", "selamlar", "günaydın", "iyi",
    "çalışmalar", "günler", "kolay", "gelsin", "rica", "ederim",
    "ederiz", "teşekkürler", "teşekkür", "lütfen", "saygılarımla", "saygılar",
    "dilerim", "yardımcı", "olur", "musunuz", "ol", "al",

    "bir", "bu","bey", "şu", "o", "ve", "veya", "ile", "için", "daha", "en",
    "çok", "gibi", "kadar", "olan", "olarak", "ise", "da", "de", "mi", "mu",
    "mı", "mü", "ya", "var", "yok", "neden", "nasıl", "niçin", "hangi",
    "sonra", "önce", "göre", "tarafından", "şekilde", "ilgili", "dair",
    "hakkında", "tüm", "bütün", "her", "bazı", "şey", "diğer", "başka",

    "yi", "yı", "yu", "yü", "ni", "nı", "nu", "nü", "in", "ın", "un", "ün",
    "no", "numara", "numarası", "nd", "th", "veya"
]

IT_VARLIK_KOKLERI = [
    "bilgisayar", "sunucu", "sistem", "ağ", "ekran", "yazıcı", "hesap", "hesab",
    "şifre", "vpn", "sap", "server", "network", "mail", "e-posta", "eposta",
    "veritabanı", "database", "uygulama", "program", "telefon", "laptop",
    "printer", "monitör", "klavye", "fare", "internet", "portal", "yazılım",
    "domain", "sertifika", "şirket", "ofis", "departman", "ekip", "takım",
    "lokasyon", "şube", "fabrika", "depo",
]
_KOK_REGEX = "(?:" + "|".join(IT_VARLIK_KOKLERI) + ")"


_HAL_EKI = r"(?:i|ı|u|ü|e|a|de|da|den|dan|te|ta)?"

COGUL_IYELIK_REGEX = re.compile(
    _KOK_REGEX + r"'?(?:ımız|imiz|umuz|ümüz|mız|miz|muz|müz)" + _HAL_EKI + r"\b",
    re.IGNORECASE,
)
TEKIL_IYELIK_REGEX = re.compile(
    _KOK_REGEX + r"'?(?:ımı|imi|umu|ümü|ım|im|um|üm|m)" + _HAL_EKI + r"\b",
    re.IGNORECASE,
)

def sirket_geneli_iyelik_var_mi(text):
    return bool(COGUL_IYELIK_REGEX.search(str(text)))

def bireysel_iyelik_var_mi(text):
    if sirket_geneli_iyelik_var_mi(text):
        return False
    return bool(TEKIL_IYELIK_REGEX.search(str(text)))

def bireysel_sorun_mu(text):
    t_lower = str(text).lower()
    if any(k in t_lower for k in BIREYSEL_ISARETLER):
        return True
    return bireysel_iyelik_var_mi(text)

def departman_geneli_etkisi_var_mi(text):
    t_lower = str(text).lower()
    if any(k in t_lower for k in DEPARTMAN_GENELI_ISARETLERI):
        return True
    if sirket_geneli_iyelik_var_mi(text):
        return True
    if bireysel_sorun_mu(text):
        return False
    return False


BT_ANAHTAR_KELIMELER = ["bilgisayar", "sistem", "sap", "mail", "e-posta", "eposta", "şifre",
                         "parola", "ağ", "internet", "yazıcı", "ekran", "vpn", "sunucu",
                         "yazılım", "donanım", "hesap", "yetki", "erişim", "outlook", "monitör",
                         "printer", "network", "server", "modül", "fatura", "stok", "rapor",
                         "malzeme", "sipariş", "belge", "kalem", "üretim emri", "bakım",
                         "onay", "seri no", "seri numarası", "teslimat", "işlem", "hata",
                         "transaction", "tcode", "t-code", "kod", "veri", "senkron", "kayıt",
                         "giriş yapamıyorum", "açılmıyor", "kilitleniyor", "bağlanamıyor"]

def bt_ile_alakali_mi(text):
    t_lower = str(text).lower()
    return any(k in t_lower for k in BT_ANAHTAR_KELIMELER)

DUSUK_ETKI_KELIMELERI = ["yazıcı", "toner", "şifre", "fare", "klavye", "kısayol", "monitör", "kablo"]

def yalanci_acillik_var_mi(text):
    t_lower = str(text).lower()
    return "acil" in t_lower and any(k in t_lower for k in DUSUK_ETKI_KELIMELERI)


PLANLI_IS_KELIMELERI = [
    "kurulum", "kurulumu", "kurulması", "kurulmasını", "kuruluş",
    "talep", "talebi", "talep ediyorum",
    "yeni hesap", "yeni kullanıcı", "yeni kullanıcı hesabı",
    "tanımlama", "tanımlanması", "tanımlanmasını", "tanımlayabilir misiniz",
    "sağlanması", "sağlanmasını", "sağlayabilir misiniz",
    "geliştirme", "geliştirilmesi", "geliştirilmesini",
    "istiyorum", "rica ediyorum", "talep ediyoruz",
    "yetki talebi", "yetki tanımlaması", "yetki verilmesi",
    "açılması", "açılmasını", "oluşturulması", "oluşturulmasını",
    "temin", "temin edilmesi", "planlı iş", "kurulmasını istiyorum"
]

BLOKAJ_ISARETLERI = [
    "açmaya çalışıyoruz", "açamıyoruz", "girmeye çalışıyoruz", "girilemiyoruz",
    "yapamıyoruz", "oluşturamıyoruz", "yaratamıyoruz", "yaratılamıyoruz",
    "tamamlayamıyoruz", "ilerleyemiyoruz", "devam edemiyoruz", "kaydedemiyoruz",
    "hata alıyoruz", "hata veriyor", "hata aldık", "engelleniyor",
    "duruyor", "takıldık", "sıkıştık", "çözemedik", "başaramadık",
    "uğraştı ancak çözemedik", "bir türlü olmuyor"
]

def aktif_blokaj_var_mi(text):
    t_lower = str(text).lower()
    return any(k in t_lower for k in BLOKAJ_ISARETLERI)

def planli_is_var_mi(text):
    t_lower = str(text).lower()
    if aktif_blokaj_var_mi(t_lower):
        return False
    return any(k in t_lower for k in PLANLI_IS_KELIMELERI)


class ModulMultiHotEncoder(BaseEstimator, TransformerMixin):
    def __init__(self):
        self.mlb = MultiLabelBinarizer()

    @staticmethod
    def _to_list(X):
        seri = X.iloc[:, 0] if hasattr(X, "iloc") else X
        return [[] if v == "modul_yok" else [m.strip() for m in str(v).split(",")] for v in seri]

    def fit(self, X, y=None):
        self.mlb.fit(self._to_list(X))
        return self

    def transform(self, X):
        bilinen = set(self.mlb.classes_)
        etiket_listesi = [[m for m in etiketler if m in bilinen] for etiketler in self._to_list(X)]
        return self.mlb.transform(etiket_listesi)

    def get_feature_names_out(self, input_features=None):
        return [f"modul_{c}" for c in self.mlb.classes_]


ÖZELLİK_SÜTUNLARI = ['maskelenmis_metin', 'sap_modulu', 'departman_geneli_flag',
                      'bt_modulsuz_flag', 'yalanci_acillik_flag', 'planli_is_flag']

def veri_hazirla_ve_temizle(df):
    df['sla_level'] = pd.to_numeric(df['sla_level'], errors='coerce')
    df['konu'] = df['konu'].fillna('')
    df['sorun_aciklamasi'] = df['sorun_aciklamasi'].fillna('')
    df['metin'] = (df['konu'].astype(str) + " " + df['sorun_aciklamasi'].astype(str)).str.strip()
    df['maskelenmis_metin'] = df['metin'].apply(veriyi_maskele)
    df['sap_modulu'] = df['metin'].apply(sap_modul_analizi)

    df['departman_geneli_flag'] = df['metin'].apply(lambda m: int(departman_geneli_etkisi_var_mi(m)))

    df['bt_modulsuz_flag'] = df.apply(
        lambda r: int(r['sap_modulu'] == 'modul_yok' and bt_ile_alakali_mi(r['metin'])), axis=1)

    df['yalanci_acillik_flag'] = df['metin'].apply(lambda m: int(yalanci_acillik_var_mi(m)))
    df['planli_is_flag'] = df['metin'].apply(lambda m: int(planli_is_var_mi(m)))
    return df

def model_egit_ve_kaydet():
    if not os.path.exists(DOSYA_ADI):
        raise FileNotFoundError(f"'{DOSYA_ADI}' dosyası bulunamadı!")

    df = pd.read_json(DOSYA_ADI)
    df = veri_hazirla_ve_temizle(df)

    if 'kayit_turu' in df.columns:
        print("Dataset içinde 'kayit_turu' etiketi tespit edildi. Stratejik bölütleme uygulanıyor...")

        df_train_pool = df[df['kayit_turu'] == 'duzenli'].dropna(subset=['sla_level'])
        df_train_pool = df_train_pool[df_train_pool['sla_level'].between(1, 5)]

        df_test_pool = df[df['kayit_turu'] == 'duzensiz_etiketli'].dropna(subset=['sla_level'])
        df_test_pool = df_test_pool[df_test_pool['sla_level'].between(1, 5)]

        if len(df_train_pool) > 0:
            X_train = df_train_pool[ÖZELLİK_SÜTUNLARI]
            y_train = df_train_pool['sla_level'].astype(int)
        else:
             temiz_df = df.dropna(subset=['sla_level'])
             X = temiz_df[ÖZELLİK_SÜTUNLARI]
             y = temiz_df['sla_level'].astype(int)
             X_train, _, y_train, _ = train_test_split(X, y, test_size=0.2, random_state=42)

        print(f"Eğitim kümesi boyutu ('duzenli'): {len(X_train)} kayıt.")

        preprocessor = ColumnTransformer(
            transformers=[
        ('text', TfidfVectorizer(
            ngram_range=(1, 2),
            max_features=3000,
            lowercase=True,
            stop_words=GURULTU_KELIMELER
        ), 'maskelenmis_metin'),
        ('modul', ModulMultiHotEncoder(), ['sap_modulu']),

        ('departman_sinyali', 'passthrough', ['departman_geneli_flag']),
        ('bt_modulsuz_sinyali', 'passthrough', ['bt_modulsuz_flag']),
        ('yalanci_acillik_sinyali', 'passthrough', ['yalanci_acillik_flag']),
        ('planli_is_sinyali', 'passthrough', ['planli_is_flag']),
    ])

        taban_pipeline = Pipeline([
            ('preprocessor', preprocessor),
            ('clf', RandomForestClassifier(class_weight='balanced', n_estimators=300, random_state=42))
        ])

        pipeline = CalibratedClassifierCV(estimator=taban_pipeline, method='sigmoid', cv=3)
        pipeline.fit(X_train, y_train)

        if len(df_test_pool) > 0:
            X_test_real = df_test_pool[ÖZELLİK_SÜTUNLARI]
            y_test_real = df_test_pool['sla_level'].astype(int)
            y_pred = pipeline.predict(X_test_real)
            print("\n--- 'duzensiz_etiketli' (Bozuk/Dağınık Metinler) Üzerindeki Performans Raporu ---")
            print(classification_report(y_test_real, y_pred, zero_division=0))
        else:
            print("\nNot: 'duzensiz_etiketli' türünde kayıt bulunamadı.")

    else:
        print("Uyarı: 'kayit_turu' bulunamadı, standart train_test_split uygulanıyor.")
        temiz_df = df.dropna(subset=['sla_level'])
        temiz_df['sla_level'] = temiz_df['sla_level'].astype(int)

        X = temiz_df[ÖZELLİK_SÜTUNLARI]
        y = temiz_df['sla_level']

        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

        preprocessor = ColumnTransformer(
            transformers=[
                ('text', TfidfVectorizer(
                    ngram_range=(1, 2),
                    max_features=3000,
                    lowercase=True,
                    stop_words=GURULTU_KELIMELER
                ), 'maskelenmis_metin'),
                ('modul', ModulMultiHotEncoder(), ['sap_modulu']),
                ('departman_sinyali', 'passthrough', ['departman_geneli_flag']),
                ('bt_modulsuz_sinyali', 'passthrough', ['bt_modulsuz_flag']),
                ('yalanci_acillik_sinyali', 'passthrough', ['yalanci_acillik_flag']),
                ('planli_is_sinyali', 'passthrough', ['planli_is_flag']),
            ])

        pipeline = Pipeline([
            ('preprocessor', preprocessor),
            ('clf', RandomForestClassifier(class_weight='balanced', n_estimators=300, random_state=42))
        ])

        pipeline.fit(X_train, y_train)

        y_pred = pipeline.predict(X_test)
        print("\n--- Test Seti Performans Raporu ---")
        print(classification_report(y_test, y_pred, zero_division=0))

    joblib.dump(pipeline, MODEL_DOSYASI)
    print(f"Model eğitildi ve '{MODEL_DOSYASI}' olarak kaydedildi.\n")
    return pipeline

def model_guncel_mi():
    if not os.path.exists(MODEL_DOSYASI):
        return False
    if not os.path.exists(DOSYA_ADI):
        return True
    veri_guncel_mi = os.path.getmtime(MODEL_DOSYASI) > os.path.getmtime(DOSYA_ADI)

    kod_guncel_mi = os.path.getmtime(MODEL_DOSYASI) > os.path.getmtime(__file__)
    return veri_guncel_mi and kod_guncel_mi

if model_guncel_mi():
    best_model = joblib.load(MODEL_DOSYASI)
    print(f"Güncel model '{MODEL_DOSYASI}' üzerinden yüklendi.")
else:
    best_model = model_egit_ve_kaydet()


def sla_karar_mekanizmasi(tahmin_sinifi, olasilik_skoru):
    tahmin_sinifi = int(tahmin_sinifi)
    if tahmin_sinifi in [1, 2]:
        if olasilik_skoru >= 0.70:
            return f"OTOMATİK ATANDI -> SLA Seviyesi {tahmin_sinifi} (Güven: %{olasilik_skoru*100:.1f})"
        else:
            return f"MANUEL ONAY HAVUZU -> SLA Seviyesi {tahmin_sinifi} (Güven yetersiz: %{olasilik_skoru*100:.1f} < %90)"
    else:
        if olasilik_skoru >= 0.40:
            return f"OTOMATİK İŞLEME ALINDI -> SLA Seviyesi {tahmin_sinifi} (Güven: %{olasilik_skoru*100:.1f})"
        else:
            return f"MANUEL ONAY HAVUZU -> SLA Seviyesi {tahmin_sinifi} (Güven yetersiz: %{olasilik_skoru*100:.1f} < %70)"


UNLU_HARFLER = set("aeıioöuüAEIİOÖUÜ")
SPAM_ANAHTAR_KELIMELER = ["tebrikler", "hediye çeki", "kazandınız", "%0 faiz", "garantili kazanç",
                          "abonelikten çık", "yatırım fırsatı", "linke tıklayın", "tıklayınız"]

def metin_saglamlik_kontrolu(text):
    if text is None:
        return False, "Boş içerik (None)"
    t = str(text).strip()
    if len(t) < 5:
        return False, "Çok kısa/boş içerik"

    harfler = [c for c in t if c.isalpha()]
    if len(harfler) < 4:
        return False, "Alfabetik içerik yetersiz (emoji/sembol ağırlıklı)"

    unlu_orani = sum(1 for c in harfler if c in UNLU_HARFLER) / len(harfler)
    if unlu_orani < 0.15 or unlu_orani > 0.70:
        return False, f"Anlamsız karakter dizisi şüphesi (ünlü oranı: %{unlu_orani*100:.0f})"

    kelimeler = [w for w in re.findall(r"[a-zA-ZçğıöşüÇĞİÖŞÜ]+", t) if len(w) > 1]
    if len(kelimeler) < 2:
        return False, "Yeterli sayıda anlamlı kelime bulunamadı"

    t_lower = t.lower()
    if any(k in t_lower for k in SPAM_ANAHTAR_KELIMELER):
        return False, "Olası spam / reklam içeriği"

    return True, "OK"


def tahmin_nedenini_acikla(model, test_df, top_n=5):
    try:
        base_pipe = model.calibrated_classifiers_[0].estimator if hasattr(model, 'calibrated_classifiers_') else model
        pre = base_pipe.named_steps['preprocessor']
        clf = base_pipe.named_steps['clf']

        X = pre.transform(test_df)
        if hasattr(X, 'toarray'):
            X = X.toarray()
        satir = X[0]
        onemler = clf.feature_importances_
        isimler = pre.get_feature_names_out()

        katkilar = [(isim, deger * onem) for isim, deger, onem in zip(isimler, satir, onemler) if deger != 0]
        katkilar.sort(key=lambda x: x[1], reverse=True)

        kelimeler, sinyaller = [], []
        for isim, _ in katkilar:
            if isim.startswith('text__'):
                k = isim.replace('text__', '')
                if k not in kelimeler:
                    kelimeler.append(k)
            elif isim.startswith('modul__modul_'):
                sinyaller.append(f"SAP modülü: {isim.replace('modul__modul_', '')}")
            elif isim == 'departman_sinyali__departman_geneli_flag':
                sinyaller.append("şirket/departman geneli ifade var")
            elif isim == 'bt_modulsuz_sinyali__bt_modulsuz_flag':
                sinyaller.append("BT ile ilişkili ama T-Code/modül tespit edilemedi")
            elif isim == 'yalanci_acillik_sinyali__yalanci_acillik_flag':
                sinyaller.append("'acil' + düşük etkili donanım/bireysel kelime bir arada")
            elif isim == 'planli_is_sinyali__planli_is_flag':
                sinyaller.append("kurulum/talep/yetki gibi planlı iş ifadesi var")

        parcalar = []
        if sinyaller:
            parcalar.append(", ".join(dict.fromkeys(sinyaller)))
        if kelimeler:
            parcalar.append("etkili kelimeler: " + ", ".join(kelimeler[:top_n]))
        return " | ".join(parcalar) if parcalar else "belirgin tekil bir sinyal yok, genel metin kalıbına göre tahmin edildi"
    except Exception as e:
        return f"(açıklama üretilemedi: {e})"


def gorselden_metin_oku(dosya_yolu):
    try:
        if not os.path.exists(dosya_yolu):
            return f"[HATA] '{dosya_yolu}' dosyası bulunamadı. Lütfen dosya adını kontrol edin."

        resim = Image.open(dosya_yolu)
        metin = pytesseract.image_to_string(resim, lang='tur+eng')
        return metin.strip()
    except Exception as e:
        return f"[HATA] Görsel okunurken sorun yaşandı: {e}"


def _sade_cikti(sla, guven, manuel_mi, neden):
    print(f"SLA Seviyesi: {sla if sla is not None else '-'}")
    print(f"Güven Oranı: {'%' + format(guven*100, '.1f') if guven is not None else '-'}")
    print(f"Manuel Onay Havuzuna Düştü mü: {'Evet' if manuel_mi else 'Hayır'}")
    print(f"Neden: {neden}")
    print("=" * 60)


def gelen_maili_veya_gorseli_isle(girdi_verisi, tip='metin'):
    if tip == 'gorsel':
        ham_mail_metni = gorselden_metin_oku(girdi_verisi)
        if ham_mail_metni.startswith("[HATA]"):
            _sade_cikti(None, None, True, ham_mail_metni)
            return
    else:
        ham_mail_metni = str(girdi_verisi)

    if not ham_mail_metni.strip():
        _sade_cikti(None, None, True, "İçerik çok kısa veya boş.")
        return

    gecerli_mi, sebep = metin_saglamlik_kontrolu(ham_mail_metni)
    if not gecerli_mi:
        _sade_cikti(None, None, True, sebep)
        return

    maskelenmis = veriyi_maskele(ham_mail_metni)
    tespit_edilen_modul = sap_modul_analizi(ham_mail_metni)
    departman_geneli_mi = departman_geneli_etkisi_var_mi(ham_mail_metni)
    bt_modulsuz_mu = (tespit_edilen_modul == "modul_yok") and bt_ile_alakali_mi(ham_mail_metni)
    yalanci_acillik_mi = yalanci_acillik_var_mi(ham_mail_metni)
    planli_is_mi = planli_is_var_mi(ham_mail_metni)

    test_df = pd.DataFrame([{
        'maskelenmis_metin': maskelenmis,
        'sap_modulu': tespit_edilen_modul,
        'departman_geneli_flag': int(departman_geneli_mi),
        'bt_modulsuz_flag': int(bt_modulsuz_mu),
        'yalanci_acillik_flag': int(yalanci_acillik_mi),
        'planli_is_flag': int(planli_is_mi),
    }])

    tahmin = int(best_model.predict(test_df)[0])

    if hasattr(best_model, "predict_proba"):
        olasiliklar = best_model.predict_proba(test_df)[0]
        en_yuksek_olasilik = max(olasiliklar)
    else:
        en_yuksek_olasilik = 0.85

    if en_yuksek_olasilik < 0.35:
        _sade_cikti(tahmin, en_yuksek_olasilik, True,
                    "Model bu metindeki kelimeleri tanımıyor (güven %35'in altında, yabancı/bilinmeyen içerik).")
        return

    karar_metni = sla_karar_mekanizmasi(tahmin, en_yuksek_olasilik)
    manuel_mi = "MANUEL ONAY HAVUZU" in karar_metni
    neden = tahmin_nedenini_acikla(best_model, test_df)

    _sade_cikti(tahmin, en_yuksek_olasilik, manuel_mi, neden)

if __name__ == "__main__":
    print("\n--- IT HELP DESK CANLI OTOMATİK SLA YÖNETİCİSİ ---")
    print("Sisteme düşen ham mailleri VEYA fotoğraf dosyalarını (örn: ekran.png) test edebilirsiniz.")
    print("Çıkmak için klavyeden 'q' tuşuna basın.\n")

    while True:
        kullanici_girisi = input("Simüle edilecek metin VEYA resim adı: ")

        kullanici_girisi = kullanici_girisi.strip(" '\"")

        if kullanici_girisi.lower() == 'q':
            print("Sistemden çıkılıyor...")
            break
        if not kullanici_girisi:
            continue

        if kullanici_girisi.lower().endswith(('.png', '.jpg', '.jpeg')):
            gelen_maili_veya_gorseli_isle(kullanici_girisi, tip='gorsel')
        else:
            gelen_maili_veya_gorseli_isle(kullanici_girisi, tip='metin')