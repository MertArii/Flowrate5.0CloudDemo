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

DOSYA_ADI = 'emails_sla_seviyeli.json' # Veri setin
MODEL_DOSYASI = 'model.pkl'
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

DOSYA_ADI = os.path.join(
    BASE_DIR,
    'emails_sla_seviyeli.json'
)

MODEL_DOSYASI = os.path.join(
    BASE_DIR,
    'model.pkl'
)

JSON_SOZLUK_YOLU = os.path.join(
    BASE_DIR,
    'knowledge_base',
    'modul_sozlugu.json'
)

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
    
    # 1. Aşama: Kesin T-Code (İşlem Kodu) Taraması
    sap_kurallari = {
        "SD_Modulu": r'\b(VA\d{2}[A-Z]*|VL\d{2}[A-Z]*|VF\d{2}[A-Z]*)\b',
        "MM_Modulu": r'\b(ME\d{2}[A-Z]*|MI[A-Z]{2}|MB\d{2})\b',
        "FI_Modulu": r'\b(FB\d{2}[A-Z]*|F-\d{2}|FS\d{2})\b',
        "CO_Modulu": r'\b(CK\d{2}[A-Z]*|CO\d{2}[A-Z]*|KS\d{2})\b',
        "BASIS_Modulu": r'\b(SU\d{2}|PFCG|SM\d{2})\b'
    }
    
    for modul_adi, regex_kurali in sap_kurallari.items():
        if re.search(regex_kurali, metin_upper):
            print(f"✅ [SİSTEM - TCode]: Metinde {modul_adi} tespit edildi.")
            return modul_adi
            
    # 2. Aşama: T-Code Bulunamadıysa Anlamsal Anahtar Kelime Taraması (Keyword Fallback)
    if any(k in metin_upper for k in ["SİPARİŞ", "TESLİMAT", "FATURA", "SD BELGESİ"]):
        print(" [SİSTEM - Anlamsal]: Kelime bazlı SD (Satış) Modülü eşleştirildi.")
        return "SD_Modulu"
    elif any(k in metin_upper for k in ["MALZEME", "STOK", "MAL GİRİŞİ", "ÜRETİM YERİ", "SATINALMA"]):
        print(" [SİSTEM - Anlamsal]: Kelime bazlı MM (Malzeme) Modülü eşleştirildi.")
        return "MM_Modulu"
    elif any(k in metin_upper for k in ["MALİYET", "KONTROL", "TEYİDİ"]):
        print(" [SİSTEM - Anlamsal]: Kelime bazlı CO (Maliyet) Modülü eşleştirildi.")
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
    """'-mız/-miz/-muz/-müz' (biz-iyelik) eki BT varlığı üzerindeyse True.
    Örn: 'sunucumuz çöktü', 'VPN'imiz düşüyor', 'ağımız kesildi'."""
    return bool(COGUL_IYELIK_REGEX.search(str(text)))

def bireysel_iyelik_var_mi(text):
    """'-ım/-im/-um/-üm/-m' (ben-iyelik) eki BT varlığı üzerindeyse True.
    Örn: 'bilgisayarım açılmıyor', 'şifremi unuttum'."""
    if sirket_geneli_iyelik_var_mi(text):
        return False  # çoğul ek bulunduysa tekil eşleşmesini geçersiz say
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


ÖZELLİK_SÜTUNLARI = ['maskelenmis_metin', 'sap_modulu', 'departman_geneli_flag']

