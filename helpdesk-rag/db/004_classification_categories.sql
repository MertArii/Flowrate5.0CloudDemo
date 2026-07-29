-- Sınıflandırma kategorilerini DB'ye taşır. Önceden app/triage/routing_rules.json
-- dosyasında elle tutuluyordu; artık classifier.py ve router.py bu tablodan okur.
--
-- routing_rules TABLOSUNA KARIŞTIRILMASIN: o farklı bir amaç için (e-posta
-- deseni / anahtar kelime tabanlı ön-yönlendirme kuralları) ve şu an motor
-- tarafından kullanılmıyor — ileride ayrı bir özellik olarak değerlendirilebilir.
--
-- DBeaver'da tek seferlik çalıştırın (mevcut veriyi silmez, sadece ekler).

CREATE TABLE IF NOT EXISTS classification_categories (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_key   TEXT UNIQUE NOT NULL,   -- classifier'ın çıktısı + tickets.extracted_category ile eşleşir
    aciklama       TEXT NOT NULL,          -- LLM prompt'unda kategori açıklaması olarak kullanılır
    ekip_group_id  UUID REFERENCES support_groups(id) ON DELETE SET NULL,
    is_active      BOOLEAN DEFAULT TRUE,
    created_at     TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Not: 'Diger' (belirsiz/eşleşmeyen) kategorisi BİLEREK burada yok — o kod
-- seviyesinde sabit bir "insan triyajına düş" sinyalidir, atanabilir bir
-- ekibi olmadığı için gerçek bir kategori satırı değildir.

INSERT INTO classification_categories (category_key, aciklama, ekip_group_id)
SELECT v.category_key, v.aciklama, sg.id
FROM (VALUES
    ('SAP-FI',     'Finans ve muhasebe (fatura, hesap belirleme, mizan, kapanış)', 'SAP Danışman Ekibi'),
    ('SAP-MM',     'Malzeme yönetimi / satınalma (sipariş, mal girişi, stok)',      'SAP Danışman Ekibi'),
    ('SAP-SD',     'Satış ve dağıtım (müşteri siparişi, teslimat, faturalama)',     'SAP Danışman Ekibi'),
    ('SAP-Basis',  'Sistem yönetimi, yetkiler, performans, transport',              'SAP Danışman Ekibi'),
    ('SAP-Yetki',  'Kullanıcı yetkileri, rol atama, erişim engeli',                 'SAP Danışman Ekibi'),
    ('IT-Ag',      'Ağ, VPN, internet erişimi bağlantı sorunları',                  'BT Destek Ekibi'),
    ('IT-Donanim', 'Bilgisayar, yazıcı, monitör, donanım arızası/talebi',           'BT Destek Ekibi'),
    ('IT-Hesap',   'Parola sıfırlama, hesap kilidi, e-posta erişimi',               'BT Destek Ekibi')
) AS v(category_key, aciklama, ekip_adi)
JOIN support_groups sg ON sg.name = v.ekip_adi
ON CONFLICT (category_key) DO NOTHING;
