-- 16 gercek agent: kimlik, ekip, elle beyan edilmis uzmanlik
SELECT u.id, u.email, u.full_name, sg.name AS ekip, u.uzman_kategorileri
FROM users u
LEFT JOIN support_groups sg ON sg.id = u.support_group_id
WHERE u.role = 'agent'
  AND u.id NOT IN (
    '1f31b7ad-852a-4282-b872-9c63bb73193e','64a4c27c-e82f-4e7a-8197-ba93b084c58c',
    '550e173f-86dc-446f-a9c4-12f9edd3fb94','f1bec9fc-8414-4efa-bedb-51fe100299a3',
    '574389d2-d73a-4b51-83c2-58f3c46288ce','9b511a78-766d-4fdb-96e2-3c08f1842e75',
    '98d9db18-fc84-4221-9830-2be35f83afcd','f6db68a8-f3ff-4030-be4b-60e354de603d',
    'a0df5f07-ad44-4392-8d2f-d90fb70a9c5d'
  )
ORDER BY sg.name, u.full_name;

-- kategori -> ekip eslemesi
SELECT cc.category_key, sg.name AS ekip, cc.ekip_gorunum_adi
FROM classification_categories cc
LEFT JOIN support_groups sg ON sg.id = cc.ekip_group_id
WHERE cc.is_active = true
ORDER BY cc.category_key;
