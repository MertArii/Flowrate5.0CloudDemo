UPDATE users
SET uzman_kategorileri = ARRAY['IT-Hesap','SAP-Yetki']
WHERE id = '78cc4401-f73a-4447-9943-5a3bddec63dc';

SELECT id, full_name, uzman_kategorileri FROM users WHERE id = '78cc4401-f73a-4447-9943-5a3bddec63dc';
