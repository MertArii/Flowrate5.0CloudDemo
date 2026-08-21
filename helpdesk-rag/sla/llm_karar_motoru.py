import os
import re
import json
import time
import requests
import psycopg2
import psycopg2.extras
import pandas as pd

import __main__


from sla_model_egitici import ModulMultiHotEncoder
__main__.ModulMultiHotEncoder = ModulMultiHotEncoder

from sla_model_egitici import (
    veriyi_maskele,
    sap_modul_analizi,
    departman_geneli_etkisi_var_mi,
    bt_ile_alakali_mi,
    yalanci_acillik_var_mi,
    planli_is_var_mi,
    aktif_blokaj_var_mi,
    metin_saglamlik_kontrolu,
    sla_karar_mekanizmasi,
    tahmin_nedenini_acikla,
    gorselden_metin_oku,
)


# os.environ.get kısımlarını tamamen siliyoruz, doğrudan isimleri veriyoruz:
OLLAMA_HOST = "http://localhost:11434"
KARAR_MODELI = "qwen3:8b"
EMBEDDING_MODELI = "bge-m3:latest"
MAX_LLM_DENEME = 2

try:
    import db_baglanti
    BAGLANTI_HAVUZU_MEVCUT = True
except ImportError:
    BAGLANTI_HAVUZU_MEVCUT = False

    def _yedek_baglanti_al():
        for deneme in range(3):
            try:
                return psycopg2.connect(
                    host=os.environ.get("PGHOST", "127.0.0.1"),
                    port=os.environ.get("PGPORT", "5433"),
                    dbname=os.environ.get("PGDATABASE", "helpdesk"),
                    user=os.environ.get("PGUSER", "helpdesk"),
                    password=os.environ.get("PGPASSWORD", "demopw"),
                    connect_timeout=5,
                )
            except psycopg2.OperationalError as e:
                print(f"Uyarı: veritabanı bağlantı denemesi {deneme + 1} başarısız: {e}")
                time.sleep(2 ** deneme)
        raise ConnectionError("Veritabanına bağlanılamadı, 3. aşamadaki tünel/havuz mekanizmasını kontrol edin.")

    class _YedekBaglantiHavuzu:
        def baglanti_al(self):
            return _yedek_baglanti_al()

    db_baglanti = _YedekBaglantiHavuzu()


def on_sinyalleri_olustur(ham_metin):
    maskelenmis = veriyi_maskele(ham_metin)
    sap_modulu = sap_modul_analizi(ham_metin)
    return {
        "maskelenmis_metin": maskelenmis,
        "sap_modulu": sap_modulu,
        "departman_geneli_flag": departman_geneli_etkisi_var_mi(ham_metin),
        "bt_modulsuz_flag": (sap_modulu == "modul_yok") and bt_ile_alakali_mi(ham_metin),
        "yalanci_acillik_flag": yalanci_acillik_var_mi(ham_metin),
        "planli_is_flag": planli_is_var_mi(ham_metin),
        "aktif_blokaj_flag": aktif_blokaj_var_mi(ham_metin),
    }


def metni_vektorlestir(metin):
    yanit = requests.post(
        f"{OLLAMA_HOST}/api/embeddings",
        json={"model": EMBEDDING_MODELI, "prompt": metin},
        timeout=15,
    )
    yanit.raise_for_status()
    return yanit.json()["embedding"]


def benzer_gecmis_kayitlari_getir(conn, maskelenmis_metin, top_k=3):
    vektor = metni_vektorlestir(maskelenmis_metin)
    sorgu = """
        SELECT ts.problem_text AS maskelenmis_metin,
               ts.solution_text AS cozum_ozeti,
               u.full_name AS atanan_personel,
               t.priority AS sla_level,
               1 - (ts.embedding <=> %s::vector) AS benzerlik
        FROM ticket_solutions ts
        JOIN tickets t ON t.id = ts.ticket_id
        LEFT JOIN users u ON u.id = t.assigned_agent_id
        ORDER BY ts.embedding <=> %s::vector
        LIMIT %s;
    """
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(sorgu, (vektor, vektor, top_k))
        return cur.fetchall()


def personel_uzmanlik_getir(conn, sap_modulu, limit=3):
    if sap_modulu == "modul_yok":
        return []
    sorgu = """
        SELECT u.full_name AS ad_soyad,
               u.uzman_kategorileri AS uzmanlik_alani,
               COUNT(t.id) FILTER (
                   WHERE t.status NOT IN ('closed', 'resolved')
               ) AS aktif_ticket_sayisi
        FROM users u
        LEFT JOIN tickets t ON t.assigned_agent_id = u.id
        WHERE EXISTS (
            SELECT 1 FROM unnest(u.uzman_kategorileri) AS kategori
            WHERE kategori ILIKE %s
        )
        GROUP BY u.id, u.full_name, u.uzman_kategorileri
        ORDER BY aktif_ticket_sayisi ASC
        LIMIT %s;
    """
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(sorgu, (f"%{sap_modulu}%", limit))
        return cur.fetchall()


