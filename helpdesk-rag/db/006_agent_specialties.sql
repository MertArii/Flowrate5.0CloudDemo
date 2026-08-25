-- Uzmanların GERÇEK, elle beyan edilmiş uzmanlık kategorileri. Geçmiş ticket
-- sayısına dayalı sezgi (get_agents_by_category) yanıltıcı olabiliyordu —
-- ör. Ramazan'ın title'ı 'SAP QM PP' iken, geçmişte tesadüfen 4 SAP-MM
-- ticket'ı çözmüştü ve sistem onu MM uzmanı sanıyordu. Bu sütun varsa
-- ATAMA ALGORİTMASI ARTIK BUNU ÖNCELİKLİ KULLANIR (geçmiş ticket sezgisi
-- sadece bu boşsa devreye girer).
--
-- DBeaver'da tek seferlik çalıştırın (mevcut veriyi silmez, sadece ekler).

ALTER TABLE users ADD COLUMN IF NOT EXISTS uzman_kategorileri TEXT[];

-- title'lardan çıkarılan eşleme:
UPDATE users SET uzman_kategorileri = ARRAY['IT-Donanim']
WHERE email IN ('emirhan.teknoloji@sirket.com', 'faruk.teknoloji@sirket.com',
                'salih.teknoloji@sirket.com', 'yusuf.teknoloji@sirket.com');

UPDATE users SET uzman_kategorileri = ARRAY['IT-Donanim', 'IT-Ag']
WHERE email = 'yucel.teknoloji@sirket.com';

UPDATE users SET uzman_kategorileri = ARRAY['SAP-SD']
WHERE email = 'gizem.teknoloji@sirket.com';

UPDATE users SET uzman_kategorileri = ARRAY['SAP-FI']
WHERE email = 'ogulcan.teknoloji@sirket.com';

UPDATE users SET uzman_kategorileri = ARRAY['SAP-MM', 'SAP-SD']
WHERE email = 'sena.teknoloji@sirket.com';

-- SAP EWM: bizim taksonomimizde yok, en yakını SAP-MM (depo/stok ilişkili).
UPDATE users SET uzman_kategorileri = ARRAY['SAP-MM']
WHERE email = 'omer.teknoloji@sirket.com';

-- Siber Güvenlik: IT-Hesap'a (hesap/erişim güvenliği) bağlandı.
UPDATE users SET uzman_kategorileri = ARRAY['IT-Hesap']
WHERE email = 'turgut.teknoloji@sirket.com';

-- Ramazan (SAP QM PP) ve Esra/Mustafa (Sistem Destek, genel BT):
-- BİLEREK hiçbir kategoriye bağlanmadı — bizim taksonomimizle örtüşmüyor,
-- yanlış eşleme riskini almamak için boş bırakıldı. Bu uzmanlar sadece
-- ekiplerine (SAP/BT Destek) genel üye olarak, geçmiş-ticket sezgisi veya
-- hiçbir uzman eşleşmediğinde tüm ekip yedeği yoluyla aday olabilirler.
