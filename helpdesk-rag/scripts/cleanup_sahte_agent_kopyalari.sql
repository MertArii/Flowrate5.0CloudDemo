-- ============================================================================
-- 9 sahte agent'a atanmis KOPYA ticket'larin ve tum bagli kayitlarin temizligi.
-- SIRAYLA, HER ADIMDAN SONRA SONUCU GOZDEN GECIREREK calistirilmak icin
-- yazildi. Hicbir DELETE otomatik/toplu calistirilmamali.
--
-- Kapsam: routing_logs.assigned_agent_id bu 9 sahte agent'tan biri olan
-- ticket'lar arasinda, ayni subject'e sahip (kopya) olanlar.
-- Her kopya grubunda EN ESKI (created_at) kayit tutulur, digerleri silinir.
-- (Kullanicinin kendi DISTINCT ON (t.subject) sorgusuyla ayni mantik.)
--
-- Beklenen sonuc: 9 sahte agent uzerinde toplam kac ticket varsa, dedupe
-- sonrasi geriye subject basina 1 tane kalir (kullanicinin beklentisi: 127).
-- Adim 1'in ciktisindaki "tutulacak_ticket_sayisi" bu sayiyla eslesmeli --
-- eslesmezse Adim 5'e gecmeden once nedenini arastirin.
--
-- Cascade zinciri (tickets silinince otomatik silinenler):
--   tickets -> routing_logs            (CASCADE)
--   tickets -> attachment_vectors      (CASCADE, ticket_id uzerinden)
--   tickets -> ticket_messages         (CASCADE)
--     ticket_messages -> ai_feedbacks         (CASCADE)
--     ticket_messages -> message_attachments  (CASCADE)
--       message_attachments -> attachment_vectors (CASCADE, attachment_id uzerinden)
--
-- Cascade OLMAYAN, elle halledilmesi gereken:
--   ticket_solutions.ticket_id -> ON DELETE SET NULL (silinmiyor, oksuz kaliyor)
--   message_attachments.file_path -> diskteki fiziksel dosya (DB disi, elle)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- ADIM 1 — Kapsami olc (dry run, hicbir sey degistirmez)
-- ----------------------------------------------------------------------------
WITH sahte_agent_ticketlari AS (
    SELECT t.id, t.subject, t.created_at,
           row_number() OVER (
               PARTITION BY t.subject
               ORDER BY t.created_at, t.id
           ) AS rn
    FROM tickets t
    JOIN routing_logs rl ON rl.ticket_id = t.id
    WHERE rl.assigned_agent_id IN (
        '1f31b7ad-852a-4282-b872-9c63bb73193e','64a4c27c-e82f-4e7a-8197-ba93b084c58c',
        '550e173f-86dc-446f-a9c4-12f9edd3fb94','f1bec9fc-8414-4efa-bedb-51fe100299a3',
        '574389d2-d73a-4b51-83c2-58f3c46288ce','9b511a78-766d-4fdb-96e2-3c08f1842e75',
        '98d9db18-fc84-4221-9830-2be35f83afcd','f6db68a8-f3ff-4030-be4b-60e354de603d',
        'a0df5f07-ad44-4392-8d2f-d90fb70a9c5d'
    )
)
SELECT
    count(*) FILTER (WHERE rn = 1) AS tutulacak_ticket_sayisi,
    count(*) FILTER (WHERE rn > 1) AS silinecek_kopya_ticket_sayisi,
    count(*) AS toplam_ticket_sayisi
FROM sahte_agent_ticketlari;


-- ----------------------------------------------------------------------------
-- ADIM 2 — Silinecek ticket ID'lerini gecici bir tabloya sabitle
-- (boylece asagidaki adimlarin hepsi ayni ID kumesini kullanir, tekrar
-- hesaplama sirasinda kayma/tutarsizlik olmaz)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_silinecek_ticket_ids;