JSON_SEMASI = {
    "sla_seviyesi": "1-5 arası tam sayı",
    "guven_skoru": "0.0-1.0 arası ondalık sayı",
    "onerilen_departman": "string",
    "onerilen_personel": "string veya null",
    "gerekce": "kısa string",
    "manuel_onaya_gonder": "true/false",
}


def llm_karar_promptu_olustur(sinyaller, benzer_kayitlar, personel_onerileri):
    baglam_parcalari = [
        f"Maskelenmiş talep metni: {sinyaller['maskelenmis_metin']}",
        f"Tespit edilen SAP modülü: {sinyaller['sap_modulu']}",
        f"Departman geneli etkisi: {'evet' if sinyaller['departman_geneli_flag'] else 'hayır'}",
        f"BT ile ilişkili ama modül tespit edilemedi: {'evet' if sinyaller['bt_modulsuz_flag'] else 'hayır'}",
        f"Yanlış acillik sinyali: {'evet' if sinyaller['yalanci_acillik_flag'] else 'hayır'}",
        f"Planlı iş sinyali: {'evet' if sinyaller['planli_is_flag'] else 'hayır'}",
        f"Aktif blokaj sinyali: {'evet' if sinyaller['aktif_blokaj_flag'] else 'hayır'}",
    ]

    if benzer_kayitlar:
        baglam_parcalari.append("Anlamsal olarak benzer geçmiş kayıtlar:")
        for kayit in benzer_kayitlar:
            baglam_parcalari.append(
                f"- (benzerlik %{kayit['benzerlik']*100:.0f}) SLA {kayit['sla_level']}, "
                f"çözen: {kayit['atanan_personel']}, özet: {kayit['cozum_ozeti']}"
            )
    else:
        baglam_parcalari.append("Anlamsal olarak benzer geçmiş kayıt bulunamadı.")

    if personel_onerileri:
        baglam_parcalari.append("Bu modülde uzman ve müsait personel:")
        for p in personel_onerileri:
            baglam_parcalari.append(
                f"- {p['ad_soyad']} ({p['uzmanlik_alani']}, aktif iş yükü: {p['aktif_ticket_sayisi']})"
            )

    baglam = "\n".join(baglam_parcalari)

    return f"""Sen bir IT Help Desk SLA ve yönlendirme karar mekanizmasısın.
Aşağıdaki bağlamı değerlendirerek karar ver.

{baglam}

SLA seviyeleri: 1-2 kritik/acil arıza, 3 standart arıza, 4 orta öncelik talep, 5 planlı iş/kurulum.
Aktif blokaj sinyali varsa bunu planlı iş olarak değerlendirme; kullanıcı şu an bloke olmuş demektir.

SADECE aşağıdaki alanları içeren geçerli bir JSON nesnesi döndür.
Markdown, ```json işareti, açıklama cümlesi, kod bloğu KULLANMA. Sadece ham JSON.

Şema:
{json.dumps(JSON_SEMASI, ensure_ascii=False, indent=2)}
"""


def _json_ayikla(ham_yanit):
    temiz = ham_yanit.strip()
    temiz = re.sub(r"^```(json)?", "", temiz).strip()
    temiz = re.sub(r"```$", "", temiz).strip()
    return json.loads(temiz)


def karar_json_gecerli_mi(veri):
    if not isinstance(veri, dict):
        return False
    zorunlu_alanlar = ["sla_seviyesi", "guven_skoru", "onerilen_departman", "gerekce", "manuel_onaya_gonder"]
    if not all(alan in veri for alan in zorunlu_alanlar):
        return False
    if not isinstance(veri["sla_seviyesi"], int) or not (1 <= veri["sla_seviyesi"] <= 5):
        return False
    if not isinstance(veri["guven_skoru"], (int, float)) or not (0.0 <= float(veri["guven_skoru"]) <= 1.0):
        return False
    return True


def llm_ile_karar_al(prompt):
    for deneme in range(MAX_LLM_DENEME):
        try:
            yanit = requests.post(
                f"{OLLAMA_HOST}/api/generate",
                json={
                    "model": KARAR_MODELI,
                    "prompt": prompt,
                    "format": "json",
                    "stream": False,
                    "options": {"temperature": 0.1},
                },
                timeout=30,
            )
            yanit.raise_for_status()
            ham_yanit = yanit.json()["response"]
            karar = _json_ayikla(ham_yanit)
            if karar_json_gecerli_mi(karar):
                karar["kaynak"] = "llm"
                return karar
            print(f"Uyarı: LLM geçersiz şema döndürdü (deneme {deneme + 1}/{MAX_LLM_DENEME}): {karar}")
        except (requests.RequestException, json.JSONDecodeError, KeyError) as e:
            print(f"Uyarı: LLM çağrısı başarısız (deneme {deneme + 1}/{MAX_LLM_DENEME}): {e}")
        time.sleep(1)
    return None


