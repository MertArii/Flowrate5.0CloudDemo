-- ============================================================================
-- ADIM 2/3 -- 125 disindaki, hala 9 sahte agent'a bagli TUM ticket'lari
-- (kopyalar/test verisi) ve bagli tum kayitlari sil.
--
-- Kapsam: routing_logs.assigned_agent_id bu 9 sahte agent'tan biri OLAN
-- ve tickets_125_yeniden_atanmis.xlsx'te YER ALMAYAN ticket'lar.
--
-- Cascade zinciri (tickets silinince otomatik silinenler):
--   tickets -> routing_logs            (CASCADE, ticket_id uzerinden)
--   tickets -> attachment_vectors      (CASCADE, ticket_id uzerinden)
--   tickets -> ticket_messages         (CASCADE)
--     ticket_messages -> ai_feedbacks         (CASCADE)
--     ticket_messages -> message_attachments  (CASCADE)
--       message_attachments -> attachment_vectors (CASCADE, attachment_id uzerinden)
--
-- Cascade OLMAYAN, elle halledilmesi gereken:
--   ticket_solutions.ticket_id -> ON DELETE SET NULL (once elle silinir)
--   message_attachments.file_path -> diskteki fiziksel dosya (DB disi, elle)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- ADIM 2.0 -- Once ADIM 1'i calistirip COMMIT ettiginizden emin olun.
-- (Aksi halde asagidaki "disinda kalanlar" hesaplamasi henuz yeniden
-- atanmamis 125 ticket'i da kapsama alip yanlislikla siler.)
-- ----------------------------------------------------------------------------


-- ----------------------------------------------------------------------------
-- ADIM 2.1 -- Korunacak 125 ticket ID'sini gecici tabloya koy
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_korunacak_ticket_ids;
CREATE TEMP TABLE tmp_korunacak_ticket_ids (ticket_id uuid PRIMARY KEY);
INSERT INTO tmp_korunacak_ticket_ids (ticket_id) VALUES
  ('35223499-bcbe-4225-8a47-b228aee74d50'::uuid),
  ('711ccde9-713e-497c-a4b8-1c0d27a39429'::uuid),
  ('47275353-1d4b-4afd-8427-e8aff7f29a7f'::uuid),
  ('6101b9d6-4ebe-4ac6-b217-eb94c71b1c95'::uuid),
  ('83095217-d5ad-48b8-ae82-7e2ca44c13ee'::uuid),
  ('f724bd60-7419-490b-93cb-7901d6b51241'::uuid),
  ('d01b9acd-905c-422b-bdbd-fa9576c558fa'::uuid),
  ('d0a408aa-1385-4cbb-a8e7-a22ca8c96aea'::uuid),
  ('f40f70d8-5edd-4202-b2e2-8b7701e56d46'::uuid),
  ('0028c55f-2190-477b-83a0-5360b104b2ed'::uuid),
  ('913c4b42-3940-4b7b-85dd-687b4919f504'::uuid),
  ('d8ba8399-7a58-40b8-ae76-02cbb2e69f80'::uuid),
  ('f60a76cf-6bf1-49e8-a7d9-02c7e4edfc6f'::uuid),
  ('43a6b3b1-b2c8-4b9a-84e4-45aa49ae1c4c'::uuid),
  ('35c9313b-e20f-4538-a8a6-a0024093d1a6'::uuid),
  ('cdf24f28-2a17-4aec-8b23-50d6f0bf48c2'::uuid),
  ('9a228976-4b92-4ed7-9d44-6e6508366250'::uuid),
  ('d7890f59-c266-4520-b881-5de71ed9f685'::uuid),
  ('7dbc7c05-aa2f-4490-8ae3-a019b89454e4'::uuid),
  ('ed6e3c13-fafd-43dd-bf6f-e6f77c3c9518'::uuid),
  ('084080a8-a219-4f7e-8fe9-0071be63c3e0'::uuid),
  ('a012c905-4328-4028-b0e5-243fb0fb648a'::uuid),
  ('1fa507cf-3ca0-474e-9a1f-eab4acbaa6e9'::uuid),
  ('fcb9a22d-f75d-4537-9934-42b3058a21c2'::uuid),
  ('25e6ab52-5703-430b-af1f-37c6c27c092b'::uuid),
  ('96a8d952-ca18-4513-a1b1-580841b51a35'::uuid),
  ('1c58ea53-5cbc-4849-868b-3ac6750be6b5'::uuid),
  ('3185275f-c8b4-40cc-ae69-0ac1777c9c41'::uuid),
  ('9b802679-8c60-4ce0-9fdc-b5e90e11edc1'::uuid),
  ('512021a5-07e5-45f9-9a56-c5f23a425c1e'::uuid),
  ('e12b8285-04e5-429c-8df4-15455eea1e91'::uuid),
  ('03339dca-99f2-4019-bb5b-21567c16a8b6'::uuid),
  ('9e474c58-8f8b-4c22-991e-e405a50fef65'::uuid),
  ('a907778f-c918-48cb-bd44-0d5be8a94910'::uuid),
  ('28be8878-961d-417c-9f5e-916e6db303c4'::uuid),
  ('eb5f4461-fb5b-4c09-a027-06cac63bd478'::uuid),
  ('9f477304-88bc-43a4-988c-84f11cff1c47'::uuid),
  ('81dcc5d7-466d-4b55-b820-cf0888086104'::uuid),
  ('80480fa2-6b30-44e0-aebf-5c8014431b81'::uuid),
  ('eaeaff5e-4058-49ac-8621-54cd512e357b'::uuid),
  ('eb7fae5a-2c3d-406c-a58c-bfaa0857f330'::uuid),
  ('6992d751-6b9f-4bee-833d-ec8e6e7bfab9'::uuid),
  ('03143309-cab3-442f-9246-200dcba4a2b0'::uuid),
  ('f0e9e61a-9263-40f4-b5a5-1af618ea750b'::uuid),
  ('cc4a8a49-e1a7-4662-8938-beaf8f2e5bdf'::uuid),
  ('c0c7ae23-ebba-486a-9bcd-9414f1468e66'::uuid),
  ('bd467ffa-f1b8-42ba-bfcb-78177a38049f'::uuid),
  ('19f9af63-fe7b-4476-89c7-50ed255c5528'::uuid),
  ('6689e7b0-29f0-47d2-8f2e-52d526f06129'::uuid),
  ('98f06333-4afb-4942-8c61-cbcb6bfc0d9d'::uuid),
  ('2effec90-f696-41d3-a496-91815cf5c8d5'::uuid),
  ('db05be94-67ef-43bc-8fee-22a22c891cb9'::uuid),
  ('9cd70d0e-d4c0-42a6-9529-e61d5a0ae143'::uuid),
  ('502fb15c-2439-43ee-bcdc-613b4d2859fd'::uuid),
  ('e501664f-8636-4974-b069-779ec4e03d61'::uuid),
  ('15ebe85d-8800-4c84-9389-65c74f45b4fc'::uuid),
  ('56ec44f8-22e4-4dc6-bed9-7cec5ff52555'::uuid),
  ('2f6c1a02-379c-4c24-b607-c10db9494f54'::uuid),
  ('fdc704f8-b2e3-4de2-8f90-4588efd08485'::uuid),
  ('628b698e-9e8e-4e15-a3bb-b6d4d7e506bf'::uuid),
  ('b1aa9397-9e36-4d23-ab24-dbaf5338d847'::uuid),
  ('68f61ba7-ebb9-44f9-b2c9-c364e6c04945'::uuid),
  ('bdf9ebae-e7ba-4df9-ae09-974020be2a49'::uuid),
  ('8cedc7f6-4778-48ee-b3cc-3da5832db386'::uuid),
  ('58500715-a670-4126-aac9-c57fdc8ab619'::uuid),
  ('4b35ee5f-5b3e-4120-aed6-af2250d381dc'::uuid),
  ('7fe01e5d-fbc8-4aa7-be30-9339264d2e20'::uuid),
  ('e375201b-b599-4f23-a724-fbfe8427f2ab'::uuid),
  ('0a4aba50-f460-4041-99f3-4a76817fd3c0'::uuid),
  ('e3428dbf-b149-4f82-aba0-c2751ee345cb'::uuid),
  ('6c931096-4bd6-4e86-8d90-2504fba4bcca'::uuid),
  ('8ff710f8-f16b-4912-877c-a34ba2af28cc'::uuid),
  ('40ba46c8-0ba5-4263-8f03-91a457147292'::uuid),
  ('5ca7e42a-a911-49dd-b086-a15adc4ce83e'::uuid),
  ('b533509d-fb69-4e1e-a0c3-114843692e6c'::uuid),
  ('a2dad4aa-d924-4d7d-9c96-b1e10549f3ce'::uuid),
  ('12188be8-3228-491e-8fe2-789e01450d10'::uuid),
  ('071b3529-dbee-4c35-96df-f51aa711f37a'::uuid),
  ('e36d59b6-8f2b-46af-a62c-dd30113d2854'::uuid),
  ('1f5ae26b-540f-4587-99dd-0f7f542f8854'::uuid),
  ('0b16cb34-8b3d-4272-b5a5-7b93a3d25464'::uuid),
  ('b460c44b-ee81-426d-9d34-b7c2852e2bd7'::uuid),
  ('fbbeec72-5b70-4f75-beb8-0eb199b0900e'::uuid),
  ('cbbdff0d-899d-4ae5-8255-fe500c452f01'::uuid),
  ('894e1bff-5991-4c69-a828-a52ee43635d7'::uuid),
  ('99c9fff9-1cb9-4ec6-903e-34d146149c60'::uuid),
  ('fecec3ff-7d78-43e1-95a1-7c98abe5e1a0'::uuid),
  ('224e8e8e-07db-462d-b986-4205b4059e19'::uuid),
  ('2def92c6-c78c-4f12-8226-14c8a6674936'::uuid),
  ('763e9b4f-9615-4b19-b7bb-6ac5218a0814'::uuid),
  ('13712efb-6a84-48b0-9b35-f9184afaae43'::uuid),
  ('6c367dad-756f-4001-a86f-080e4b2c2eb6'::uuid),
  ('6751557f-dcc5-4409-9e8b-60ae624e7580'::uuid),
  ('4289db19-b479-4de9-bc84-0a84736c051b'::uuid),
  ('859d96f2-bb33-4867-9d92-1ad510a67ee4'::uuid),
  ('0c570c1d-f390-4669-a929-0089cfedb20e'::uuid),
  ('f5f2dc5b-8b29-4ea5-b854-552af3d1b2c9'::uuid),
  ('3146e2d1-56a9-4d66-8fe8-906eaabfb189'::uuid),
  ('d2ffa292-9e12-40d5-b7f4-0b8f7ca68475'::uuid),
  ('84712920-de00-4f05-8e7b-be1d508d43bb'::uuid),
  ('f8c497fd-7a23-4b09-89d1-9df8113e7855'::uuid),
  ('93516cf8-11b6-424d-b34d-282646aafa1c'::uuid),
  ('e613f035-2a40-4f88-a523-609aa24a426f'::uuid),
  ('b3698670-46bd-4160-b363-0894fd98c3c1'::uuid),
  ('b3d0efa5-1f7b-431a-b62c-f8def025db18'::uuid),
  ('7d7e99bc-3e31-4d35-9be3-054572c9e564'::uuid),
  ('846c3e95-36ec-4840-89f0-dc226cbf3b77'::uuid),
  ('271cf952-3d03-44d5-906c-15a4d5d8043f'::uuid),
  ('3d0f4669-d6c4-4b81-8027-dd8c3a04403f'::uuid),
  ('1fd60982-52ce-475b-92b5-3e0dba41cd46'::uuid),
  ('856fc641-b20c-4892-8c69-48b37eb480d0'::uuid),
  ('4d7b942e-361c-4831-929d-7eaea6c7de25'::uuid),
  ('63cfbd2c-b3bd-47d3-a77b-8a973b332d9f'::uuid),
  ('5c7e7273-4c24-4d1f-b7c2-555f17d56105'::uuid),
  ('a67adf05-9d12-46ed-b119-9d40228907f6'::uuid),
  ('d465975e-f660-4658-ae6e-e487f140c89f'::uuid),
  ('367d51d5-7b84-48c2-b5c1-adb4675e403e'::uuid),
  ('22773daf-0f84-4ee7-9435-6785e54bcfcd'::uuid),
  ('71171141-b29e-48af-9589-2e13ff544e89'::uuid),
  ('980635ab-4148-4d8b-8011-6400471c7940'::uuid),
  ('0999c2b1-d5e0-483b-9134-c50dd6caf56e'::uuid),
  ('2e7af195-8391-4d77-9cbf-7b51b743c087'::uuid),
  ('5d1d43b6-a790-41d1-a87d-f198a83d00bb'::uuid),
  ('7c5c1630-a589-4406-8c02-357e24b0071f'::uuid),
  ('a74d31f4-03ee-4014-af5b-217b60fa10eb'::uuid);

-- kontrol: 125 olmali
SELECT count(*) FROM tmp_korunacak_ticket_ids;


-- ----------------------------------------------------------------------------
-- ADIM 2.2 -- Silinecek ticket ID'lerini sabitle (dry run + kapsam olcumu)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_silinecek_ticket_ids;
CREATE TEMP TABLE tmp_silinecek_ticket_ids AS
SELECT DISTINCT t.id AS ticket_id
FROM tickets t
JOIN routing_logs rl ON rl.ticket_id = t.id
WHERE rl.assigned_agent_id IN (
    '1f31b7ad-852a-4282-b872-9c63bb73193e','64a4c27c-e82f-4e7a-8197-ba93b084c58c',
    '550e173f-86dc-446f-a9c4-12f9edd3fb94','f1bec9fc-8414-4efa-bedb-51fe100299a3',
    '574389d2-d73a-4b51-83c2-58f3c46288ce','9b511a78-766d-4fdb-96e2-3c08f1842e75',
    '98d9db18-fc84-4221-9830-2be35f83afcd','f6db68a8-f3ff-4030-be4b-60e354de603d',
    'a0df5f07-ad44-4392-8d2f-d90fb70a9c5d'
)
AND t.id NOT IN (SELECT ticket_id FROM tmp_korunacak_ticket_ids);

-- kapsam kontrolu: 125 (korunan) + bu sayi = 9 sahte agent'a bagli TOPLAM ticket sayisi olmali
SELECT count(*) FROM tmp_silinecek_ticket_ids;


-- ----------------------------------------------------------------------------
-- ADIM 2.3 -- Yedek al (silmeden ONCE, GERI DONUSU YOK)
-- psql \copy ornegi (tarihi kendi gununuze gore degistirin):
--
--   \copy (SELECT * FROM tickets WHERE id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids)) TO 'db/archive/2026_09_07/tickets_silinecek.csv' CSV HEADER
--   \copy (SELECT * FROM routing_logs WHERE ticket_id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids)) TO 'db/archive/2026_09_07/routing_logs_silinecek.csv' CSV HEADER
--   \copy (SELECT * FROM ticket_messages WHERE ticket_id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids)) TO 'db/archive/2026_09_07/ticket_messages_silinecek.csv' CSV HEADER
--   \copy (SELECT ts.* FROM ticket_solutions ts WHERE ts.ticket_id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids)) TO 'db/archive/2026_09_07/ticket_solutions_silinecek.csv' CSV HEADER
--
-- Bu adimi atlamayin.
-- ----------------------------------------------------------------------------


