-- L1 triyaj için ticket kayıtları. Sistem çalıştıkça birikir; ileride
-- benzerlik tabanlı yönlendirme (geçmişten öğrenme) için veri kaynağı.
CREATE TABLE IF NOT EXISTS tickets (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    metin            TEXT NOT NULL,
    modul            TEXT,
    oncelik          TEXT,
    ozet             TEXT,
    guven            REAL,
    ekip             TEXT,
    atanan_uzman     TEXT,
    otomatik_atandi  BOOLEAN DEFAULT FALSE,
    onerilen_cozum   TEXT,
    durum            TEXT DEFAULT 'acik',   -- acik | atandi | cozuldu | kapandi
    created_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS tickets_modul_idx ON tickets(modul);
CREATE INDEX IF NOT EXISTS tickets_durum_idx ON tickets(durum);
