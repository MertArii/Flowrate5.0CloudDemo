-- Kurumsal 3 seviyeli alt kategori taksonomisi — 3 AYRI TABLO olarak
-- (ust_kategoriler -> kategori_gruplari -> alt_kategoriler). Tek, self-
-- referencing bir tablo yerine bilerek böyle seçildi: taksonomi sabit 3
-- seviyeli ve nadiren değişecek, buna karşılık asıl amaç raporlama —
-- düz JOIN'lerle sorgulanabilmesi (recursive CTE gerekmeden) ve her
-- seviyenin kendi FK'sıyla sıkı bütünlük sağlaması önceliklendirildi.
--
-- classification_categories'in YERİNE geçmez — o hâlâ triyaj/atama
-- motorunun (classifier.py -> router.py) kullandığı modul->ekip
-- eşlemesidir. Bu, ayrı, daha ince taneli bir raporlama/etiketleme
-- katmanıdır; tickets.sub_category_id ile ticket'a bağlanır.
--
-- SAP Modülü (FI, MM, SD...) BİLEREK bu hiyerarşinin bir parçası değil —
-- ayrı bir çapraz alan (sap_modules + tickets.sap_module_id). Sebep: modül,
-- "SAP Problemleri" grubundaki 8 alt kategorinin (Bug fix, Yetki Hatası vb.)
-- HER BİRİYLE bağımsız olarak kesişebilir.
--
-- Not: Kaynak listede iki yerde kopyala-yapıştır kayması vardı
-- ("...arızasınetwork cihazları arızası") — iki ayrı kaleme bölünerek
-- düzeltildi. "Vertabanı ERişim Talebi" -> "Veritabanı Erişim Talebi"
-- yazım hatası düzeltildi.
--
-- DBeaver'da tek seferlik çalıştırın (mevcut veriyi silmez, sadece ekler).

