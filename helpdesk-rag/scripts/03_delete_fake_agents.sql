-- ============================================================================
-- ADIM 3/3 -- 9 sahte agent'i (users) kalici olarak sil
--
-- ONCE Adim 1 ve Adim 2 COMMIT edilmis olmali. Bu adim, digerlerinin
-- aksine, DELETE'i dogrudan calistirir cunku hedef zaten sadece 9 satir
-- (users) ve DB, referans kalmadiysa zaten guvenli sekilde silecek --
-- referans kaldiysa da hata verip hicbir sey silmeyecek (transaction).
--
-- users(id) referans eden FK'lar ve davranislari:
--   routing_rules.default_assigned_agent_id  -> ON DELETE SET NULL   (sorun degil)
--   tickets.assigned_agent_id                -> ON DELETE SET NULL   (sorun degil, ama Adim 1/2 sonrasi zaten 0 satir kalmis olmali)
--   tickets.customer_id                      -> ON DELETE SET NULL   (sorun degil)
--   ai_feedbacks.user_id                     -> ON DELETE CASCADE    (varsa feedback'leri de siler)
--   routing_logs.assigned_agent_id           -> KURAL YOK (RESTRICT) (**Adim 1/2 tamamlanmadan burada patlar**)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- ADIM 3.1 -- On kontrol: bu 9 id'ye hala referans veren satir var mi?
-- HEPSI 0 DONMEDEN ADIM 3.3'E GECMEYIN.
-- ----------------------------------------------------------------------------
SELECT
    (SELECT count(*) FROM routing_logs WHERE assigned_agent_id IN (    '1f31b7ad-852a-4282-b872-9c63bb73193e','64a4c27c-e82f-4e7a-8197-ba93b084c58c',
    '550e173f-86dc-446f-a9c4-12f9edd3fb94','f1bec9fc-8414-4efa-bedb-51fe100299a3',
    '574389d2-d73a-4b51-83c2-58f3c46288ce','9b511a78-766d-4fdb-96e2-3c08f1842e75',
    '98d9db18-fc84-4221-9830-2be35f83afcd','f6db68a8-f3ff-4030-be4b-60e354de603d',
    'a0df5f07-ad44-4392-8d2f-d90fb70a9c5d')) AS kalan_routing_logs,
    (SELECT count(*) FROM tickets      WHERE assigned_agent_id IN (    '1f31b7ad-852a-4282-b872-9c63bb73193e','64a4c27c-e82f-4e7a-8197-ba93b084c58c',
    '550e173f-86dc-446f-a9c4-12f9edd3fb94','f1bec9fc-8414-4efa-bedb-51fe100299a3',
    '574389d2-d73a-4b51-83c2-58f3c46288ce','9b511a78-766d-4fdb-96e2-3c08f1842e75',
    '98d9db18-fc84-4221-9830-2be35f83afcd','f6db68a8-f3ff-4030-be4b-60e354de603d',
    'a0df5f07-ad44-4392-8d2f-d90fb70a9c5d')) AS kalan_tickets,
    (SELECT count(*) FROM tickets      WHERE customer_id       IN (    '1f31b7ad-852a-4282-b872-9c63bb73193e','64a4c27c-e82f-4e7a-8197-ba93b084c58c',
    '550e173f-86dc-446f-a9c4-12f9edd3fb94','f1bec9fc-8414-4efa-bedb-51fe100299a3',
    '574389d2-d73a-4b51-83c2-58f3c46288ce','9b511a78-766d-4fdb-96e2-3c08f1842e75',
    '98d9db18-fc84-4221-9830-2be35f83afcd','f6db68a8-f3ff-4030-be4b-60e354de603d',
    'a0df5f07-ad44-4392-8d2f-d90fb70a9c5d')) AS kalan_tickets_customer,
    (SELECT count(*) FROM routing_rules WHERE default_assigned_agent_id IN (    '1f31b7ad-852a-4282-b872-9c63bb73193e','64a4c27c-e82f-4e7a-8197-ba93b084c58c',
    '550e173f-86dc-446f-a9c4-12f9edd3fb94','f1bec9fc-8414-4efa-bedb-51fe100299a3',
    '574389d2-d73a-4b51-83c2-58f3c46288ce','9b511a78-766d-4fdb-96e2-3c08f1842e75',
    '98d9db18-fc84-4221-9830-2be35f83afcd','f6db68a8-f3ff-4030-be4b-60e354de603d',
    'a0df5f07-ad44-4392-8d2f-d90fb70a9c5d')) AS kalan_routing_rules,
    (SELECT count(*) FROM ai_feedbacks WHERE user_id IN (    '1f31b7ad-852a-4282-b872-9c63bb73193e','64a4c27c-e82f-4e7a-8197-ba93b084c58c',
    '550e173f-86dc-446f-a9c4-12f9edd3fb94','f1bec9fc-8414-4efa-bedb-51fe100299a3',
    '574389d2-d73a-4b51-83c2-58f3c46288ce','9b511a78-766d-4fdb-96e2-3c08f1842e75',
    '98d9db18-fc84-4221-9830-2be35f83afcd','f6db68a8-f3ff-4030-be4b-60e354de603d',
    'a0df5f07-ad44-4392-8d2f-d90fb70a9c5d')) AS kalan_ai_feedbacks;


-- ----------------------------------------------------------------------------
-- ADIM 3.2 -- kalan_routing_logs > 0 ise: Adim 1 ve/veya Adim 2'yi
-- COMMIT ETMEDEN calistirdiniz demektir. Once onlari tamamlayip
-- tekrar Adim 3.1'i calistirin. kalan_routing_logs = 0 olmadan
-- Adim 3.3'teki DELETE hata verecektir (bu istenen/guvenli davranistir).
-- ----------------------------------------------------------------------------


-- ----------------------------------------------------------------------------
-- ADIM 3.3 -- Sil (transaction icinde)
-- ----------------------------------------------------------------------------
BEGIN;

DELETE FROM users
WHERE id IN (    '1f31b7ad-852a-4282-b872-9c63bb73193e','64a4c27c-e82f-4e7a-8197-ba93b084c58c',
    '550e173f-86dc-446f-a9c4-12f9edd3fb94','f1bec9fc-8414-4efa-bedb-51fe100299a3',
    '574389d2-d73a-4b51-83c2-58f3c46288ce','9b511a78-766d-4fdb-96e2-3c08f1842e75',
    '98d9db18-fc84-4221-9830-2be35f83afcd','f6db68a8-f3ff-4030-be4b-60e354de603d',
    'a0df5f07-ad44-4392-8d2f-d90fb70a9c5d');

-- kontrol: 0 donmeli (hicbiri kalmamali -> 9'u da silindi demektir)
SELECT count(*) FROM users WHERE id IN (    '1f31b7ad-852a-4282-b872-9c63bb73193e','64a4c27c-e82f-4e7a-8197-ba93b084c58c',
    '550e173f-86dc-446f-a9c4-12f9edd3fb94','f1bec9fc-8414-4efa-bedb-51fe100299a3',
    '574389d2-d73a-4b51-83c2-58f3c46288ce','9b511a78-766d-4fdb-96e2-3c08f1842e75',
    '98d9db18-fc84-4221-9830-2be35f83afcd','f6db68a8-f3ff-4030-be4b-60e354de603d',
    'a0df5f07-ad44-4392-8d2f-d90fb70a9c5d');

-- 0 ise:
-- COMMIT;
-- Beklenmedik bir sey varsa:
-- ROLLBACK;