CREATE TEMP TABLE tmp_silinecek_ticket_ids AS
WITH sahte_agent_ticketlari AS (
    SELECT t.id,
           row_number() OVER (
               PARTITION BY t.subject
               ORDER BY t.created_at, t.id
           ) AS rn
    FROM tickets t
    JOIN routing_logs rl ON rl.ticket_id = t.id
    WHERE rl.assigned_agent_id IN (
        '1f31b7ad-852a-4282-b872-9c63bb73193e','64a4c27c-e82f-4e7a-8197-ba93b084c58c',
        '550e173f-86dc-446f-a9c4-12f9edd3fb94','f1bec9fc-8414-4efa-bedb-51fe100299a3',
        '574389d2-d73a-4b51-83c2-58f3c46288ce','9b511a78-766d-4fdb-96e2-3c08f1842e75',
        '98d9db18-fc84-4221-9830-2be35f83afcd','f6db68a8-f3ff-4030-be4b-60e354de603d',
        'a0df5f07-ad44-4392-8d2f-d90fb70a9c5d'
    )
)
SELECT id AS ticket_id FROM sahte_agent_ticketlari WHERE rn > 1;

-- kontrol: adim 1'deki "silinecek_kopya_ticket_sayisi" ile ayni olmali
SELECT count(*) FROM tmp_silinecek_ticket_ids;


-- ----------------------------------------------------------------------------
-- ADIM 3 — Yedek al (silmeden ONCE). db/archive/ altindaki mevcut pattern'e
-- uygun sekilde JSON'a aktarin, ornek psql \copy kullanimi:
--
--   \copy (SELECT * FROM tickets WHERE id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids)) TO 'db/archive/<tarih>/tickets_silinecek.csv' CSV HEADER
--   \copy (SELECT * FROM routing_logs WHERE ticket_id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids)) TO 'db/archive/<tarih>/routing_logs_silinecek.csv' CSV HEADER
--   \copy (SELECT * FROM ticket_messages WHERE ticket_id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids)) TO 'db/archive/<tarih>/ticket_messages_silinecek.csv' CSV HEADER
--   \copy (SELECT ts.* FROM ticket_solutions ts WHERE ts.ticket_id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids)) TO 'db/archive/<tarih>/ticket_solutions_silinecek.csv' CSV HEADER
--
-- Bu adimi atlamayin — geri donusu olmayan bir silme oncesi tek guvenlik agi bu.
-- ----------------------------------------------------------------------------


-- ----------------------------------------------------------------------------
-- ADIM 4 — (Bilgi amacli) diskteki fiziksel ek dosyalarin listesi
-- DB'den silinen kayit fiziksel dosyayi silmez; bu dosyalarin yolunu simdi
-- cikarip, DB temizligi sonrasi ayri bir adimda diskten silmeniz gerekir.
-- ----------------------------------------------------------------------------
SELECT ma.file_path
FROM message_attachments ma
JOIN ticket_messages tm ON tm.id = ma.message_id
WHERE tm.ticket_id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids);


-- ----------------------------------------------------------------------------
-- ADIM 5 — Asil silme (transaction icinde, COMMIT'ten once sayilari kontrol edin)
-- ----------------------------------------------------------------------------
BEGIN;

-- 5a) ticket_solutions ONCE silinmeli (ON DELETE SET NULL oldugu icin,
--     tickets silindikten sonra ticket_id zaten NULL olur, esleyemeyiz)
DELETE FROM ticket_solutions
WHERE ticket_id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids);

-- 5b) tickets silinince routing_logs, ticket_messages, ai_feedbacks,
--     message_attachments, attachment_vectors otomatik (CASCADE) silinir
DELETE FROM tickets
WHERE id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids);

-- kontrol: bu sayimlar sifir donmeli
SELECT
    (SELECT count(*) FROM routing_logs   WHERE ticket_id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids)) AS kalan_routing_logs,
    (SELECT count(*) FROM ticket_messages WHERE ticket_id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids)) AS kalan_ticket_messages,
    (SELECT count(*) FROM ticket_solutions WHERE ticket_id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids)) AS kalan_ticket_solutions,
    (SELECT count(*) FROM tickets WHERE id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids)) AS kalan_tickets;

-- Yukaridaki 4 sayi da 0 ise:
-- COMMIT;
-- Beklenmedik bir sey varsa:
-- ROLLBACK;


-- ----------------------------------------------------------------------------
-- ADIM 6 — COMMIT sonrasi (ayri, DB disi): Adim 4'te listelenen file_path'leri
-- diskten/objekt depolamadan elle veya bir script ile silin.
-- ----------------------------------------------------------------------------
