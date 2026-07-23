-- L1 triyaj için ticket kayıtları. Sistem çalıştıkça birikir; ileride
-- benzerlik tabanlı yönlendirme (geçmişten öğrenme) için veri kaynağı.
--
-- Sütun grupları:
--   1) Ticket bilgisi   — kullanıcıdan/dış sistemden gelen alanlar
--   2) Triyaj çıktısı   — sınıflandırıcı ve yönlendirme motorunun ürettiği
--   3) Çözüm            — AI önerisi (onerilen_cozum) ve gerçek çözüm (cozum)

CREATE TABLE IF NOT EXISTS tickets (
    ticket_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- 1) Ticket bilgisi
    sorun_aciklamasi TEXT NOT NULL,         -- ticket metni (zorunlu)
    kullanici_maili  TEXT,                  -- ticketı açan kullanıcı
    kime             TEXT,                  -- yönlendirilen kişi/ekip (serbest)
    bolge            TEXT,                  -- kullanıcının bölgesi/lokasyonu
    konu             TEXT,                  -- ticket başlığı
    harici_ticket_no TEXT,                  -- dış sistemdeki ticket numarası

    -- 2) Triyaj çıktısı
    modul            TEXT,                  -- SAP-FI, IT-Ag, Diger...
    oncelik          TEXT,                  -- dusuk | orta | yuksek | kritik
    ozet             TEXT,
    guven            REAL,                  -- 0.0 - 1.0
    ekip             TEXT,
    atanan_kisi      TEXT,
    otomatik_atandi  BOOLEAN DEFAULT FALSE, -- false ise insan triyajına düştü

    -- 3) Çözüm
    onerilen_cozum   TEXT,                  -- AI'ın RAG'den ürettiği öneri
    cozum            TEXT,                  -- gerçekte uygulanan çözüm
    cozum_tarihi     TIMESTAMPTZ,

    durum            TEXT DEFAULT 'acik',   -- acik | atandi | cozuldu | kapandi
    created_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS tickets_modul_idx           ON tickets(modul);
CREATE INDEX IF NOT EXISTS tickets_durum_idx           ON tickets(durum);
CREATE INDEX IF NOT EXISTS tickets_kullanici_maili_idx ON tickets(kullanici_maili);
CREATE INDEX IF NOT EXISTS tickets_bolge_idx           ON tickets(bolge);
CREATE INDEX IF NOT EXISTS tickets_harici_no_idx       ON tickets(harici_ticket_no);
