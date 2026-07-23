-- L1 triyaj için ticket kayıtları. Sistem çalıştıkça birikir; ileride
-- benzerlik tabanlı yönlendirme (geçmişten öğrenme) için veri kaynağı.
CREATE TABLE IF NOT EXISTS tickets (
    ticket_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sorun_aciklamasi TEXT NOT NULL,
    modul            TEXT,
    oncelik          TEXT,
    ozet             TEXT,
    guven            REAL,
    ekip             TEXT,
    atanan_kisi      TEXT,
    otomatik_atandi  BOOLEAN DEFAULT FALSE,
    onerilen_cozum   TEXT,                  -- AI'ın önerdiği çözüm
    durum            TEXT DEFAULT 'acik',   -- acik | atandi | cozuldu | kapandi
    created_at       TIMESTAMPTZ DEFAULT now(),

    -- Ek alanlar (bkz. 003_tickets_ek_alanlar.sql)
    harici_ticket_no TEXT,                  -- dış sistemdeki ticket numarası
    kullanici_maili  TEXT,                  -- ticketı açan kullanıcı
    kime             TEXT,                  -- yönlendirilen kişi/ekip (serbest)
    bolge            TEXT,                  -- kullanıcının bölgesi
    konu             TEXT,                  -- ticket başlığı
    cozum            TEXT,                  -- gerçekleşen çözüm
    cozum_tarihi     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS tickets_modul_idx           ON tickets(modul);
CREATE INDEX IF NOT EXISTS tickets_durum_idx           ON tickets(durum);
CREATE INDEX IF NOT EXISTS tickets_kullanici_maili_idx ON tickets(kullanici_maili);
CREATE INDEX IF NOT EXISTS tickets_bolge_idx           ON tickets(bolge);
CREATE INDEX IF NOT EXISTS tickets_harici_no_idx       ON tickets(harici_ticket_no);