def veri_hazirla_ve_temizle(df):
    df['sla_level'] = pd.to_numeric(df['sla_level'], errors='coerce')
    df['konu'] = df['konu'].fillna('')
    df['sorun_aciklamasi'] = df['sorun_aciklamasi'].fillna('')
    df['metin'] = (df['konu'].astype(str) + " " + df['sorun_aciklamasi'].astype(str)).str.strip()
    df['maskelenmis_metin'] = df['metin'].apply(veriyi_maskele)
    df['sap_modulu'] = df['metin'].apply(sap_modul_analizi)
    df['departman_geneli_flag'] = df['metin'].apply(lambda m: int(departman_geneli_etkisi_var_mi(m)))
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
                ('text', TfidfVectorizer(ngram_range=(1, 2), max_features=3000, lowercase=True), 'maskelenmis_metin'),
                ('modul', ModulMultiHotEncoder(), ['sap_modulu']),
                # YENİ: departman/şirket geneli mi bireysel mi sinyali - gerçek eğitim özelliği
                ('departman_sinyali', 'passthrough', ['departman_geneli_flag']),
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
                ('text', TfidfVectorizer(ngram_range=(1, 2), max_features=3000, lowercase=True), 'maskelenmis_metin'),
                ('modul', ModulMultiHotEncoder(), ['sap_modulu']),
                ('departman_sinyali', 'passthrough', ['departman_geneli_flag']),
            ])

        pipeline = Pipeline([
            ('preprocessor', preprocessor),
            ('clf', RandomForestClassifier(class_weight='balanced', n_estimators=300, random_state=42))
        ])

        pipeline.fit(X_train, y_train)

        #pipeline = CalibratedClassifierCV(estimator=taban_pipeline, method='sigmoid', cv=3)
        #pipeline.fit(X_train, y_train)
        
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
BT_ANAHTAR_KELIMELER = ["bilgisayar", "sistem", "sap", "mail", "e-posta", "eposta", "şifre",
                         "parola", "ağ", "internet", "yazıcı", "ekran", "vpn", "sunucu",
                         "yazılım", "donanım", "hesap", "yetki", "erişim", "outlook", "monitör",
                         "printer", "network", "server", "modül", "fatura", "stok", "rapor",
                         # SAP işlem/master-data terimleri (eskiden eksikti; bu yüzden gerçek
                         # SAP hataları "BT ile alakasız" sayılıp yanlış yönlendirme uyarısı
                         # alıyor ve heuristic boost'tan yararlanamıyordu):
                         "malzeme", "sipariş", "belge", "kalem", "üretim emri", "bakım",
                         "onay", "seri no", "seri numarası", "teslimat", "işlem", "hata",
                         "transaction", "tcode", "t-code", "kod", "veri", "senkron", "kayıt",
                         "giriş yapamıyorum", "açılmıyor", "kilitleniyor", "bağlanamıyor"]

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

def bt_ile_alakali_mi(text):
    t_lower = str(text).lower()
    return any(k in t_lower for k in BT_ANAHTAR_KELIMELER)


def gorselden_metin_oku(dosya_yolu):
    try:
        if not os.path.exists(dosya_yolu):
            return f"[HATA] '{dosya_yolu}' dosyası bulunamadı. Lütfen dosya adını kontrol edin."
            
        resim = Image.open(dosya_yolu)
        metin = pytesseract.image_to_string(resim, lang='tur+eng')
        print(f"\n[📷 OCR Başarılı] Görselden Okunan Metin:\n{metin.strip()}")
        return metin.strip()
    except Exception as e:
        return f"[HATA] Görsel okunurken sorun yaşandı: {e}"

