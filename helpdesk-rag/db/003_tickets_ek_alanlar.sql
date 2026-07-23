-- tickets tablosuna ek alanlar.
-- Mevcut tabloya uygulanabilir (IF NOT EXISTS ile tekrar çalıştırmak güvenli).
--
-- Not: Aşağıdakiler ZATEN VAR, tekrar eklenmedi:
--   sorun_aciklamasi -> mevcut "metin" sütunu
--   atanan_kisi      -> mevcut "atanan_uzman" sütunu
--   ticket_id        -> mevcut "id" (otomatik artan birincil anahtar)
-- Harici bir sistemden (Jira/ServiceNow vb.) gelen numara için
-- "harici_ticket_no" eklendi.

ALTER TABLE tickets
    ADD COLUMN IF NOT EXISTS harici_ticket_no TEXT,
    ADD COLUMN IF NOT EXISTS kullanici_maili  TEXT,
    ADD COLUMN IF NOT EXISTS kime             TEXT,
    ADD COLUMN IF NOT EXISTS bolge            TEXT,
    ADD COLUMN IF NOT EXISTS konu             TEXT,
    ADD COLUMN IF NOT EXISTS cozum            TEXT,
    ADD COLUMN IF NOT EXISTS cozum_tarihi     TIMESTAMPTZ;

COMMENT ON COLUMN tickets.harici_ticket_no IS 'Dış sistemdeki ticket numarası';
COMMENT ON COLUMN tickets.kullanici_maili  IS 'Ticketı açan kullanıcının e-postası';
COMMENT ON COLUMN tickets.kime             IS 'Ticketın yönlendirildiği kişi/ekip (serbest metin)';
COMMENT ON COLUMN tickets.bolge            IS 'Kullanıcının bölgesi/lokasyonu';
COMMENT ON COLUMN tickets.konu             IS 'Ticket başlığı/konusu';
COMMENT ON COLUMN tickets.cozum            IS 'Gerçekleşen çözüm (onerilen_cozum = AI önerisi)';
COMMENT ON COLUMN tickets.cozum_tarihi     IS 'Çözümün kaydedildiği an';

-- Sık kullanılacak filtreler için indeksler
CREATE INDEX IF NOT EXISTS tickets_kullanici_maili_idx ON tickets(kullanici_maili);
CREATE INDEX IF NOT EXISTS tickets_bolge_idx           ON tickets(bolge);
CREATE INDEX IF NOT EXISTS tickets_harici_no_idx       ON tickets(harici_ticket_no);
