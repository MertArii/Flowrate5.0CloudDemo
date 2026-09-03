SELECT 'support_groups' AS tbl, count(*) FROM support_groups
UNION ALL SELECT 'sla_policies', count(*) FROM sla_policies
UNION ALL SELECT 'classification_categories', count(*) FROM classification_categories
UNION ALL SELECT 'users', count(*) FROM users
UNION ALL SELECT 'routing_rules', count(*) FROM routing_rules;

-- ekip_group_id gercekten dolu mu (FK baglantisi saglikli mi)
SELECT category_key, ekip_group_id IS NOT NULL AS ekibi_var
FROM classification_categories ORDER BY category_key;