def kural_tabanli_yedek_karar(sinyaller):
    # Model yüklenmediği için predict satırlarını sildik.
    # LLM veya veritabanı bağlantısı koptuğunda sistem çökmez, bu güvenli JSON'ı döner.
    return {
        "sla_seviyesi": "Manuel Atama",
        "guven_skoru": 0.0,
        "onerilen_departman": sinyaller.get("sap_modulu", "modul_yok"),
        "onerilen_personel": "Havuz (Manuel Onay)",
        "gerekce": "Yapay zeka (LLM) veya veritabanı bağlantısı kurulamadığı için otomatik atama yapılamadı.",
        "manuel_onaya_gonder": True,
        "kaynak": "guvenli_yedek_mod"
    }

def karari_uygula(ham_metin, db_baglantisi_kullan=True):
    gecerli_mi, sebep = metin_saglamlik_kontrolu(ham_metin)
    if not gecerli_mi:
        return {
            "sla_seviyesi": None,
            "guven_skoru": None,
            "onerilen_departman": None,
            "onerilen_personel": None,
            "gerekce": sebep,
            "manuel_onaya_gonder": True,
            "kaynak": "on_filtre_red",
            "rag_baglami_kullanildi": False,
        }

    sinyaller = on_sinyalleri_olustur(ham_metin)

    benzer_kayitlar, personel_onerileri = [], []
    if db_baglantisi_kullan:
        conn = None
        try:
            conn = db_baglanti.baglanti_al()
            benzer_kayitlar = benzer_gecmis_kayitlari_getir(conn, sinyaller["maskelenmis_metin"])
            personel_onerileri = personel_uzmanlik_getir(conn, sinyaller["sap_modulu"])
        except Exception as e:
            print(f"Uyarı: RAG/personel sorgusu alınamadı, LLM bağlamsız devam edecek: {e}")
        finally:
            if conn is not None:
                conn.close()

    rag_baglami_var = bool(benzer_kayitlar or personel_onerileri)

    prompt = llm_karar_promptu_olustur(sinyaller, benzer_kayitlar, personel_onerileri)
    llm_karari = llm_ile_karar_al(prompt)

    if llm_karari is not None:
        llm_karari["rag_baglami_kullanildi"] = rag_baglami_var
        return llm_karari

    print("Uyarı: LLM'den geçerli karar alınamadı, kural tabanlı modele düşülüyor.")
    yedek_karar = kural_tabanli_yedek_karar(sinyaller)
    yedek_karar["rag_baglami_kullanildi"] = rag_baglami_var
    return yedek_karar


if __name__ == "__main__":
    print("\n--- LLM + RAG DESTEKLİ SLA KARAR MOTORU ---")
    print("Sisteme düşen ham mailleri VEYA fotoğraf dosyalarını (örn: ekran.png) test edebilirsiniz.")
    print("Çıkmak için 'q' yazın.\n")

    while True:
        # Sürükle-bırak yapıldığında oluşan tırnakları temizlemek için strip(" '\"")
        kullanici_girisi = input("Simüle edilecek metin VEYA resim adı: ").strip(" '\"")

        if kullanici_girisi.lower() == "q":
            print("Sistemden çıkılıyor...")
            break

        if not kullanici_girisi:
            continue

        # Girilen değerin bir görsel dosyası olup olmadığını kontrol et
        if kullanici_girisi.lower().endswith(('.png', '.jpg', '.jpeg')):
            print("Görsel algılandı. Tesseract OCR ile metin okunuyor...")
            islenmis_metin = gorselden_metin_oku(kullanici_girisi)

            # Eğer OCR sırasında dosya bulunamazsa veya hata olursa
            if islenmis_metin.startswith("[HATA]"):
                print(islenmis_metin)
                print("=" * 60)
                continue

            print(f"Görselden Okunan Metin: {islenmis_metin}\n")
        else:
            # Görsel değilse, doğrudan metin olarak kabul et
            islenmis_metin = kullanici_girisi

        # Çıkan metni LLM karar motoruna (veya orkestrasyon fonksiyonuna) gönder
        print("Yapay Zeka (LLM) karar üretiyor, lütfen bekleyin...")
        sonuc = karari_uygula(islenmis_metin)

        print("\n--- LLM KARAR ÇIKTISI ---")
        if sonuc:
            print(json.dumps(sonuc, ensure_ascii=False, indent=2))
        else:
            print("Karar üretilemedi (JSON ayrıştırma hatası veya API bağlantı sorunu).")

        print("=" * 60)