CREATE TABLE IF NOT EXISTS ust_kategoriler (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT UNIQUE NOT NULL,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS kategori_gruplari (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ust_kategori_id UUID NOT NULL REFERENCES ust_kategoriler(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (ust_kategori_id, name)
);
CREATE INDEX IF NOT EXISTS idx_kategori_gruplari_ust ON kategori_gruplari(ust_kategori_id);

CREATE TABLE IF NOT EXISTS alt_kategoriler (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    grup_id     UUID NOT NULL REFERENCES kategori_gruplari(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (grup_id, name)
);
CREATE INDEX IF NOT EXISTS idx_alt_kategoriler_grup ON alt_kategoriler(grup_id);

CREATE TABLE IF NOT EXISTS sap_modules (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code        TEXT UNIQUE NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE tickets ADD COLUMN IF NOT EXISTS sub_category_id UUID REFERENCES alt_kategoriler(id) ON DELETE SET NULL;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS sap_module_id UUID REFERENCES sap_modules(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_tickets_sub_category ON tickets(sub_category_id);
CREATE INDEX IF NOT EXISTS idx_tickets_sap_module ON tickets(sap_module_id);

COMMENT ON COLUMN tickets.sub_category_id IS
    'alt_kategoriler tablosuna işaret eder. Üst kategori/grup, '
    'alt_kategoriler -> kategori_gruplari -> ust_kategoriler JOIN''iyle elde edilir.';
COMMENT ON COLUMN tickets.sap_module_id IS
    'Opsiyonel — sadece SAP ile ilgili ticket''larda dolu. sub_category_id''den '
    'BAĞIMSIZ çapraz bir alandır (ör. Yetki Hatası + FI, Bug fix + MM gibi).';


-- ============================================================
-- Taksonomi verisi
-- ============================================================
DO $$
DECLARE
    v_ariza      UUID;
    v_talep      UUID;
    v_tindiso    UUID;
    v_grup       UUID;
BEGIN
    -- ==================== ARIZALAR ====================
    INSERT INTO ust_kategoriler (name) VALUES ('ARIZALAR') RETURNING id INTO v_ariza;

    INSERT INTO kategori_gruplari (ust_kategori_id, name) VALUES (v_ariza, 'Ağ ve İletişim Arızaları') RETURNING id INTO v_grup;
    INSERT INTO alt_kategoriler (grup_id, name) VALUES
        (v_grup, 'Erişim Engeli'),
        (v_grup, 'Erişim Yavaşlığı'),
        (v_grup, 'İnternet Kesintisi'),
        (v_grup, 'VPN Bağlantı Sorunları');

    INSERT INTO kategori_gruplari (ust_kategori_id, name) VALUES (v_ariza, 'Donanım Arızaları') RETURNING id INTO v_grup;
    INSERT INTO alt_kategoriler (grup_id, name) VALUES
        (v_grup, 'Bilgisayar Arızası'),
        (v_grup, 'Bilgisayar Çevre Birimleri Arızası'),
        (v_grup, 'Cep Telefonu Arızası'),
        (v_grup, 'IP Telefon Arızası'),
        (v_grup, 'Kamera Arızası'),
        (v_grup, 'Laptop Arızası'),
        (v_grup, 'Monitör Arızası'),
        (v_grup, 'Network Cihazları Arızası'),
        (v_grup, 'PDKS Arızası'),
        (v_grup, 'Sabit Telefon Arızası'),
        (v_grup, 'Yazıcı Arızası');

    INSERT INTO kategori_gruplari (ust_kategori_id, name) VALUES (v_ariza, 'Güvenlik Arızaları') RETURNING id INTO v_grup;
    INSERT INTO alt_kategoriler (grup_id, name) VALUES
        (v_grup, 'Antivirüs Uyarısı'),
        (v_grup, 'Şüpheli Mail / Phishing');

    INSERT INTO kategori_gruplari (ust_kategori_id, name) VALUES (v_ariza, 'Kullanıcı Hesap Yönetimi Arızaları') RETURNING id INTO v_grup;
    INSERT INTO alt_kategoriler (grup_id, name) VALUES
        (v_grup, 'E-posta Problemleri'),
        (v_grup, 'Local Yetki / Rol Değişikliği'),
        (v_grup, 'Parola Sıfırlama'),
        (v_grup, 'VPN Yetki / Rol Değişikliği');

    INSERT INTO kategori_gruplari (ust_kategori_id, name) VALUES (v_ariza, 'SAP Problemleri') RETURNING id INTO v_grup;
    INSERT INTO alt_kategoriler (grup_id, name) VALUES
        (v_grup, '3rd Party Desteği'),
        (v_grup, 'Ana Veri'),
        (v_grup, 'Bug Fix'),
        (v_grup, 'Ekran Desteği'),
        (v_grup, 'Kullanıcı Hatası'),
        (v_grup, 'SAP Problemleri'),
        (v_grup, 'Süreç Desteği'),
        (v_grup, 'Yetki Hatası');

    INSERT INTO kategori_gruplari (ust_kategori_id, name) VALUES (v_ariza, 'Yazılım Arızaları') RETURNING id INTO v_grup;
    INSERT INTO alt_kategoriler (grup_id, name) VALUES
        (v_grup, 'Diğer Uygulamalar'),
        (v_grup, 'İşletim Sistemi'),
        (v_grup, 'Ofis Uygulamaları'),
        (v_grup, 'Outlook'),
        (v_grup, 'PE Uygulaması');

    -- ==================== TALEPLER ====================
    INSERT INTO ust_kategoriler (name) VALUES ('TALEPLER') RETURNING id INTO v_talep;

    INSERT INTO kategori_gruplari (ust_kategori_id, name) VALUES (v_talep, 'Donanım Talepleri') RETURNING id INTO v_grup;
    INSERT INTO alt_kategoriler (grup_id, name) VALUES
        (v_grup, 'Bilgisayar Talebi'),
        (v_grup, 'Bilgisayar Çevre Birimleri Talebi'),
        (v_grup, 'Cep Telefonu Talebi'),
        (v_grup, 'IP Telefon Talebi'),
        (v_grup, 'Kamera Talebi'),
        (v_grup, 'Laptop Talebi'),
        (v_grup, 'Monitör Talebi'),
        (v_grup, 'Network Cihazları Talebi'),
        (v_grup, 'PDKS Talebi'),
        (v_grup, 'Sabit Telefon Talebi'),
        (v_grup, 'Yazıcı Talebi');

    INSERT INTO kategori_gruplari (ust_kategori_id, name) VALUES (v_talep, 'Erişim Talepleri') RETURNING id INTO v_grup;
    INSERT INTO alt_kategoriler (grup_id, name) VALUES
        (v_grup, 'Firma Erişim Talebi'),
        (v_grup, 'Network Erişim Talebi'),
        (v_grup, 'Ortak Alan Erişim Talebi'),
        (v_grup, 'Sunucu Erişim Talebi'),
        (v_grup, 'Uygulama Erişim Talebi'),
        (v_grup, 'Veritabanı Erişim Talebi'),
        (v_grup, 'VPN Yetki Talebi');

    INSERT INTO kategori_gruplari (ust_kategori_id, name) VALUES (v_talep, 'Geliştirme ve Raporlama Talepleri') RETURNING id INTO v_grup;
    INSERT INTO alt_kategoriler (grup_id, name) VALUES
        (v_grup, 'Geliştirme Talebi'),
        (v_grup, 'İyileştirme Talebi'),
        (v_grup, 'Proje Talebi'),
        (v_grup, 'Raporlama Talebi');

    INSERT INTO kategori_gruplari (ust_kategori_id, name) VALUES (v_talep, 'Güvenlik Talepleri') RETURNING id INTO v_grup;
    INSERT INTO alt_kategoriler (grup_id, name) VALUES
        (v_grup, 'Dosya Paylaşımı (DLP) Talebi'),
        (v_grup, 'E-Posta Kontrol Talebi'),
        (v_grup, 'EDR / AV'),
        (v_grup, 'Genel Kontrol');

    INSERT INTO kategori_gruplari (ust_kategori_id, name) VALUES (v_talep, 'Kullanıcı Hesap Yönetimi Talepleri') RETURNING id INTO v_grup;
    INSERT INTO alt_kategoriler (grup_id, name) VALUES
        (v_grup, 'E-Posta Hesabı Talebi'),
        (v_grup, 'Hesap Açılışı'),
        (v_grup, 'Hesap Düzenleme'),
        (v_grup, 'Hesap Kapatma');

    INSERT INTO kategori_gruplari (ust_kategori_id, name) VALUES (v_talep, 'Yazılım Talepleri') RETURNING id INTO v_grup;
    INSERT INTO alt_kategoriler (grup_id, name) VALUES
        (v_grup, 'Lisans Talebi'),
        (v_grup, 'Uygulama Kurulumu Talebi'),
        (v_grup, 'Web, Intranet Talebi');

    -- ==================== TİNDİSO BAKIM ====================
    INSERT INTO ust_kategoriler (name) VALUES ('TİNDİSO BAKIM') RETURNING id INTO v_tindiso;

    INSERT INTO kategori_gruplari (ust_kategori_id, name) VALUES (v_tindiso, 'Kamera Periyodik Kontrol') RETURNING id INTO v_grup;
    INSERT INTO alt_kategoriler (grup_id, name) VALUES
        (v_grup, 'Bug Fix'),
        (v_grup, 'Ek Talep (CR)'),
        (v_grup, 'Genel Kontrol'),
        (v_grup, 'Kamera Periyodik Bakım');

    INSERT INTO kategori_gruplari (ust_kategori_id, name) VALUES (v_tindiso, 'İşe Giriş İşlemleri') RETURNING id INTO v_grup;
    INSERT INTO alt_kategoriler (grup_id, name) VALUES
        (v_grup, 'Hesap Açılışı'),
        (v_grup, 'Genel Kontrol');

    INSERT INTO kategori_gruplari (ust_kategori_id, name) VALUES (v_tindiso, 'İşten Çıkış İşlemleri') RETURNING id INTO v_grup;
    INSERT INTO alt_kategoriler (grup_id, name) VALUES
        (v_grup, 'Hesap Kapatma'),
        (v_grup, 'Genel Kontrol');
END $$;

-- ==================== SAP Modülleri (ayrı, çapraz alan) ====================
INSERT INTO sap_modules (code) VALUES
    ('FI'), ('CO'), ('MM'), ('EWM'), ('PP'), ('SD'), ('QM'), ('PS'), ('PM'),
    ('TRM'), ('e-irsaliye'), ('e-fatura'), ('e-ödeme'), ('e-banka'),
    ('GRC'), ('CS'), ('ABAP')
ON CONFLICT (code) DO NOTHING;