-- ----------------------------------------------------------------------------
-- ADIM 2.4 -- (Bilgi amacli) diskteki fiziksel ek dosyalarin listesi.
-- DB'den silinen kayit fiziksel dosyayi silmez; DB temizligi sonrasi
-- bu yollari diskten/objekt depolamadan ayrica silmeniz gerekir.
-- ----------------------------------------------------------------------------
SELECT ma.file_path
FROM message_attachments ma
JOIN ticket_messages tm ON tm.id = ma.message_id
WHERE tm.ticket_id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids);


-- ----------------------------------------------------------------------------
-- ADIM 2.5 -- Asil silme (transaction icinde; COMMIT'ten once sayilari kontrol edin)
-- ----------------------------------------------------------------------------
BEGIN;

-- ticket_solutions ONCE silinmeli (ON DELETE SET NULL oldugu icin, tickets
-- silindikten sonra ticket_id zaten NULL olur, esleyemeyiz)
DELETE FROM ticket_solutions
WHERE ticket_id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids);

-- tickets silinince routing_logs, ticket_messages, ai_feedbacks,
-- message_attachments, attachment_vectors otomatik (CASCADE) silinir
DELETE FROM tickets
WHERE id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids);

-- kontrol: asagidaki 4 sayi da sifir donmeli
SELECT
    (SELECT count(*) FROM routing_logs    WHERE ticket_id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids)) AS kalan_routing_logs,
    (SELECT count(*) FROM ticket_messages WHERE ticket_id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids)) AS kalan_ticket_messages,
    (SELECT count(*) FROM ticket_solutions WHERE ticket_id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids)) AS kalan_ticket_solutions,
    (SELECT count(*) FROM tickets WHERE id IN (SELECT ticket_id FROM tmp_silinecek_ticket_ids)) AS kalan_tickets;

-- ek kontrol: 125 korunan ticket hala DB'de olmali (125 donmeli)
SELECT count(*) FROM tickets WHERE id IN (SELECT ticket_id FROM tmp_korunacak_ticket_ids);

-- Yukaridaki 4 sayi 0, sonuncusu 125 ise:
-- COMMIT;
-- Beklenmedik bir sey varsa:
-- ROLLBACK;