def gelen_maili_veya_gorseli_isle(girdi_verisi, tip='metin'):
    if tip == 'gorsel':
        ham_mail_metni = gorselden_metin_oku(girdi_verisi)
        if ham_mail_metni.startswith("[HATA]"):
            print(ham_mail_metni)
            return
    else:
        ham_mail_metni = str(girdi_verisi)

    if not ham_mail_metni.strip():
        print("Sistem Kararı: İNCELENEMEDİ / MANUEL HAVUZA DÜŞTÜ -> Gerekçe: İçerik çok kısa veya boş.")
        print("=" * 60)
        return

    print(f"\n[Analiz Edilen İçerik]: {ham_mail_metni}")

    gecerli_mi, sebep = metin_saglamlik_kontrolu(ham_mail_metni)
    if not gecerli_mi:
        print(f"Sistem Kararı: İNCELENEMEDİ / MANUEL HAVUZA DÜŞTÜ -> Gerekçe: {sebep}")
        print("=" * 60)
        return

    maskelenmis = veriyi_maskele(ham_mail_metni)
    tespit_edilen_modul = sap_modul_analizi(ham_mail_metni)
    departman_geneli_mi = departman_geneli_etkisi_var_mi(ham_mail_metni)

    test_df = pd.DataFrame([{
        'maskelenmis_metin': maskelenmis,
        'sap_modulu': tespit_edilen_modul,
        'departman_geneli_flag': int(departman_geneli_mi),
    }])

    tahmin = best_model.predict(test_df)[0]
    
    if hasattr(best_model, "predict_proba"):
        olasiliklar = best_model.predict_proba(test_df)[0]
        en_yuksek_olasilik = max(olasiliklar)
    else:
        en_yuksek_olasilik = 0.85

    if en_yuksek_olasilik < 0.35:
        print(f"[KVKK Maskelenmiş Hali]: {maskelenmis}")
        print("🚨 [SİSTEM UYARISI]: Model bu metindeki kelimeleri tanımıyor (Güven %35'in altında).")
        print("Sistem Kararı: MANUEL ONAY HAVUZU -> Gerekçe: Yabancı/Bilinmeyen İçerik")
        print("=" * 60)
        return

    boost_uygulandi_mi = False
    boost_miktari = 0.0
    ceza_uygulandi_mi = False

    # A) Heuristic Boost (Model kod bulamadıysa ama BT kelimeleri varsa destek ver)
    if tespit_edilen_modul == "modul_yok" and bt_ile_alakali_mi(ham_mail_metni):
        if en_yuksek_olasilik < 0.85:
            boost_miktari = 0.15
            en_yuksek_olasilik += boost_miktari
            if en_yuksek_olasilik > 0.99:
                en_yuksek_olasilik = 0.99
            boost_uygulandi_mi = True

    DUSUK_ETKI_KELIMELERI = ["yazıcı", "toner", "şifre", "fare", "klavye", "kısayol", "monitör", "kablo"]
    t_lower = ham_mail_metni.lower()
    
    if "acil" in t_lower and any(k in t_lower for k in DUSUK_ETKI_KELIMELERI):
        if tahmin in [1, 2]:
            en_yuksek_olasilik -= 0.40  # Güven skorunu %40 düşür
            ceza_uygulandi_mi = True

    departman_sinyali_bilgi_notu = (tahmin in [1, 2]) and (not departman_geneli_mi)

    if en_yuksek_olasilik < 0.01:
        en_yuksek_olasilik = 0.01

    # 5. Sonuçları Ekrana Yazdırma
    print(f"[KVKK Maskelenmiş Hali]: {maskelenmis}")
    print(f"[Algılanan SAP Modülü]: {tespit_edilen_modul}")
    print(f"[Departman/Şirket Geneli Sinyali]: {'VAR' if departman_geneli_mi else 'YOK'} (eğitim özelliği: departman_geneli_flag={int(departman_geneli_mi)})")
    
    if ceza_uygulandi_mi:
        print(f" [YALANCI ACİLİYET TESPİTİ]: 'Acil' kullanılmış ancak donanım/bireysel sorun tespit edildi! (Güven -%30)")
        print(f"Model Tahmini: SLA Seviyesi {tahmin} (%{en_yuksek_olasilik*100:.1f} güven) [📉 CEZA UYGULANDI]")
    elif boost_uygulandi_mi:
        print(f"Model Tahmini: SLA Seviyesi {tahmin} (%{en_yuksek_olasilik*100:.1f} güven) [⚡ HEURISTIC BOOST +%{boost_miktari*100:.0f} UYGULANDI]")
    else:
        print(f"Model Tahmini: SLA Seviyesi {tahmin} (%{en_yuksek_olasilik*100:.1f} güven)")

    if departman_sinyali_bilgi_notu:
        print(f" ℹ️  [BİLGİ]: SLA {tahmin} tahmin edildi ama metinde çoğul-iyelik ('...miz/...muz') veya 'departmanı/herkes/toplu' gibi şirket geneli bir ifade tespit edilmedi. Model bu sinyali zaten eğitim sırasında öğrendi (departman_geneli_flag=0); yine de düşük skorlarda insan kontrolü önerilir.")

    if boost_uygulandi_mi:
        print("Sistem Kararı: MANUEL ONAY HAVUZU -> Gerekçe: Tahmin yalnızca heuristic boost sayesinde eşiği geçti, modelin ham güveni yetersizdi.")
    else:
        print(f"Sistem Kararı: {sla_karar_mekanizmasi(tahmin, en_yuksek_olasilik)}")
    if not bt_ile_alakali_mi(ham_mail_metni):
        print("Uyarı: Metinde BT ile ilişkili anahtar kelime bulunamadı, talep yanlış birime gönderilmiş olabilir.")
    print("=" * 60)

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