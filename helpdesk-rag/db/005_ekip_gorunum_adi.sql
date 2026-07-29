-- Her kategoriye, gerçek destek grubundan (support_groups) BAĞIMSIZ,
-- iş-türüne özel bir GÖRÜNÜR ekip adı ekler. Amaç: donanım sorununa
-- "BT Destek Ekibi" gibi şemsiye bir isim yerine "Donanım Destek Ekibi"
-- gösterebilmek — asıl atama mantığı (ekip_group_id, uzman havuzu) DEĞİŞMEZ,
-- sadece API yanıtındaki görünen isim netleşir.
--
-- DBeaver'da tek seferlik çalıştırın (mevcut veriyi silmez).

ALTER TABLE classification_categories ADD COLUMN IF NOT EXISTS ekip_gorunum_adi TEXT;

UPDATE classification_categories SET ekip_gorunum_adi = v.gorunum_adi
FROM (VALUES
    ('SAP-FI',     'SAP Finans Danışmanlığı'),
    ('SAP-MM',     'SAP Malzeme Yönetimi Danışmanlığı'),
    ('SAP-SD',     'SAP Satış/Dağıtım Danışmanlığı'),
    ('SAP-Basis',  'SAP Basis Danışmanlığı'),
    ('SAP-Yetki',  'SAP Yetkilendirme Danışmanlığı'),
    ('IT-Ag',      'Ağ Destek Ekibi'),
    ('IT-Donanim', 'Donanım Destek Ekibi'),
    ('IT-Hesap',   'Hesap/Erişim Destek Ekibi')
) AS v(category_key, gorunum_adi)
WHERE classification_categories.category_key = v.category_key;
