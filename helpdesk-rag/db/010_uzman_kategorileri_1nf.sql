-- users.uzman_kategorileri (TEXT[]) 1NF ihlali: bir hucrede birden fazla
-- atomik deger tutuluyor (coklu deger/tekrarlanan grup). Cozum: klasik
-- coktan-coga koprulesme (junction) tablosu.
--
-- Ad neden agent_expertise (agent_kategorileri degil): DB'de zaten
-- ust_kategoriler -> kategori_gruplari -> alt_kategoriler diye AYRI bir
-- kategori hiyerarsisi var (tickets.sub_category_id icin). "kategori"
-- kelimesini kullanan baska bir isim o hiyerarsiyle karistirilabilirdi;
-- bu tablo ise classification_categories'e bagli, tamamen farkli bir sey.
--
-- category_id neden TEXT category_key degil de UUID id: semadaki TUM diger
-- FK'ler surrogate key (id) kullaniyor (tickets.sub_category_id, sap_module_id
-- vb.); tutarlilik + kategori adi (category_key) ileride yeniden adlandirilirsa
-- (rename) bu tablonun etkilenmemesi icin id tercih edildi.
--
-- Uygulama sirasi:
--   1) Bu dosyayi calistir (tablo + veri tasima, ESKI SUTUNA DOKUNMAZ).
--   2) app kodu (store.py/main.py) yeni tabloyu kullanacak sekilde
--      guncellenip deploy edildikten ve dogrulandiktan SONRA,
--      010b_drop_uzman_kategorileri_column.sql ile eski sutunu kaldir.

CREATE TABLE IF NOT EXISTS agent_expertise (
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES classification_categories(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, category_id)
);

-- Mevcut dizi verisini satirlara ac (unnest), category_key -> id'ye cevirip tasi.
INSERT INTO agent_expertise (user_id, category_id)
SELECT u.id, cc.id
FROM users u
CROSS JOIN LATERAL unnest(u.uzman_kategorileri) AS kat(category_key)
JOIN classification_categories cc ON cc.category_key = kat.category_key
WHERE u.uzman_kategorileri IS NOT NULL
ON CONFLICT (user_id, category_id) DO NOTHING;

-- Dogrulama: eski dizideki eleman sayisi ile yeni tablodaki satir sayisi
-- esit olmali (asagidaki iki sorgunun sonucu ayni cikmali).
-- SELECT sum(array_length(uzman_kategorileri,1)) FROM users WHERE uzman_kategorileri IS NOT NULL;
-- SELECT count(*) FROM agent_expertise;
