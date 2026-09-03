-- 007'nin ilk (tek tablolu, self-referencing) sürümü daha önce çalıştırılmış
-- olabilir. O sürümün ticket_categories tablosu ve tickets.sub_category_id
-- üzerindeki eski FK'sı kalmış olabilir; 007'nin 3-tablolu son sürümündeki
-- "ADD COLUMN IF NOT EXISTS sub_category_id" satırı bu yüzden sessizce
-- atlanmış (kolon zaten vardı) ve sub_category_id hâlâ ESKİ tabloya
-- bağlıydı — yeni ust_kategoriler/kategori_gruplari/alt_kategoriler
-- zincirine hiç bağlanmamıştı.
--
-- Bu script:
--   1) Eski ticket_categories tablosunu ve ona olan eski FK'yı temizler
--      (CASCADE sadece bağımlı FK kısıtını kaldırır; tickets.sub_category_id
--      kolonunun kendisine veya verisine dokunmaz).
--   2) sub_category_id'yi doğru tabloya (alt_kategoriler) bağlar.
--
-- DBeaver'da tek seferlik çalıştırın. ticket_categories tablosu hiç
-- kullanılmadıysa (feature henüz canlıda yazılmıyor) veri kaybı riski yok;
-- yine de tedbiren önce içeriğini kontrol edin: SELECT count(*) FROM ticket_categories;

DROP TABLE IF EXISTS ticket_categories CASCADE;

-- Önce (varsa) kısıtı kaldırıp yeniden ekliyoruz — böylece script hem
-- "sub_category_id hâlâ eski tabloya bağlıydı" hem "zaten doğru tabloya
-- bağlıydı" durumlarında da güvenle (idempotent) çalışır.
ALTER TABLE tickets DROP CONSTRAINT IF EXISTS tickets_sub_category_id_fkey;
ALTER TABLE tickets
    ADD CONSTRAINT tickets_sub_category_id_fkey
    FOREIGN KEY (sub_category_id) REFERENCES alt_kategoriler(id) ON DELETE SET NULL;
