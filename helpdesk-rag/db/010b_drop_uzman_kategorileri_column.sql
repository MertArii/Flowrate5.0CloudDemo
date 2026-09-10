-- SADECE 010_uzman_kategorileri_1nf.sql calistirildiktan, app kodu yeni
-- agent_expertise tablosunu kullanacak sekilde deploy edildikten VE
-- dogrulama sorgusu (asagida) beklenen sonucu verdikten SONRA calistir.

-- Dogrulama (0 satir donmeli -- donmezse DROP COLUMN'u calistirma):
SELECT u.id, u.email, u.uzman_kategorileri
FROM users u
WHERE u.uzman_kategorileri IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM agent_expertise ae
      JOIN classification_categories cc ON cc.id = ae.category_id
      WHERE ae.user_id = u.id
        AND cc.category_key = ANY(u.uzman_kategorileri)
  );

ALTER TABLE users DROP COLUMN uzman_kategorileri;
