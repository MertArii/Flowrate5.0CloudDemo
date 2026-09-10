-- ===========================================================================
-- 120 Adet Örnek Ticket Ekleme Scripti (Kusursuz FK, SLA ve Bölge Eşleşmeleri)
-- Çalıştırma: DBeaver veya psql üzerinde tek seferde çalıştırılabilir.
-- ===========================================================================

DO $$
DECLARE
    v_ticket_id UUID;
    v_msg_id    UUID;
    v_user_id   UUID;
    v_agent_id  UUID;
    v_group_id  UUID;
    v_subcat_id UUID;
    v_sap_id    UUID;
    v_sla_id    UUID;
BEGIN
    -- [1/120] FB60 Satıcı Faturası Girişinde KDV Hesaplama Hatası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('ahmet.yilmaz@sirket.com', 'Ahmet Yilmaz', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'ogulcan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Fiyatlama / Muhasebe / Vergi / Rapor Uyuşmazlığı' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'ahmet.yilmaz@sirket.com', v_user_id, 'sapdestek@sirket.com', 'FB60 Satıcı Faturası Girişinde KDV Hesaplama Hatası',
        'Ankara bölge müdürlüğü için gelen %20 KDV oranlı satıcı faturasını FB60 ile girerken sistem otomatik olarak %10 hesaplamakta ve bakiye farkı vermektedir.', 'SAP-FI', 'Ankara', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'ahmet.yilmaz@sirket.com', 'customer', 'Ankara bölge müdürlüğü için gelen %20 KDV oranlı satıcı faturasını FB60 ile girerken sistem otomatik olarak %10 hesaplamakta ve bakiye farkı vermektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-FI', 'oncelik', 'high', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-FI', 'Ankara bölge müdürlüğü için gelen %20 KDV oranlı satıcı faturasını FB60 ile girerken sistem otomatik olarak %10 hesaplamakta ve bakiye farkı vermektedir.', 'Satıcı ana verisinde vergi göstergesi kontrol edildi. Doğru vergi kodu atanarak FB60 faturası muhasebeleştirildi.', true);

    ---------------------------------------------------------------------------
    -- [2/120] Ay Sonu Amortisman Çalıştırma (AFAB) Duruşu
    INSERT INTO users (email, full_name, role, region)
    VALUES ('deniz.kor@sirket.com', 'Deniz Kor', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'ogulcan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Dönem Açılış / Kapanış' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'deniz.kor@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Ay Sonu Amortisman Çalıştırma (AFAB) Duruşu',
        'İstanbul genel merkez şirket kodu için AFAB amortisman programı çalıştırıldığında ''Duran varlık 400102 için değer hatası'' vererek süreç yarıda kalmaktadır.', 'SAP-FI', 'İstanbul', 'in_progress',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'deniz.kor@sirket.com', 'customer', 'İstanbul genel merkez şirket kodu için AFAB amortisman programı çalıştırıldığında ''Duran varlık 400102 için değer hatası'' vererek süreç yarıda kalmaktadır.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-FI', 'oncelik', 'urgent', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-FI', 'İstanbul genel merkez şirket kodu için AFAB amortisman programı çalıştırıldığında ''Duran varlık 400102 için değer hatası'' vererek süreç yarıda kalmaktadır.', '400102 numaralı duran varlık kartındaki amortisman anahtarı düzeltildi ve AFAB yeniden başlatılarak dönem başarıyla kapatıldı.', true);

    ---------------------------------------------------------------------------
    -- [3/120] F-03 Açık Kalem Denkleştirmede Kur Farkı Hatası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('kemal.arslan@sirket.com', 'Kemal Arslan', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'ogulcan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Entegrasyon Hataları' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'kemal.arslan@sirket.com', v_user_id, 'sapdestek@sirket.com', 'F-03 Açık Kalem Denkleştirmede Kur Farkı Hatası',
        'Sakarya tesisimiz için dövizli banka havalesi ile açık müşteri faturasını F-03 işleminde eşleştirirken kur farkı hesabı tayin edilemediği uyarısı çıkmaktadır.', 'SAP-FI', 'Sakarya', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'kemal.arslan@sirket.com', 'customer', 'Sakarya tesisimiz için dövizli banka havalesi ile açık müşteri faturasını F-03 işleminde eşleştirirken kur farkı hesabı tayin edilemediği uyarısı çıkmaktadır.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-FI', 'oncelik', 'high', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-FI', 'Sakarya tesisimiz için dövizli banka havalesi ile açık müşteri faturasını F-03 işleminde eşleştirirken kur farkı hesabı tayin edilemediği uyarısı çıkmaktadır.', 'OB09 işlem kodu üzerinden ilgili döviz cinsi için kur farkı gelir/gider hesap tayini tanımlandı.', true);

    ---------------------------------------------------------------------------
    -- [4/120] Yozgat Şubesi İçin Yeni Banka Hesabı ve GL Hesap Tanımı
    INSERT INTO users (email, full_name, role, region)
    VALUES ('selim.kaya@sirket.com', 'Selim Kaya', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'ogulcan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Şirket / Şube / Tesis Tanımı' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'selim.kaya@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Yozgat Şubesi İçin Yeni Banka Hesabı ve GL Hesap Tanımı',
        'Yozgat şubesinde açılan yeni Ziraat Bankası ticari hesabı için FI modülünde ana hesap (FS00) ve banka ana veri eşleştirmelerinin yapılması rica olunur.', 'SAP-FI', 'Yozgat', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'selim.kaya@sirket.com', 'customer', 'Yozgat şubesinde açılan yeni Ziraat Bankası ticari hesabı için FI modülünde ana hesap (FS00) ve banka ana veri eşleştirmelerinin yapılması rica olunur.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-FI', 'oncelik', 'medium', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-FI', 'Yozgat şubesinde açılan yeni Ziraat Bankası ticari hesabı için FI modülünde ana hesap (FS00) ve banka ana veri eşleştirmelerinin yapılması rica olunur.', 'FS00 ile 102.04.015 ana hesabı açıldı ve FI-12 üzerinden Ziraat Bankası Yozgat şubesi hesap parametreleri bağlandı.', true);

    ---------------------------------------------------------------------------
    -- [5/120] F.01 Mizan Raporunda Kar/Zarar Hesap Grubu Eşleşmeme Hatası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('buse.kara@sirket.com', 'Buse Kara', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'ogulcan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Fiyatlama / Muhasebe / Vergi / Rapor Uyuşmazlığı' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'buse.kara@sirket.com', v_user_id, 'sapdestek@sirket.com', 'F.01 Mizan Raporunda Kar/Zarar Hesap Grubu Eşleşmeme Hatası',
        'İstanbul finans ekibi mali mizan çekerken bazı 6''lı gelir hesaplarının bilanço yapısında tanımlı olmadığı uyarısını almaktadır.', 'SAP-FI', 'İstanbul', 'resolved',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'buse.kara@sirket.com', 'customer', 'İstanbul finans ekibi mali mizan çekerken bazı 6''lı gelir hesaplarının bilanço yapısında tanımlı olmadığı uyarısını almaktadır.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-FI', 'oncelik', 'medium', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-FI', 'İstanbul finans ekibi mali mizan çekerken bazı 6''lı gelir hesaplarının bilanço yapısında tanımlı olmadığı uyarısını almaktadır.', 'OB58 bilanço/gelir tablosu yapısına ilgili 600''lü hesaplar eklenerek raporlama hiyerarşisi güncellendi.', true);

    ---------------------------------------------------------------------------
    -- [6/120] MIGO Mal Girişi Sırasında WRX Hesap Belirleme Hatası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('orhan.kaya@sirket.com', 'Orhan Kaya', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'omer.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Entegrasyon Hataları' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'orhan.kaya@sirket.com', v_user_id, 'sapdestek@sirket.com', 'MIGO Mal Girişi Sırasında WRX Hesap Belirleme Hatası',
        'Yozgat fabrikasına ulaşan hammadde irsaliyesini MIGO ile sisteme alırken ''WRX hesabı belirlenemedi'' hatası ile işlem engellenmektedir.', 'SAP-MM', 'Yozgat', 'assigned',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'orhan.kaya@sirket.com', 'customer', 'Yozgat fabrikasına ulaşan hammadde irsaliyesini MIGO ile sisteme alırken ''WRX hesabı belirlenemedi'' hatası ile işlem engellenmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-MM', 'oncelik', 'urgent', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-MM', 'Yozgat fabrikasına ulaşan hammadde irsaliyesini MIGO ile sisteme alırken ''WRX hesabı belirlenemedi'' hatası ile işlem engellenmektedir.', 'OBYC üzerinden WRX (fatura/mal girişi takas hesabı) tayini yapılarak mal kabul işlemi tamamlatıldı.', true);

    ---------------------------------------------------------------------------
    -- [7/120] ME21N Satınalma Siparişi Tutar Onay Stratejisi Çalışmıyor
    INSERT INTO users (email, full_name, role, region)
    VALUES ('mert.aydin@sirket.com', 'Mert Aydin', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'sena.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Geliştirme / Uyarlama Hatası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'mert.aydin@sirket.com', v_user_id, 'sapdestek@sirket.com', 'ME21N Satınalma Siparişi Tutar Onay Stratejisi Çalışmıyor',
        'Ankara bölge satın alımlarında 100.000 TL üzeri siparişlerde direktör onay adımı açılmadan sipariş serbest kalmaktadır.', 'SAP-MM', 'Ankara', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'mert.aydin@sirket.com', 'customer', 'Ankara bölge satın alımlarında 100.000 TL üzeri siparişlerde direktör onay adımı açılmadan sipariş serbest kalmaktadır.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-MM', 'oncelik', 'high', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-MM', 'Ankara bölge satın alımlarında 100.000 TL üzeri siparişlerde direktör onay adımı açılmadan sipariş serbest kalmaktadır.', 'CL20N sınıflandırma koşulları ve onay stratejisi matrisi güncellenerek 100.000 TL üzeri siparişlere direktör onay zorunluluğu getirildi.', true);

    ---------------------------------------------------------------------------
    -- [8/120] Sakarya Depo İçin Yeni Malzeme Kartı Genişletme
    INSERT INTO users (email, full_name, role, region)
    VALUES ('turgay.yilmaz@sirket.com', 'Turgay Yilmaz', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'omer.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Şirket / Şube / Tesis Tanımı' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'turgay.yilmaz@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Sakarya Depo İçin Yeni Malzeme Kartı Genişletme',
        'Üretim hattında kullanılacak yeni ambalaj malzemesi (KOD: AMB-402) için Sakarya depo yeri ve tesis verilerinin MM01 üzerinden açılması gerekmektedir.', 'SAP-MM', 'Sakarya', 'resolved',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'turgay.yilmaz@sirket.com', 'customer', 'Üretim hattında kullanılacak yeni ambalaj malzemesi (KOD: AMB-402) için Sakarya depo yeri ve tesis verilerinin MM01 üzerinden açılması gerekmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-MM', 'oncelik', 'medium', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-MM', 'Üretim hattında kullanılacak yeni ambalaj malzemesi (KOD: AMB-402) için Sakarya depo yeri ve tesis verilerinin MM01 üzerinden açılması gerekmektedir.', 'MM01 üzerinden Sakarya tesisine (1020) ait depolama ve muhasebe görünümleri açılarak malzeme kullanıma hazırlandı.', true);

    ---------------------------------------------------------------------------
    -- [9/120] MI07 Envanter Sayım Farkı Kaydında Tolerans Aşımı
    INSERT INTO users (email, full_name, role, region)
    VALUES ('canan.ozer@sirket.com', 'Canan Ozer', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'sena.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Fiyatlama / Muhasebe / Vergi / Rapor Uyuşmazlığı' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'canan.ozer@sirket.com', v_user_id, 'sapdestek@sirket.com', 'MI07 Envanter Sayım Farkı Kaydında Tolerans Aşımı',
        'İstanbul merkez depodaki periyodik sayım sonucunda oluşan miktar farkı tolerans limitini aştığı için sistem kayda izin vermiyor.', 'SAP-MM', 'İstanbul', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'canan.ozer@sirket.com', 'customer', 'İstanbul merkez depodaki periyodik sayım sonucunda oluşan miktar farkı tolerans limitini aştığı için sistem kayda izin vermiyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-MM', 'oncelik', 'high', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-MM', 'İstanbul merkez depodaki periyodik sayım sonucunda oluşan miktar farkı tolerans limitini aştığı için sistem kayda izin vermiyor.', 'Sayım farkı yöneticisi onayı alınarak tolerans limiti geçici olarak genişletildi ve MI07 fark kaydı işlendi.', true);

    ---------------------------------------------------------------------------
    -- [10/120] Yozgat Tesisi İçin Fason Satınalma Süreci Eğitimi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('hakan.tunc@sirket.com', 'Hakan Tunc', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'omer.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Eğitim Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'low' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'hakan.tunc@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Yozgat Tesisi İçin Fason Satınalma Süreci Eğitimi',
        'Yozgat fabrikasındaki yeni satınalma uzmanlarına fason sipariş (541 hareket kodu ve alt yüklenici faturası) adımlarının anlatılması talep edilmektedir.', 'SAP-MM', 'Yozgat', 'assigned',
        'low', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'hakan.tunc@sirket.com', 'customer', 'Yozgat fabrikasındaki yeni satınalma uzmanlarına fason sipariş (541 hareket kodu ve alt yüklenici faturası) adımlarının anlatılması talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-MM', 'oncelik', 'low', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-MM', 'Yozgat fabrikasındaki yeni satınalma uzmanlarına fason sipariş (541 hareket kodu ve alt yüklenici faturası) adımlarının anlatılması talep edilmektedir.', 'Fason üretim malzeme hareketleri ve alt yüklenici süreç dokümanı paylaşılarak online eğitim planlandı.', true);

    ---------------------------------------------------------------------------
    -- [11/120] Kısmi Teslimat Engeli Nedeniyle Sevkiyat Yapılamıyor
    INSERT INTO users (email, full_name, role, region)
    VALUES ('serkan.yavuz@sirket.com', 'Serkan Yavuz', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'gizem.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Veri Düzeltme' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'serkan.yavuz@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Kısmi Teslimat Engeli Nedeniyle Sevkiyat Yapılamıyor',
        'İstanbul müşterimizin siparişindeki 100 ürünün acil olan 20 tanesini sevk etmek istiyoruz ancak kısmi teslimat engeli kısıt koyuyor.', 'SAP-SD', 'İstanbul', 'assigned',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'serkan.yavuz@sirket.com', 'customer', 'İstanbul müşterimizin siparişindeki 100 ürünün acil olan 20 tanesini sevk etmek istiyoruz ancak kısmi teslimat engeli kısıt koyuyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-SD', 'oncelik', 'urgent', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-SD', 'İstanbul müşterimizin siparişindeki 100 ürünün acil olan 20 tanesini sevk etmek istiyoruz ancak kısmi teslimat engeli kısıt koyuyor.', 'Siparişteki kısmi teslimat göstergesi ''Bölünemez'' statüsünden ''Kısmi teslime izin ver'' olarak güncellendi.', true);

    ---------------------------------------------------------------------------
    -- [12/120] VF11 Fatura İptalinde Kapalı Dönem Uyarısı
    INSERT INTO users (email, full_name, role, region)
    VALUES ('fatma.guler@sirket.com', 'Fatma Guler', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'sena.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Dönem Açılış / Kapanış' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'fatma.guler@sirket.com', v_user_id, 'sapdestek@sirket.com', 'VF11 Fatura İptalinde Kapalı Dönem Uyarısı',
        'Ankara satış ofisinde hatalı kesilen e-faturayı iptal ederken ''Dönem kapalı'' uyarısı alınmakta ve ters kayıt oluşmamaktadır.', 'SAP-SD', 'Ankara', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'fatma.guler@sirket.com', 'customer', 'Ankara satış ofisinde hatalı kesilen e-faturayı iptal ederken ''Dönem kapalı'' uyarısı alınmakta ve ters kayıt oluşmamaktadır.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-SD', 'oncelik', 'high', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-SD', 'Ankara satış ofisinde hatalı kesilen e-faturayı iptal ederken ''Dönem kapalı'' uyarısı alınmakta ve ters kayıt oluşmamaktadır.', 'Ters kayıt tarihi güncel açık döneme yönlendirilerek VF11 iptal kaydı başarıyla oluşturuldu.', true);

    ---------------------------------------------------------------------------
    -- [13/120] E-İrsaliye GİB Entegratör Gönderim Hatası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('ismail.cetin@sirket.com', 'Ismail Cetin', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'gizem.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'E-Dönüşüm Hataları (E-Fatura, E-İrsaliye vb.)' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'ismail.cetin@sirket.com', v_user_id, 'sapdestek@sirket.com', 'E-İrsaliye GİB Entegratör Gönderim Hatası',
        'Sakarya deposundan çıkan sevkiyatların e-irsaliyeleri entegratöre iletilirken ''VKN formatı geçersiz'' hatasıyla kuyrukta beklemektedir.', 'SAP-SD', 'Sakarya', 'assigned',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'ismail.cetin@sirket.com', 'customer', 'Sakarya deposundan çıkan sevkiyatların e-irsaliyeleri entegratöre iletilirken ''VKN formatı geçersiz'' hatasıyla kuyrukta beklemektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-SD', 'oncelik', 'urgent', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-SD', 'Sakarya deposundan çıkan sevkiyatların e-irsaliyeleri entegratöre iletilirken ''VKN formatı geçersiz'' hatasıyla kuyrukta beklemektedir.', 'Müşteri ana verisindeki vergi numarası kontrol edildi, baştaki boşluk karakteri silinip e-irsaliye kuyruğu tekrar tetiklendi.', true);

    ---------------------------------------------------------------------------
    -- [14/120] Yozgat Bölgesi İçin Yeni Satış Fiyat Listesi (VK11) Uyarlaması
    INSERT INTO users (email, full_name, role, region)
    VALUES ('ali.dogan@sirket.com', 'Ali Dogan', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'sena.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Geliştirme / Ekip Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'ali.dogan@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Yozgat Bölgesi İçin Yeni Satış Fiyat Listesi (VK11) Uyarlaması',
        'Yozgat ve İç Anadolu bayilerine özel olarak belirlenen iskonto ve yeni fiyat koşullarının VK11 üzerinde sisteme tanımlanması talep edilmektedir.', 'SAP-SD', 'Yozgat', 'resolved',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'ali.dogan@sirket.com', 'customer', 'Yozgat ve İç Anadolu bayilerine özel olarak belirlenen iskonto ve yeni fiyat koşullarının VK11 üzerinde sisteme tanımlanması talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-SD', 'oncelik', 'medium', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-SD', 'Yozgat ve İç Anadolu bayilerine özel olarak belirlenen iskonto ve yeni fiyat koşullarının VK11 üzerinde sisteme tanımlanması talep edilmektedir.', 'VK11 üzerinden PR00 ve ZDIS koşul türleri bölgesel müşteri grubuna tanımlandı.', true);

    ---------------------------------------------------------------------------
    -- [15/120] Yeni Bayi İçin FD32 Kredi Limiti Açılması
    INSERT INTO users (email, full_name, role, region)
    VALUES ('nihal.sari@sirket.com', 'Nihal Sari', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'gizem.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Geliştirme / Ekip Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'nihal.sari@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Yeni Bayi İçin FD32 Kredi Limiti Açılması',
        'İstanbul Anadolu yakası yeni bayimiz için FD32 işleminden 750.000 TL kredi limiti tanımlanması ve risk kategorisinin belirlenmesi rica olunur.', 'SAP-SD', 'İstanbul', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'nihal.sari@sirket.com', 'customer', 'İstanbul Anadolu yakası yeni bayimiz için FD32 işleminden 750.000 TL kredi limiti tanımlanması ve risk kategorisinin belirlenmesi rica olunur.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-SD', 'oncelik', 'medium', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-SD', 'İstanbul Anadolu yakası yeni bayimiz için FD32 işleminden 750.000 TL kredi limiti tanımlanması ve risk kategorisinin belirlenmesi rica olunur.', 'Kredi komitesi onayı doğrultusunda FD32''de 750.000 TL limit açılarak risk sınıfı ''B'' olarak tanımlandı.', true);

    ---------------------------------------------------------------------------
    -- [16/120] SAP Canlı Sistemde Toplu Kilitlenme (Enqueue Server)
    INSERT INTO users (email, full_name, role, region)
    VALUES ('engin.tekin@sirket.com', 'Engin Tekin', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'mustafa.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Server / Sanallaştırma Arızası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'engin.tekin@sirket.com', v_user_id, 'sapdestek@sirket.com', 'SAP Canlı Sistemde Toplu Kilitlenme (Enqueue Server)',
        'İstanbul genel merkez ve tüm şubelerde kullanıcılar SM12 üzerinde kilitlenmeler yaşamakta ve sistem yanıt vermemektedir.', 'SAP-Basis', 'İstanbul', 'in_progress',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'engin.tekin@sirket.com', 'customer', 'İstanbul genel merkez ve tüm şubelerde kullanıcılar SM12 üzerinde kilitlenmeler yaşamakta ve sistem yanıt vermemektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Basis', 'oncelik', 'urgent', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Basis', 'İstanbul genel merkez ve tüm şubelerde kullanıcılar SM12 üzerinde kilitlenmeler yaşamakta ve sistem yanıt vermemektedir.', 'Askıda kalan uzun süreli arka plan job kilitleri SM12''den temizlendi ve enqueue bellek parametresi optimize edildi.', true);

    ---------------------------------------------------------------------------
    -- [17/120] Canlı Sisteme Acil Transport Talebi (STMS)
    INSERT INTO users (email, full_name, role, region)
    VALUES ('ayten.guzel@sirket.com', 'Ayten Guzel', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Geliştirme / Ekip Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'ayten.guzel@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Canlı Sisteme Acil Transport Talebi (STMS)',
        'Ankara faturalama sürecinde oluşan kritik hatayı gideren TRK900452 numaralı transport paketinin canlı ortama aktarılması gerekmektedir.', 'SAP-Basis', 'Ankara', 'resolved',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'ayten.guzel@sirket.com', 'customer', 'Ankara faturalama sürecinde oluşan kritik hatayı gideren TRK900452 numaralı transport paketinin canlı ortama aktarılması gerekmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Basis', 'oncelik', 'high', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Basis', 'Ankara faturalama sürecinde oluşan kritik hatayı gideren TRK900452 numaralı transport paketinin canlı ortama aktarılması gerekmektedir.', 'STMS üzerinden kalite onayı doğrulanmış TRK900452 talebi PRD sistemine import edildi.', true);

    ---------------------------------------------------------------------------
    -- [18/120] Yozgat Fabrika Yazıcısı İçin SPAD Çıktı Cihazı Tanımlama
    INSERT INTO users (email, full_name, role, region)
    VALUES ('remzi.usta@sirket.com', 'Remzi Usta', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'mustafa.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Şirket / Şube / Tesis Tanımı' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'remzi.usta@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Yozgat Fabrika Yazıcısı İçin SPAD Çıktı Cihazı Tanımlama',
        'Yozgat sevkiyat alanına yeni kurulan barkod yazıcısının SAP SPAD işlem kodu üzerinden ağ yazıcısı olarak tanımlanması rica olunur.', 'SAP-Basis', 'Yozgat', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'remzi.usta@sirket.com', 'customer', 'Yozgat sevkiyat alanına yeni kurulan barkod yazıcısının SAP SPAD işlem kodu üzerinden ağ yazıcısı olarak tanımlanması rica olunur.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Basis', 'oncelik', 'medium', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Basis', 'Yozgat sevkiyat alanına yeni kurulan barkod yazıcısının SAP SPAD işlem kodu üzerinden ağ yazıcısı olarak tanımlanması rica olunur.', 'SPAD üzerinde ''YOZ_ZEBRA_01'' çıktı aygıtı access method U ve IP adresi ile tanımlanarak test çıktısı alındı.', true);

    ---------------------------------------------------------------------------
    -- [19/120] SAP Logon Single Sign-On (SNC) Bağlantı Hatası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('nermin.aslan@sirket.com', 'Nermin Aslan', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Active Directory Arızası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'nermin.aslan@sirket.com', v_user_id, 'sapdestek@sirket.com', 'SAP Logon Single Sign-On (SNC) Bağlantı Hatası',
        'Sakarya kalite laboratuvarındaki bilgisayarlarda SAP Logon açılırken ''SNC GSS-API error'' hatası alınmakta ve şifre ekranı gelmemektedir.', 'SAP-Basis', 'Sakarya', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'nermin.aslan@sirket.com', 'customer', 'Sakarya kalite laboratuvarındaki bilgisayarlarda SAP Logon açılırken ''SNC GSS-API error'' hatası alınmakta ve şifre ekranı gelmemektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Basis', 'oncelik', 'high', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Basis', 'Sakarya kalite laboratuvarındaki bilgisayarlarda SAP Logon açılırken ''SNC GSS-API error'' hatası alınmakta ve şifre ekranı gelmemektedir.', 'Kullanıcı bilgisayarındaki Kerberos bilet önbelleği temizlendi ve sncgss32.dll kütüphanesi yeniden kaydedildi.', true);

    ---------------------------------------------------------------------------
    -- [20/120] Test Sistemi (QAS) Günlük DB Backup ve Snapshot Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('cengiz.kaya@sirket.com', 'Cengiz Kaya', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'mustafa.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yedekleme / Snapshot Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'low' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'cengiz.kaya@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Test Sistemi (QAS) Günlük DB Backup ve Snapshot Talebi',
        'İstanbul yazılım geliştirme ekibinin yapacağı versiyon güncellemesi öncesinde SAP QAS veritabanı yedeğinin alınması rica olunur.', 'SAP-Basis', 'İstanbul', 'resolved',
        'low', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'cengiz.kaya@sirket.com', 'customer', 'İstanbul yazılım geliştirme ekibinin yapacağı versiyon güncellemesi öncesinde SAP QAS veritabanı yedeğinin alınması rica olunur.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Basis', 'oncelik', 'low', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Basis', 'İstanbul yazılım geliştirme ekibinin yapacağı versiyon güncellemesi öncesinde SAP QAS veritabanı yedeğinin alınması rica olunur.', 'QAS sanal sunucusu üzerinde VMware snapshot ve HANA tam DB backup işlemi tamamlandı.', true);

    ---------------------------------------------------------------------------
    -- [21/120] SU53 Yetki Hatası - VA02 Sipariş Değiştirme
    INSERT INTO users (email, full_name, role, region)
    VALUES ('sevgi.can@sirket.com', 'Sevgi Can', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yetki Hatası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'sevgi.can@sirket.com', v_user_id, 'sapdestek@sirket.com', 'SU53 Yetki Hatası - VA02 Sipariş Değiştirme',
        'Ankara satış ekibine transfer olan personele VA02 yetkisi verilmiş görünmesine rağmen sipariş kaydederken ''V_VBAK_AAT yetkisi eksik'' hatası çıkıyor.', 'SAP-Yetki', 'Ankara', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'sevgi.can@sirket.com', 'customer', 'Ankara satış ekibine transfer olan personele VA02 yetkisi verilmiş görünmesine rağmen sipariş kaydederken ''V_VBAK_AAT yetkisi eksik'' hatası çıkıyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Yetki', 'oncelik', 'high', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Yetki', 'Ankara satış ekibine transfer olan personele VA02 yetkisi verilmiş görünmesine rağmen sipariş kaydederken ''V_VBAK_AAT yetkisi eksik'' hatası çıkıyor.', 'PFCG üzerinden Z_SD_SATIS rolündeki V_VBAK_AAT nesnesine Ankara satış organizasyonu yetkisi eklenip kullanıcıya yeniden üretildi.', true);

    ---------------------------------------------------------------------------
    -- [22/120] Yeni İşe Başlayan Finans Uzmanı İçin SAP Rol Tanımlama
    INSERT INTO users (email, full_name, role, region)
    VALUES ('ihsan.demir@sirket.com', 'Ihsan Demir', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Yetki / Rol Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'ihsan.demir@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Yeni İşe Başlayan Finans Uzmanı İçin SAP Rol Tanımlama',
        'İstanbul muhasebe departmanında işe başlayan Ayşe Yılmaz için Z_FI_MUHASEBE_UZMAN rolünün SU01 üzerinden atanması talep edilmektedir.', 'SAP-Yetki', 'İstanbul', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'ihsan.demir@sirket.com', 'customer', 'İstanbul muhasebe departmanında işe başlayan Ayşe Yılmaz için Z_FI_MUHASEBE_UZMAN rolünün SU01 üzerinden atanması talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Yetki', 'oncelik', 'medium', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Yetki', 'İstanbul muhasebe departmanında işe başlayan Ayşe Yılmaz için Z_FI_MUHASEBE_UZMAN rolünün SU01 üzerinden atanması talep edilmektedir.', 'SU01 üzerinde kullanıcı açılarak Z_FI_MUHASEBE_UZMAN rolü ve ilgili şirket kodu yetkileri atandı.', true);

    ---------------------------------------------------------------------------
    -- [23/120] Yozgat Fabrika Depo Sorumlusu MIGO Yetki Genişletmesi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('hasan.tatar@sirket.com', 'Hasan Tatar', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Yetki / Rol Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'hasan.tatar@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Yozgat Fabrika Depo Sorumlusu MIGO Yetki Genişletmesi',
        'Yozgat fabrikasında vardiya amirinin sadece 101 değil 311 depo transfer hareketlerini de yapabilmesi için MM rolünün güncellenmesi rica olunur.', 'SAP-Yetki', 'Yozgat', 'resolved',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'hasan.tatar@sirket.com', 'customer', 'Yozgat fabrikasında vardiya amirinin sadece 101 değil 311 depo transfer hareketlerini de yapabilmesi için MM rolünün güncellenmesi rica olunur.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Yetki', 'oncelik', 'medium', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Yetki', 'Yozgat fabrikasında vardiya amirinin sadece 101 değil 311 depo transfer hareketlerini de yapabilmesi için MM rolünün güncellenmesi rica olunur.', 'M_MSEG_BWA nesnesine 311 ve 312 hareket türleri eklenerek depo amiri rolü güncellendi.', true);

    ---------------------------------------------------------------------------
    -- [24/120] Sakarya Kalite Kontrol Ekibi QA32 Onay Yetkisi Uyarısı
    INSERT INTO users (email, full_name, role, region)
    VALUES ('mualla.kurt@sirket.com', 'Mualla Kurt', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yetki Hatası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'QM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'mualla.kurt@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Sakarya Kalite Kontrol Ekibi QA32 Onay Yetkisi Uyarısı',
        'Sakarya kalite sorumlusu partiyi serbest bırakmak istediğinde ''Kullanım kararı yetkisi (Q_INSP_RES) bulunmamaktadır'' uyarısı alıyor.', 'SAP-Yetki', 'Sakarya', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'mualla.kurt@sirket.com', 'customer', 'Sakarya kalite sorumlusu partiyi serbest bırakmak istediğinde ''Kullanım kararı yetkisi (Q_INSP_RES) bulunmamaktadır'' uyarısı alıyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Yetki', 'oncelik', 'high', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Yetki', 'Sakarya kalite sorumlusu partiyi serbest bırakmak istediğinde ''Kullanım kararı yetkisi (Q_INSP_RES) bulunmamaktadır'' uyarısı alıyor.', 'Q_INSP_RES nesnesi ve QA11/QA32 işlem yetkileri kalite uzmanı kullanıcısına atandı.', true);

    ---------------------------------------------------------------------------
    -- [25/120] Ayrılan Personelin SAP Kullanıcı Hesabının Kilitlenmesi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('aylin.sen@sirket.com', 'Aylin Sen', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Yetki / Rol Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'aylin.sen@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Ayrılan Personelin SAP Kullanıcı Hesabının Kilitlenmesi',
        'İstanbul satınalma biriminden istifa eden personelin SAP kullanıcısının SU01 üzerinden kilitlenmesi ve rollerinin kaldırılması gerekmektedir.', 'SAP-Yetki', 'İstanbul', 'resolved',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'aylin.sen@sirket.com', 'customer', 'İstanbul satınalma biriminden istifa eden personelin SAP kullanıcısının SU01 üzerinden kilitlenmesi ve rollerinin kaldırılması gerekmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Yetki', 'oncelik', 'urgent', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Yetki', 'İstanbul satınalma biriminden istifa eden personelin SAP kullanıcısının SU01 üzerinden kilitlenmesi ve rollerinin kaldırılması gerekmektedir.', 'SU01 üzerinde kullanıcı kilitlendi, geçerlilik tarihi bugüne çekildi ve tüm yetki rolleri kaldırıldı.', true);

    ---------------------------------------------------------------------------
    -- [26/120] Sakarya Tesisi İnternet ve Metro Ethernet Kesintisi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('sabri.guler@sirket.com', 'Sabri Guler', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'İnternet Kesintisi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'sabri.guler@sirket.com', v_user_id, 'btdestek@sirket.com', 'Sakarya Tesisi İnternet ve Metro Ethernet Kesintisi',
        'Sakarya üretim tesisimizdeki ana internet hattı tamamen kesildi, şube ile genel merkez arasındaki MPLS tüneli düştü.', 'IT-Ag', 'Sakarya', 'in_progress',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'sabri.guler@sirket.com', 'customer', 'Sakarya üretim tesisimizdeki ana internet hattı tamamen kesildi, şube ile genel merkez arasındaki MPLS tüneli düştü.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Ag', 'oncelik', 'urgent', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Ag', 'Sakarya üretim tesisimizdeki ana internet hattı tamamen kesildi, şube ile genel merkez arasındaki MPLS tüneli düştü.', 'Servis sağlayıcı (ISP) ile irtibata geçilerek bölgedeki fiber kablo kopması tespit edildi ve yedek LTE hattı devreye alındı.', true);

    ---------------------------------------------------------------------------
    -- [27/120] FortiClient SSL-VPN Bağlantı Kopması (Error 455)
    INSERT INTO users (email, full_name, role, region)
    VALUES ('pelin.kaya@sirket.com', 'Pelin Kaya', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'VPN Bağlantı Sorunları' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'pelin.kaya@sirket.com', v_user_id, 'btdestek@sirket.com', 'FortiClient SSL-VPN Bağlantı Kopması (Error 455)',
        'Ankara ofisinden uzaktan çalışan mühendislerimiz VPN bağlantısı kurduktan sonra 5 dakika içinde oturumun koptuğunu bildirmektedir.', 'IT-Ag', 'Ankara', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'pelin.kaya@sirket.com', 'customer', 'Ankara ofisinden uzaktan çalışan mühendislerimiz VPN bağlantısı kurduktan sonra 5 dakika içinde oturumun koptuğunu bildirmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Ag', 'oncelik', 'high', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Ag', 'Ankara ofisinden uzaktan çalışan mühendislerimiz VPN bağlantısı kurduktan sonra 5 dakika içinde oturumun koptuğunu bildirmektedir.', 'FortiGate firewall üzerindeki VPN idle-timeout süresi 8 saate çıkarıldı ve istemci MTU boyutu 1350 olarak ayarlandı.', true);

    ---------------------------------------------------------------------------
    -- [28/120] İstanbul Genel Merkez 3. Kat Wi-Fi Sinyal Zayıflığı
    INSERT INTO users (email, full_name, role, region)
    VALUES ('tarik.yildiz@sirket.com', 'Tarik Yildiz', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Erişim Yavaşlığı' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'tarik.yildiz@sirket.com', v_user_id, 'btdestek@sirket.com', 'İstanbul Genel Merkez 3. Kat Wi-Fi Sinyal Zayıflığı',
        'İstanbul A Blok 3. kat toplantı odalarında kablosuz ağ (Corporate-WiFi) sinyali zayıf ve görüntülü toplantılarda kopmalar yaşanıyor.', 'IT-Ag', 'İstanbul', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'tarik.yildiz@sirket.com', 'customer', 'İstanbul A Blok 3. kat toplantı odalarında kablosuz ağ (Corporate-WiFi) sinyali zayıf ve görüntülü toplantılarda kopmalar yaşanıyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Ag', 'oncelik', 'medium', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Ag', 'İstanbul A Blok 3. kat toplantı odalarında kablosuz ağ (Corporate-WiFi) sinyali zayıf ve görüntülü toplantılarda kopmalar yaşanıyor.', '3. kattaki Access Point (AP) kanalları çakışmaya karşı yeniden yapılandırıldı ve yayın gücü artırıldı.', true);

    ---------------------------------------------------------------------------
    -- [29/120] Yozgat Fabrika NVR Güvenlik Kamerası İçin Statik IP ve Port İzni
    INSERT INTO users (email, full_name, role, region)
    VALUES ('hasan.koc@sirket.com', 'Hasan Koc', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Firma Dışı Erişim / Port Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'hasan.koc@sirket.com', v_user_id, 'btdestek@sirket.com', 'Yozgat Fabrika NVR Güvenlik Kamerası İçin Statik IP ve Port İzni',
        'Yozgat depoya kurulan yeni kamera kayıt cihazının merkez güvenlik birimince izlenebilmesi için firewall üzerinde port yönlendirmesi talep edilmektedir.', 'IT-Ag', 'Yozgat', 'resolved',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'hasan.koc@sirket.com', 'customer', 'Yozgat depoya kurulan yeni kamera kayıt cihazının merkez güvenlik birimince izlenebilmesi için firewall üzerinde port yönlendirmesi talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Ag', 'oncelik', 'medium', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Ag', 'Yozgat depoya kurulan yeni kamera kayıt cihazının merkez güvenlik birimince izlenebilmesi için firewall üzerinde port yönlendirmesi talep edilmektedir.', 'Firewall üzerinde NVR cihazı için VIP ve port yönlendirme kuralı açılarak merkez güvenlik erişimi sağlandı.', true);

    ---------------------------------------------------------------------------
    -- [30/120] Dış Denetim Ekibi İçin Misafir Wi-Fi Hesabı Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('zeynep.avci@sirket.com', 'Zeynep Avci', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Wi-Fi / Misafir Ağı Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'low' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'zeynep.avci@sirket.com', v_user_id, 'btdestek@sirket.com', 'Dış Denetim Ekibi İçin Misafir Wi-Fi Hesabı Talebi',
        'İstanbul ofisimize 3 gün süreyle gelecek olan bağımsız denetçiler için internet erişimli misafir Wi-Fi şifrelerinin oluşturulması rica olunur.', 'IT-Ag', 'İstanbul', 'resolved',
        'low', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'zeynep.avci@sirket.com', 'customer', 'İstanbul ofisimize 3 gün süreyle gelecek olan bağımsız denetçiler için internet erişimli misafir Wi-Fi şifrelerinin oluşturulması rica olunur.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Ag', 'oncelik', 'low', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Ag', 'İstanbul ofisimize 3 gün süreyle gelecek olan bağımsız denetçiler için internet erişimli misafir Wi-Fi şifrelerinin oluşturulması rica olunur.', 'Guest portal üzerinden 3 günlük süreli 5 adet misafir kullanıcı hesabı açılarak denetim ekibine teslim edildi.', true);

    ---------------------------------------------------------------------------
    -- [31/120] Ankara Ofisi Laptop Açılmıyor ve Siyah Ekran Veriyor
    INSERT INTO users (email, full_name, role, region)
    VALUES ('oguz.cetin@sirket.com', 'Oguz Cetin', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'faruk.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Laptop Arızası' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'oguz.cetin@sirket.com', v_user_id, 'btdestek@sirket.com', 'Ankara Ofisi Laptop Açılmıyor ve Siyah Ekran Veriyor',
        'Ankara satış müdürünün Dell dizüstü bilgisayarı açma tuşuna basıldığında ışıkları yanıyor ancak ekrana görüntü gelmiyor.', 'IT-Donanim', 'Ankara', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'oguz.cetin@sirket.com', 'customer', 'Ankara satış müdürünün Dell dizüstü bilgisayarı açma tuşuna basıldığında ışıkları yanıyor ancak ekrana görüntü gelmiyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Donanim', 'oncelik', 'high', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Donanim', 'Ankara satış müdürünün Dell dizüstü bilgisayarı açma tuşuna basıldığında ışıkları yanıyor ancak ekrana görüntü gelmiyor.', 'Ankara yerinde destek uzmanı cihazın RAM modülünü söküp temizleyerek statik elektriği boşalttı, görüntü sağlandı.', true);

    ---------------------------------------------------------------------------
    -- [32/120] Yozgat Fabrikası Zebra Barkod Yazıcı Kırmızı Işık Hatası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('deniz.aksoy@sirket.com', 'Deniz Aksoy', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'salih.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yazıcı Arızası' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'deniz.aksoy@sirket.com', v_user_id, 'btdestek@sirket.com', 'Yozgat Fabrikası Zebra Barkod Yazıcı Kırmızı Işık Hatası',
        'Yozgat ambarındaki etiket yazıcı ribon takılması uyarısıyla durdu, etiket basılamadığı için sevkiyat bekliyor.', 'IT-Donanim', 'Yozgat', 'in_progress',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'deniz.aksoy@sirket.com', 'customer', 'Yozgat ambarındaki etiket yazıcı ribon takılması uyarısıyla durdu, etiket basılamadığı için sevkiyat bekliyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Donanim', 'oncelik', 'urgent', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Donanim', 'Yozgat ambarındaki etiket yazıcı ribon takılması uyarısıyla durdu, etiket basılamadığı için sevkiyat bekliyor.', 'Yozgat yerinde destek uzmanı yazıcının ribon sensörünü alkolle temizledi ve mekanik kalibrasyon yaparak çalışır duruma getirdi.', true);

    ---------------------------------------------------------------------------
    -- [33/120] İstanbul Genel Merkez Harici Monitör Görüntü Vermiyor
    INSERT INTO users (email, full_name, role, region)
    VALUES ('selin.yurt@sirket.com', 'Selin Yurt', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'emirhan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Monitör Arızası' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'selin.yurt@sirket.com', v_user_id, 'btdestek@sirket.com', 'İstanbul Genel Merkez Harici Monitör Görüntü Vermiyor',
        'İstanbul finans katındaki ikinci monitör HDMI kablosu takılı olmasına rağmen ''No Signal'' uyarısı verip kapanıyor.', 'IT-Donanim', 'İstanbul', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'selin.yurt@sirket.com', 'customer', 'İstanbul finans katındaki ikinci monitör HDMI kablosu takılı olmasına rağmen ''No Signal'' uyarısı verip kapanıyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Donanim', 'oncelik', 'medium', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Donanim', 'İstanbul finans katındaki ikinci monitör HDMI kablosu takılı olmasına rağmen ''No Signal'' uyarısı verip kapanıyor.', 'İstanbul destek uzmanı masadaki kırık HDMI kablosunu yeni DisplayPort-HDMI kablosuyla değiştirerek görüntüyü sağladı.', true);

    ---------------------------------------------------------------------------
    -- [34/120] İstanbul Depo İçin El Terminali ve Barkod Okuyucu Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('buse.kara@sirket.com', 'Buse Kara', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yusuf.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Bilgisayar Çevre Birimleri Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'buse.kara@sirket.com', v_user_id, 'btdestek@sirket.com', 'İstanbul Depo İçin El Terminali ve Barkod Okuyucu Talebi',
        'İstanbul lojistik merkezinde yeni açılan kabul peronu için 1 adet kablosuz el terminali tahsis edilmesi talep edilmektedir.', 'IT-Donanim', 'İstanbul', 'resolved',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'buse.kara@sirket.com', 'customer', 'İstanbul lojistik merkezinde yeni açılan kabul peronu için 1 adet kablosuz el terminali tahsis edilmesi talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Donanim', 'oncelik', 'medium', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Donanim', 'İstanbul lojistik merkezinde yeni açılan kabul peronu için 1 adet kablosuz el terminali tahsis edilmesi talep edilmektedir.', 'Depo stoğundan Zebra TC21 el terminali hazırlanarak Wi-Fi ve SAP mobil istemcisi kurulup teslim edildi.', true);

    ---------------------------------------------------------------------------
    -- [35/120] Sakarya Fabrikası Departman Ağ Yazıcısı Kağıt Sıkışması
    INSERT INTO users (email, full_name, role, region)
    VALUES ('murat.gunes@sirket.com', 'Murat Gunes', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yazıcı Arızası' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'murat.gunes@sirket.com', v_user_id, 'btdestek@sirket.com', 'Sakarya Fabrikası Departman Ağ Yazıcısı Kağıt Sıkışması',
        'Sakarya idari binasındaki çok fonksiyonlu fotokopi makinesi tepsi 2''den kağıt çekerken sürekli sıkışma hatası veriyor.', 'IT-Donanim', 'Sakarya', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'murat.gunes@sirket.com', 'customer', 'Sakarya idari binasındaki çok fonksiyonlu fotokopi makinesi tepsi 2''den kağıt çekerken sürekli sıkışma hatası veriyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Donanim', 'oncelik', 'high', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Donanim', 'Sakarya idari binasındaki çok fonksiyonlu fotokopi makinesi tepsi 2''den kağıt çekerken sürekli sıkışma hatası veriyor.', 'Sakarya BT sorumlusu yazıcının kağıt çekme patenlerini temizledi ve kaset ayarlarını düzeltti.', true);

    ---------------------------------------------------------------------------
    -- [36/120] Domain Hesabı Kilitlendi ve Şifre Sıfırlama Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('aylin.toprak@sirket.com', 'Aylin Toprak', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'mustafa.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Kullanıcı Hesabı Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'aylin.toprak@sirket.com', v_user_id, 'btdestek@sirket.com', 'Domain Hesabı Kilitlendi ve Şifre Sıfırlama Talebi',
        'İstanbul ofisindeki kullanıcımız şifresini art arda hatalı girdiği için Active Directory hesabı kilitlenmiştir, kilidin açılması rica olunur.', 'IT-Hesap', 'İstanbul', 'resolved',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'aylin.toprak@sirket.com', 'customer', 'İstanbul ofisindeki kullanıcımız şifresini art arda hatalı girdiği için Active Directory hesabı kilitlenmiştir, kilidin açılması rica olunur.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Hesap', 'oncelik', 'high', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Hesap', 'İstanbul ofisindeki kullanıcımız şifresini art arda hatalı girdiği için Active Directory hesabı kilitlenmiştir, kilidin açılması rica olunur.', 'Active Directory üzerinden hesap kilidi kaldırıldı ve geçici parola oluşturularak kullanıcıya SMS ile iletildi.', true);

    ---------------------------------------------------------------------------
    -- [37/120] Microsoft Authenticator 2FA / MFA Sıfırlama
    INSERT INTO users (email, full_name, role, region)
    VALUES ('sinan.kurt@sirket.com', 'Sinan Kurt', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'turgut.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Kullanıcı Hesabı Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'sinan.kurt@sirket.com', v_user_id, 'btdestek@sirket.com', 'Microsoft Authenticator 2FA / MFA Sıfırlama',
        'Ankara çalışanımız telefonunu sıfırladığı için kurumsal e-postasına ve VPN''e giriş yapamamaktadır. MFA metodunun sıfırlanması rica olunur.', 'IT-Hesap', 'Ankara', 'resolved',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'sinan.kurt@sirket.com', 'customer', 'Ankara çalışanımız telefonunu sıfırladığı için kurumsal e-postasına ve VPN''e giriş yapamamaktadır. MFA metodunun sıfırlanması rica olunur.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Hesap', 'oncelik', 'urgent', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Hesap', 'Ankara çalışanımız telefonunu sıfırladığı için kurumsal e-postasına ve VPN''e giriş yapamamaktadır. MFA metodunun sıfırlanması rica olunur.', 'Entra ID (Azure AD) üzerinden eski MFA cihaz kaydı silindi ve kullanıcıya yeni Authenticator eşleme QR kodu üretildi.', true);

    ---------------------------------------------------------------------------
    -- [38/120] Yozgat Fabrikası Yeni Personel Kurumsal Mail ve AD Hesabı Açılışı
    INSERT INTO users (email, full_name, role, region)
    VALUES ('gokhan.yildirim@sirket.com', 'Gokhan Yildirim', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Kullanıcı Hesabı Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'gokhan.yildirim@sirket.com', v_user_id, 'btdestek@sirket.com', 'Yozgat Fabrikası Yeni Personel Kurumsal Mail ve AD Hesabı Açılışı',
        'Yozgat üretim tesisinde göreve başlayan Makine Mühendisi Selim Kaya için standart AD kullanıcı hesabı ve kurumsal e-posta açılması talep edilmektedir.', 'IT-Hesap', 'Yozgat', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'gokhan.yildirim@sirket.com', 'customer', 'Yozgat üretim tesisinde göreve başlayan Makine Mühendisi Selim Kaya için standart AD kullanıcı hesabı ve kurumsal e-posta açılması talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Hesap', 'oncelik', 'medium', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Hesap', 'Yozgat üretim tesisinde göreve başlayan Makine Mühendisi Selim Kaya için standart AD kullanıcı hesabı ve kurumsal e-posta açılması talep edilmektedir.', 'İnsan Kaynakları işe giriş formu doğrultusunda Active Directory hesabı ve M365 Business Standard lisansı tanımlandı.', true);

    ---------------------------------------------------------------------------
    -- [39/120] Sakarya Ortak Finans Dağıtım Listesine (DL) Ekleme Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('ik@sirket.com', 'Ik', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'mustafa.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'E-Posta / Dağıtım Grubu Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'low' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'ik@sirket.com', v_user_id, 'btdestek@sirket.com', 'Sakarya Ortak Finans Dağıtım Listesine (DL) Ekleme Talebi',
        'Sakarya muhasebe servisine yeni atanan personelin ''sakarya-finans@sirket.com'' mail grubuna üye yapılması rica olunur.', 'IT-Hesap', 'Sakarya', 'resolved',
        'low', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'ik@sirket.com', 'customer', 'Sakarya muhasebe servisine yeni atanan personelin ''sakarya-finans@sirket.com'' mail grubuna üye yapılması rica olunur.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Hesap', 'oncelik', 'low', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Hesap', 'Sakarya muhasebe servisine yeni atanan personelin ''sakarya-finans@sirket.com'' mail grubuna üye yapılması rica olunur.', 'Exchange Online yönetim merkezinden ilgili dağıtım grubuna kullanıcı üye olarak eklendi.', true);

    ---------------------------------------------------------------------------
    -- [40/120] İşten Ayrılan Personelin E-Posta ve Hesaplarının Kapatılması
    INSERT INTO users (email, full_name, role, region)
    VALUES ('ik@sirket.com', 'Ik', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'turgut.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Kullanıcı Hesabı Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'ik@sirket.com', v_user_id, 'btdestek@sirket.com', 'İşten Ayrılan Personelin E-Posta ve Hesaplarının Kapatılması',
        'İstanbul merkez ofisinden ayrılan personelin AD, e-posta ve VPN erişimlerinin derhal kapatılması ve maillerinin birim müdürüne yönlendirilmesi rica olunur.', 'IT-Hesap', 'İstanbul', 'resolved',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'ik@sirket.com', 'customer', 'İstanbul merkez ofisinden ayrılan personelin AD, e-posta ve VPN erişimlerinin derhal kapatılması ve maillerinin birim müdürüne yönlendirilmesi rica olunur.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Hesap', 'oncelik', 'urgent', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Hesap', 'İstanbul merkez ofisinden ayrılan personelin AD, e-posta ve VPN erişimlerinin derhal kapatılması ve maillerinin birim müdürüne yönlendirilmesi rica olunur.', 'Kullanıcı hesabı AD''de devre dışı bırakıldı, oturumları sonlandırıldı ve e-postaları birim yöneticisine forward edildi.', true);

    ---------------------------------------------------------------------------
    -- [41/120] FBL5N Müşteri Bakiye Raporunda Yanlış Yaşlandırma
    INSERT INTO users (email, full_name, role, region)
    VALUES ('elif.sahin@sirket.com', 'Elif Sahin', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'ogulcan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Fiyatlama / Muhasebe / Vergi / Rapor Uyuşmazlığı' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'elif.sahin@sirket.com', v_user_id, 'sapdestek@sirket.com', 'FBL5N Müşteri Bakiye Raporunda Yanlış Yaşlandırma',
        'Sakarya bayisine ait FBL5N raporunda 30 günlük dilimde görünmesi gereken faturalar 60+ gün dilimine düşüyor, yaşlandırma tarihi hesaplamasında sorun var.', 'SAP-FI', 'Sakarya', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'elif.sahin@sirket.com', 'customer', 'Sakarya bayisine ait FBL5N raporunda 30 günlük dilimde görünmesi gereken faturalar 60+ gün dilimine düşüyor, yaşlandırma tarihi hesaplamasında sorun var.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-FI', 'oncelik', 'high', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-FI', 'Sakarya bayisine ait FBL5N raporunda 30 günlük dilimde görünmesi gereken faturalar 60+ gün dilimine düşüyor, yaşlandırma tarihi hesaplamasında sorun var.', 'FBL5N rapor varyantındaki referans tarih alanı kontrol edilerek yaşlandırma başlangıç tarihi düzeltildi.', true);

    ---------------------------------------------------------------------------
    -- [42/120] Otomatik Ödeme Programı (F110) Banka Dosyası Üretemiyor
    INSERT INTO users (email, full_name, role, region)
    VALUES ('sinan.kurt@sirket.com', 'Sinan Kurt', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'ogulcan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Entegrasyon Hataları' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'sinan.kurt@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Otomatik Ödeme Programı (F110) Banka Dosyası Üretemiyor',
        'İstanbul genel müdürlük otomatik ödeme çalıştırmasında ''DME formatı eksik'' hatası ile banka havale dosyası oluşturulamıyor.', 'SAP-FI', 'İstanbul', 'in_progress',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'sinan.kurt@sirket.com', 'customer', 'İstanbul genel müdürlük otomatik ödeme çalıştırmasında ''DME formatı eksik'' hatası ile banka havale dosyası oluşturulamıyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-FI', 'oncelik', 'urgent', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-FI', 'İstanbul genel müdürlük otomatik ödeme çalıştırmasında ''DME formatı eksik'' hatası ile banka havale dosyası oluşturulamıyor.', 'OBPM4 üzerinden ilgili ödeme yöntemi için DME ağacı (DMEE) formatı yeniden atanarak havale dosyası üretildi.', true);

    ---------------------------------------------------------------------------
    -- [43/120] Ankara Şubesi Kasa Defteri (S_ALR_87012277) Tutarsızlığı
    INSERT INTO users (email, full_name, role, region)
    VALUES ('pelin.ozcan@sirket.com', 'Pelin Ozcan', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'ogulcan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Veri Düzeltme' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'pelin.ozcan@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Ankara Şubesi Kasa Defteri (S_ALR_87012277) Tutarsızlığı',
        'Ankara şubesinin kasa hesabında (1001) gün sonu bakiyesi banka ekstresiyle tutmuyor, 3 adet kayıp fiş tespit edildi.', 'SAP-FI', 'Ankara', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'pelin.ozcan@sirket.com', 'customer', 'Ankara şubesinin kasa hesabında (1001) gün sonu bakiyesi banka ekstresiyle tutmuyor, 3 adet kayıp fiş tespit edildi.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-FI', 'oncelik', 'medium', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-FI', 'Ankara şubesinin kasa hesabında (1001) gün sonu bakiyesi banka ekstresiyle tutmuyor, 3 adet kayıp fiş tespit edildi.', 'FB03 ile eksik fiş numaraları bulunarak iptal edilen 3 belge FBR2 referansıyla yeniden girildi.', true);

    ---------------------------------------------------------------------------
    -- [44/120] Konsolidasyon Şirket Kodu Arası İç Eliminasyon Hatası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('murat.gunes@sirket.com', 'Murat Gunes', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'ogulcan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Geliştirme / Uyarlama Hatası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'murat.gunes@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Konsolidasyon Şirket Kodu Arası İç Eliminasyon Hatası',
        'Yozgat üretim tesisi ile İstanbul merkez arasındaki grup içi satışlarda konsolidasyon eliminasyonu yapılırken karşı hesap eşleşmemektedir.', 'SAP-FI', 'Yozgat', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'murat.gunes@sirket.com', 'customer', 'Yozgat üretim tesisi ile İstanbul merkez arasındaki grup içi satışlarda konsolidasyon eliminasyonu yapılırken karşı hesap eşleşmemektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-FI', 'oncelik', 'medium', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-FI', 'Yozgat üretim tesisi ile İstanbul merkez arasındaki grup içi satışlarda konsolidasyon eliminasyonu yapılırken karşı hesap eşleşmemektedir.', 'İç ticaret ortağı (Trading Partner) alanı eksik belgeler tespit edilerek düzeltildi ve eliminasyon tekrar çalıştırıldı.', true);

    ---------------------------------------------------------------------------
    -- [45/120] Duran Varlık Devir İşlemi (ABUMN) Onay Akışı Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('gokhan.yildirim@sirket.com', 'Gokhan Yildirim', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'ogulcan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Geliştirme / Ekip Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'low' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'gokhan.yildirim@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Duran Varlık Devir İşlemi (ABUMN) Onay Akışı Talebi',
        'İstanbul ofisten Ankara ofise aktarılacak demirbaşlar için ABUMN transferinde yönetici onay mekanizmasının devreye alınması talep edilmektedir.', 'SAP-FI', 'İstanbul', 'assigned',
        'low', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'gokhan.yildirim@sirket.com', 'customer', 'İstanbul ofisten Ankara ofise aktarılacak demirbaşlar için ABUMN transferinde yönetici onay mekanizmasının devreye alınması talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-FI', 'oncelik', 'low', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-FI', 'İstanbul ofisten Ankara ofise aktarılacak demirbaşlar için ABUMN transferinde yönetici onay mekanizmasının devreye alınması talep edilmektedir.', 'Workflow Builder''da duran varlık transfer belgesi tipi için onay iş akışı tanımlanarak aktif edildi.', true);

    ---------------------------------------------------------------------------
    -- [46/120] MIRO Fatura Doğrulamasında Fiyat Farkı Tolerans Hatası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('tayfun.bilgin@sirket.com', 'Tayfun Bilgin', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'sena.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Fiyatlama / Muhasebe / Vergi / Rapor Uyuşmazlığı' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'tayfun.bilgin@sirket.com', v_user_id, 'sapdestek@sirket.com', 'MIRO Fatura Doğrulamasında Fiyat Farkı Tolerans Hatası',
        'Ankara tedarikçisinden gelen faturayı MIRO ile girerken sipariş fiyatı ile fatura fiyatı arasındaki %2''lik fark toleransı aşıyor ve kayıt engelliyor.', 'SAP-MM', 'Ankara', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'tayfun.bilgin@sirket.com', 'customer', 'Ankara tedarikçisinden gelen faturayı MIRO ile girerken sipariş fiyatı ile fatura fiyatı arasındaki %2''lik fark toleransı aşıyor ve kayıt engelliyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-MM', 'oncelik', 'high', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-MM', 'Ankara tedarikçisinden gelen faturayı MIRO ile girerken sipariş fiyatı ile fatura fiyatı arasındaki %2''lik fark toleransı aşıyor ve kayıt engelliyor.', 'OMR6 tolerans grubunda fiyat farkı eşiği kontrol edildi, satınalma müdürü onayıyla fark muhasebeleştirildi.', true);

    ---------------------------------------------------------------------------
    -- [47/120] MB52 Depo Stok Raporunda Negatif Bakiye Görünümü
    INSERT INTO users (email, full_name, role, region)
    VALUES ('aylin.toprak@sirket.com', 'Aylin Toprak', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'omer.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Veri Düzeltme' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'aylin.toprak@sirket.com', v_user_id, 'sapdestek@sirket.com', 'MB52 Depo Stok Raporunda Negatif Bakiye Görünümü',
        'İstanbul ana deposunda MB52 raporunda 3 malzemede negatif stok bakiyesi görünmektedir, fiziksel stok mevcut olmasına rağmen.', 'SAP-MM', 'İstanbul', 'in_progress',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'aylin.toprak@sirket.com', 'customer', 'İstanbul ana deposunda MB52 raporunda 3 malzemede negatif stok bakiyesi görünmektedir, fiziksel stok mevcut olmasına rağmen.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-MM', 'oncelik', 'urgent', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-MM', 'İstanbul ana deposunda MB52 raporunda 3 malzemede negatif stok bakiyesi görünmektedir, fiziksel stok mevcut olmasına rağmen.', 'COGI üzerindeki askıda kalan üretim teyitleri temizlendi ve MB1A/MB1C düzeltme hareketleriyle stok bakiyeleri eşitlendi.', true);

    ---------------------------------------------------------------------------
    -- [48/120] Sakarya Deposunda Raf Yeri (Storage Bin) Tanımlama Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('sevgi.can@sirket.com', 'Sevgi Can', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'omer.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Şirket / Şube / Tesis Tanımı' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'sevgi.can@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Sakarya Deposunda Raf Yeri (Storage Bin) Tanımlama Talebi',
        'Sakarya deposunda yeni kurulan C bloğundaki 40 adet yeni raf konumunun SAP depo yönetimine (WM/EWM) tanımlanması gerekmektedir.', 'SAP-MM', 'Sakarya', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'sevgi.can@sirket.com', 'customer', 'Sakarya deposunda yeni kurulan C bloğundaki 40 adet yeni raf konumunun SAP depo yönetimine (WM/EWM) tanımlanması gerekmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-MM', 'oncelik', 'medium', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-MM', 'Sakarya deposunda yeni kurulan C bloğundaki 40 adet yeni raf konumunun SAP depo yönetimine (WM/EWM) tanımlanması gerekmektedir.', 'LS01N üzerinden C-01-01 ile C-04-10 arası 40 raf yeri tanımlanarak depo yapısı güncellendi.', true);

    ---------------------------------------------------------------------------
    -- [49/120] ME2M Satınalma Raporu Yetki Filtreleme Sorunu
    INSERT INTO users (email, full_name, role, region)
    VALUES ('nermin.aslan@sirket.com', 'Nermin Aslan', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'sena.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yetki Hatası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'nermin.aslan@sirket.com', v_user_id, 'sapdestek@sirket.com', 'ME2M Satınalma Raporu Yetki Filtreleme Sorunu',
        'Yozgat satınalma sorumlusu ME2M raporunda sadece kendi siparişlerini görmesi gerekirken tüm fabrika siparişlerini görebiliyor.', 'SAP-MM', 'Yozgat', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'nermin.aslan@sirket.com', 'customer', 'Yozgat satınalma sorumlusu ME2M raporunda sadece kendi siparişlerini görmesi gerekirken tüm fabrika siparişlerini görebiliyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-MM', 'oncelik', 'high', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-MM', 'Yozgat satınalma sorumlusu ME2M raporunda sadece kendi siparişlerini görmesi gerekirken tüm fabrika siparişlerini görebiliyor.', 'M_BEST_EKG ve M_BEST_WRK yetki nesnelerinde satınalma grubu ve tesis kısıtlaması eklenerek rapor erişimi daraltıldı.', true);

    ---------------------------------------------------------------------------
    -- [50/120] Konsinyasyon Stok Girişi (MB1C 501) Hesap Tayini Eksikliği
    INSERT INTO users (email, full_name, role, region)
    VALUES ('sabri.guler@sirket.com', 'Sabri Guler', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'omer.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Entegrasyon Hataları' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'sabri.guler@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Konsinyasyon Stok Girişi (MB1C 501) Hesap Tayini Eksikliği',
        'İstanbul deposuna gelen konsinyasyon malzeme için MB1C 501 hareketi yapılırken ''Değerleme sınıfı için hesap tayini bulunamadı'' hatası alınmaktadır.', 'SAP-MM', 'İstanbul', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'sabri.guler@sirket.com', 'customer', 'İstanbul deposuna gelen konsinyasyon malzeme için MB1C 501 hareketi yapılırken ''Değerleme sınıfı için hesap tayini bulunamadı'' hatası alınmaktadır.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-MM', 'oncelik', 'high', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-MM', 'İstanbul deposuna gelen konsinyasyon malzeme için MB1C 501 hareketi yapılırken ''Değerleme sınıfı için hesap tayini bulunamadı'' hatası alınmaktadır.', 'OBYC üzerinden konsinyasyon stok değerleme sınıfına ait hesap tayini tanımlanarak hareket tamamlandı.', true);

    ---------------------------------------------------------------------------
    -- [51/120] VA01 Sipariş Girişinde Fiyat Koşulu Çekilmiyor
    INSERT INTO users (email, full_name, role, region)
    VALUES ('engin.tekin@sirket.com', 'Engin Tekin', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'gizem.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Fiyatlama / Muhasebe / Vergi / Rapor Uyuşmazlığı' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'engin.tekin@sirket.com', v_user_id, 'sapdestek@sirket.com', 'VA01 Sipariş Girişinde Fiyat Koşulu Çekilmiyor',
        'Ankara satış ofisinden girilen yeni siparişlerde PR00 temel fiyat koşulu otomatik gelmemekte, sıfır tutar ile kaydedilmektedir.', 'SAP-SD', 'Ankara', 'assigned',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'engin.tekin@sirket.com', 'customer', 'Ankara satış ofisinden girilen yeni siparişlerde PR00 temel fiyat koşulu otomatik gelmemekte, sıfır tutar ile kaydedilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-SD', 'oncelik', 'urgent', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-SD', 'Ankara satış ofisinden girilen yeni siparişlerde PR00 temel fiyat koşulu otomatik gelmemekte, sıfır tutar ile kaydedilmektedir.', 'VK13 ile kontrol edildiğinde ilgili müşteri/malzeme kombinasyonu için fiyat kaydının süresi dolmuştu, VK11 ile yeni tarih aralığı girildi.', true);

    ---------------------------------------------------------------------------
    -- [52/120] VL01N Teslimat Oluşturmada Depo Yeri Belirleme Hatası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('canan.ozer@sirket.com', 'Canan Ozer', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'sena.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Geliştirme / Uyarlama Hatası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'canan.ozer@sirket.com', v_user_id, 'sapdestek@sirket.com', 'VL01N Teslimat Oluşturmada Depo Yeri Belirleme Hatası',
        'Yozgat deposundan sevkiyat yapılacak teslimat belgesi oluşturulurken ''Sevkiyat noktası belirlenemedi'' hatası verilmektedir.', 'SAP-SD', 'Yozgat', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'canan.ozer@sirket.com', 'customer', 'Yozgat deposundan sevkiyat yapılacak teslimat belgesi oluşturulurken ''Sevkiyat noktası belirlenemedi'' hatası verilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-SD', 'oncelik', 'high', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-SD', 'Yozgat deposundan sevkiyat yapılacak teslimat belgesi oluşturulurken ''Sevkiyat noktası belirlenemedi'' hatası verilmektedir.', 'OVL2 konfigürasyonunda Yozgat tesisi için sevkiyat noktası ve yükleme grubu eşleşmesi kontrol edilerek eksik kayıt tamamlandı.', true);

    ---------------------------------------------------------------------------
    -- [53/120] E-Fatura GİB Schematron Doğrulaması Başarısız Oluyor
    INSERT INTO users (email, full_name, role, region)
    VALUES ('hasan.tatar@sirket.com', 'Hasan Tatar', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'gizem.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'E-Dönüşüm Hataları (E-Fatura, E-İrsaliye vb.)' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'hasan.tatar@sirket.com', v_user_id, 'sapdestek@sirket.com', 'E-Fatura GİB Schematron Doğrulaması Başarısız Oluyor',
        'İstanbul merkezden kesilen toplu satış faturalarında entegratöre gönderim sırasında ''Ödeme vadesi zorunlu alan eksik'' Schematron hatası çıkmaktadır.', 'SAP-SD', 'İstanbul', 'in_progress',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'hasan.tatar@sirket.com', 'customer', 'İstanbul merkezden kesilen toplu satış faturalarında entegratöre gönderim sırasında ''Ödeme vadesi zorunlu alan eksik'' Schematron hatası çıkmaktadır.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-SD', 'oncelik', 'urgent', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-SD', 'İstanbul merkezden kesilen toplu satış faturalarında entegratöre gönderim sırasında ''Ödeme vadesi zorunlu alan eksik'' Schematron hatası çıkmaktadır.', 'Fatura tipine bağlı ödeme koşulu alanı müşteri ana verisinden otomatik çekilecek şekilde düzeltildi ve kuyruk yeniden tetiklendi.', true);

    ---------------------------------------------------------------------------
    -- [54/120] Sakarya Bayisi İçin Özel İndirim Koşulu Tanımlama
    INSERT INTO users (email, full_name, role, region)
    VALUES ('orhan.kaya@sirket.com', 'Orhan Kaya', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'sena.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Geliştirme / Ekip Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'orhan.kaya@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Sakarya Bayisi İçin Özel İndirim Koşulu Tanımlama',
        'Sakarya bölgesinde yıllık ciro taahhüdünü karşılayan bayimize %5 ek iskonto koşulunun tanımlanması ve geçmiş 2 aylık faturalara geriye dönük uygulanması talep edilmektedir.', 'SAP-SD', 'Sakarya', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'orhan.kaya@sirket.com', 'customer', 'Sakarya bölgesinde yıllık ciro taahhüdünü karşılayan bayimize %5 ek iskonto koşulunun tanımlanması ve geçmiş 2 aylık faturalara geriye dönük uygulanması talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-SD', 'oncelik', 'medium', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-SD', 'Sakarya bölgesinde yıllık ciro taahhüdünü karşılayan bayimize %5 ek iskonto koşulunun tanımlanması ve geçmiş 2 aylık faturalara geriye dönük uygulanması talep edilmektedir.', 'VBO1 ile geriye dönük iade/iskonto belgesi oluşturuldu ve VK11 üzerinden bayi özel ZDIS koşulu tanımlandı.', true);

    ---------------------------------------------------------------------------
    -- [55/120] VA05 Sipariş Listesi Raporunda TIME_OUT Dump Hatası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('ihsan.demir@sirket.com', 'Ihsan Demir', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'gizem.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Performans / Zaman Aşımı' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'ihsan.demir@sirket.com', v_user_id, 'sapdestek@sirket.com', 'VA05 Sipariş Listesi Raporunda TIME_OUT Dump Hatası',
        'Ankara satış ekibi son 6 aylık sipariş listesini VA05 raporuyla çekmeye çalıştığında 10 dakika sonra ''TIME_OUT'' dump vererek kapanıyor.', 'SAP-SD', 'Ankara', 'resolved',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'ihsan.demir@sirket.com', 'customer', 'Ankara satış ekibi son 6 aylık sipariş listesini VA05 raporuyla çekmeye çalıştığında 10 dakika sonra ''TIME_OUT'' dump vererek kapanıyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-SD', 'oncelik', 'medium', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-SD', 'Ankara satış ekibi son 6 aylık sipariş listesini VA05 raporuyla çekmeye çalıştığında 10 dakika sonra ''TIME_OUT'' dump vererek kapanıyor.', 'Rapor parametrelerine tarih ve satış organizasyonu filtreleri eklenerek veri seti daraltıldı, runtime parametresi de 1800 saniyeye çıkarıldı.', true);

    ---------------------------------------------------------------------------
    -- [56/120] SM37 Arka Plan İşi (Job) Zamanlayıcı Hatası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('selami.ustun@sirket.com', 'Selami Ustun', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Server / Sanallaştırma Arızası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'selami.ustun@sirket.com', v_user_id, 'sapdestek@sirket.com', 'SM37 Arka Plan İşi (Job) Zamanlayıcı Hatası',
        'Sakarya fabrikasının gece 02:00''de çalışması gereken MRP çalıştırma job''ı 3 gündür ''Cancelled'' durumuna düşüyor.', 'SAP-Basis', 'Sakarya', 'assigned',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'selami.ustun@sirket.com', 'customer', 'Sakarya fabrikasının gece 02:00''de çalışması gereken MRP çalıştırma job''ı 3 gündür ''Cancelled'' durumuna düşüyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Basis', 'oncelik', 'urgent', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Basis', 'Sakarya fabrikasının gece 02:00''de çalışması gereken MRP çalıştırma job''ı 3 gündür ''Cancelled'' durumuna düşüyor.', 'SM37 loglarında batch iş sürecinin bellek aşımı (ABAP memory) ile düştüğü tespit edildi, RZ11 parametresi artırılarak job yeniden planlandı.', true);

    ---------------------------------------------------------------------------
    -- [57/120] SAP Sistem Performansı Kritik Yavaşlık (ST03N)
    INSERT INTO users (email, full_name, role, region)
    VALUES ('fatma.teyze@sirket.com', 'Fatma Teyze', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'mustafa.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Performans / Zaman Aşımı' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'fatma.teyze@sirket.com', v_user_id, 'sapdestek@sirket.com', 'SAP Sistem Performansı Kritik Yavaşlık (ST03N)',
        'İstanbul genel merkezde öğleden sonra tüm işlem kodlarında 15-20 saniyelik yanıt süreleri yaşanmaktadır, kullanıcılar çalışamıyor.', 'SAP-Basis', 'İstanbul', 'in_progress',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'fatma.teyze@sirket.com', 'customer', 'İstanbul genel merkezde öğleden sonra tüm işlem kodlarında 15-20 saniyelik yanıt süreleri yaşanmaktadır, kullanıcılar çalışamıyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Basis', 'oncelik', 'urgent', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Basis', 'İstanbul genel merkezde öğleden sonra tüm işlem kodlarında 15-20 saniyelik yanıt süreleri yaşanmaktadır, kullanıcılar çalışamıyor.', 'ST03N ve SM66 analiziyle yoğun SQL sorgusu çalıştıran bir Z-rapor tespit edildi, rapor durdurularak ve DB indexleri optimize edilerek performans normale döndü.', true);

    ---------------------------------------------------------------------------
    -- [58/120] Ankara Ofisi İçin Yeni SAP Kullanıcı Lisansı Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('remzi.usta@sirket.com', 'Remzi Usta', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Yetki / Rol Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'remzi.usta@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Ankara Ofisi İçin Yeni SAP Kullanıcı Lisansı Talebi',
        'Ankara finans birimine katılan 3 yeni personel için SAP Professional kullanıcı lisansı açılması ve lisans havuzu kontrolünün yapılması talep edilmektedir.', 'SAP-Basis', 'Ankara', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'remzi.usta@sirket.com', 'customer', 'Ankara finans birimine katılan 3 yeni personel için SAP Professional kullanıcı lisansı açılması ve lisans havuzu kontrolünün yapılması talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Basis', 'oncelik', 'medium', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Basis', 'Ankara finans birimine katılan 3 yeni personel için SAP Professional kullanıcı lisansı açılması ve lisans havuzu kontrolünün yapılması talep edilmektedir.', 'USMM üzerinden mevcut lisans kullanımı kontrol edildi, yeterli kontenjandan 3 Professional lisans atanarak SU01 ile kullanıcılar açıldı.', true);

    ---------------------------------------------------------------------------
    -- [59/120] RFC Bağlantısı (SM59) Zaman Aşımına Uğruyor
    INSERT INTO users (email, full_name, role, region)
    VALUES ('hakan.tunc@sirket.com', 'Hakan Tunc', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'mustafa.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Entegrasyon Hataları' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'hakan.tunc@sirket.com', v_user_id, 'sapdestek@sirket.com', 'RFC Bağlantısı (SM59) Zaman Aşımına Uğruyor',
        'Yozgat üretim sisteminden İstanbul merkez BI sunucusuna veri aktarımı yapan RFC bağlantısı son 2 gündür timeout vermektedir.', 'SAP-Basis', 'Yozgat', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'hakan.tunc@sirket.com', 'customer', 'Yozgat üretim sisteminden İstanbul merkez BI sunucusuna veri aktarımı yapan RFC bağlantısı son 2 gündür timeout vermektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Basis', 'oncelik', 'high', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Basis', 'Yozgat üretim sisteminden İstanbul merkez BI sunucusuna veri aktarımı yapan RFC bağlantısı son 2 gündür timeout vermektedir.', 'SM59 RFC bağlantısındaki gateway host IP adresi güncel sunucu migrasyonuna göre düzeltildi ve timeout süresi 300 saniyeye çıkarıldı.', true);

    ---------------------------------------------------------------------------
    -- [60/120] STMS Transport Rotası Yanlış Sisteme Aktarım Yapıyor
    INSERT INTO users (email, full_name, role, region)
    VALUES ('ayten.guzel@sirket.com', 'Ayten Guzel', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Geliştirme / Uyarlama Hatası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'ayten.guzel@sirket.com', v_user_id, 'sapdestek@sirket.com', 'STMS Transport Rotası Yanlış Sisteme Aktarım Yapıyor',
        'İstanbul geliştirme ekibinin DEV ortamından gönderdiği transport paketi QAS yerine yanlışlıkla doğrudan PRD''ye düşüyor.', 'SAP-Basis', 'İstanbul', 'resolved',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'ayten.guzel@sirket.com', 'customer', 'İstanbul geliştirme ekibinin DEV ortamından gönderdiği transport paketi QAS yerine yanlışlıkla doğrudan PRD''ye düşüyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Basis', 'oncelik', 'high', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Basis', 'İstanbul geliştirme ekibinin DEV ortamından gönderdiği transport paketi QAS yerine yanlışlıkla doğrudan PRD''ye düşüyor.', 'STMS transport rotası incelendiğinde DEV→PRD kısa yol tanımı bulundu, silinerek DEV→QAS→PRD doğru akış yeniden kuruldu.', true);

    ---------------------------------------------------------------------------
    -- [61/120] FB03 Belge Görüntüleme Yetkisi Kısıtlanmış
    INSERT INTO users (email, full_name, role, region)
    VALUES ('ali.dogan@sirket.com', 'Ali Dogan', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yetki Hatası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'ali.dogan@sirket.com', v_user_id, 'sapdestek@sirket.com', 'FB03 Belge Görüntüleme Yetkisi Kısıtlanmış',
        'İstanbul iç denetim ekibi tüm şirket kodlarındaki muhasebe belgelerini FB03 ile görüntülemeye çalışıyor ancak sadece 1000 kodunu görebiliyor.', 'SAP-Yetki', 'İstanbul', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'ali.dogan@sirket.com', 'customer', 'İstanbul iç denetim ekibi tüm şirket kodlarındaki muhasebe belgelerini FB03 ile görüntülemeye çalışıyor ancak sadece 1000 kodunu görebiliyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Yetki', 'oncelik', 'high', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Yetki', 'İstanbul iç denetim ekibi tüm şirket kodlarındaki muhasebe belgelerini FB03 ile görüntülemeye çalışıyor ancak sadece 1000 kodunu görebiliyor.', 'F_BKPF_BUK yetki nesnesindeki şirket kodu değerleri ''*'' olarak genişletilerek tüm kodlara okuma yetkisi verildi.', true);

    ---------------------------------------------------------------------------
    -- [62/120] Toplu Kullanıcı Rol Ataması - Yozgat Üretim Personeli
    INSERT INTO users (email, full_name, role, region)
    VALUES ('pelin.kaya@sirket.com', 'Pelin Kaya', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Yetki / Rol Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'PP' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'pelin.kaya@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Toplu Kullanıcı Rol Ataması - Yozgat Üretim Personeli',
        'Yozgat fabrikasına aynı anda başlayan 8 üretim operatörü için standart Z_PP_OPERATOR rolünün toplu olarak atanması talep edilmektedir.', 'SAP-Yetki', 'Yozgat', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'pelin.kaya@sirket.com', 'customer', 'Yozgat fabrikasına aynı anda başlayan 8 üretim operatörü için standart Z_PP_OPERATOR rolünün toplu olarak atanması talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Yetki', 'oncelik', 'medium', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Yetki', 'Yozgat fabrikasına aynı anda başlayan 8 üretim operatörü için standart Z_PP_OPERATOR rolünün toplu olarak atanması talep edilmektedir.', 'SU10 toplu kullanıcı bakımı ile 8 kullanıcıya Z_PP_OPERATOR rolü ve Yozgat tesis yetkisi eş zamanlı atandı.', true);

    ---------------------------------------------------------------------------
    -- [63/120] PFCG Rol Karşılaştırma ve Eski Rollerin Temizlenmesi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('deniz.aksoy@sirket.com', 'Deniz Aksoy', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Geliştirme / Ekip Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'low' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'deniz.aksoy@sirket.com', v_user_id, 'sapdestek@sirket.com', 'PFCG Rol Karşılaştırma ve Eski Rollerin Temizlenmesi',
        'Ankara ofisindeki yeniden yapılanma sonrası kullanılmayan 12 eski rolün PFCG''den temizlenmesi ve aktif rollerin denetim raporu çıkarılması talep edilmektedir.', 'SAP-Yetki', 'Ankara', 'assigned',
        'low', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'deniz.aksoy@sirket.com', 'customer', 'Ankara ofisindeki yeniden yapılanma sonrası kullanılmayan 12 eski rolün PFCG''den temizlenmesi ve aktif rollerin denetim raporu çıkarılması talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Yetki', 'oncelik', 'low', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Yetki', 'Ankara ofisindeki yeniden yapılanma sonrası kullanılmayan 12 eski rolün PFCG''den temizlenmesi ve aktif rollerin denetim raporu çıkarılması talep edilmektedir.', 'SUIM raporuyla kullanıcısız kalan 12 rol tespit edildi, PFCG''den silinerek AGR_1251/AGR_USERS tabloları temizlendi.', true);

    ---------------------------------------------------------------------------
    -- [64/120] Sakarya Depo Amiri İçin Transfer Emri Oluşturma Yetkisi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('aylin.sen@sirket.com', 'Aylin Sen', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yetki Hatası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'aylin.sen@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Sakarya Depo Amiri İçin Transfer Emri Oluşturma Yetkisi',
        'Sakarya depo vardiya amiri LT01 ile transfer emri oluşturmaya çalışıyor ancak ''L_TCODE yetkisi eksik'' hatası alıyor.', 'SAP-Yetki', 'Sakarya', 'resolved',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'aylin.sen@sirket.com', 'customer', 'Sakarya depo vardiya amiri LT01 ile transfer emri oluşturmaya çalışıyor ancak ''L_TCODE yetkisi eksik'' hatası alıyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Yetki', 'oncelik', 'high', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Yetki', 'Sakarya depo vardiya amiri LT01 ile transfer emri oluşturmaya çalışıyor ancak ''L_TCODE yetkisi eksik'' hatası alıyor.', 'Z_WM_DEPO rolüne LT01, LT02, LT03 işlem kodları ve L_TCODE yetki nesnesi eklenerek kullanıcıya atandı.', true);

    ---------------------------------------------------------------------------
    -- [65/120] Dış Denetçi İçin Geçici Salt-Okunur SAP Erişimi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('tarik.yildiz@sirket.com', 'Tarik Yildiz', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Yetki / Rol Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'tarik.yildiz@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Dış Denetçi İçin Geçici Salt-Okunur SAP Erişimi',
        'İstanbul ofise gelen bağımsız dış denetçiler için 2 haftalık salt-okunur (görüntüleme) SAP erişimi açılması gerekmektedir.', 'SAP-Yetki', 'İstanbul', 'resolved',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'tarik.yildiz@sirket.com', 'customer', 'İstanbul ofise gelen bağımsız dış denetçiler için 2 haftalık salt-okunur (görüntüleme) SAP erişimi açılması gerekmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Yetki', 'oncelik', 'medium', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Yetki', 'İstanbul ofise gelen bağımsız dış denetçiler için 2 haftalık salt-okunur (görüntüleme) SAP erişimi açılması gerekmektedir.', 'Z_AUDIT_READONLY rolü ile geçici kullanıcı açıldı, SU01 geçerlilik bitiş tarihi 2 hafta sonrasına ayarlandı.', true);

    ---------------------------------------------------------------------------
    -- [66/120] Ankara Ofisi DNS Çözümleme Arızası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('burak.kaya@sirket.com', 'Burak Kaya', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Erişim Engeli' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'burak.kaya@sirket.com', v_user_id, 'btdestek@sirket.com', 'Ankara Ofisi DNS Çözümleme Arızası',
        'Ankara ofisindeki bilgisayarlar kurumsal DNS sunucusuna ulaşamıyor, iç portal ve SAP Fiori adresleri açılmıyor.', 'IT-Ag', 'Ankara', 'assigned',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'burak.kaya@sirket.com', 'customer', 'Ankara ofisindeki bilgisayarlar kurumsal DNS sunucusuna ulaşamıyor, iç portal ve SAP Fiori adresleri açılmıyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Ag', 'oncelik', 'urgent', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Ag', 'Ankara ofisindeki bilgisayarlar kurumsal DNS sunucusuna ulaşamıyor, iç portal ve SAP Fiori adresleri açılmıyor.', 'Ankara ofisindeki yerel DNS forwarder servisinin çöktüğü tespit edildi, servis yeniden başlatılarak ve yedek DNS eklenerek erişim sağlandı.', true);

    ---------------------------------------------------------------------------
    -- [67/120] İstanbul Lojistik Katı Switch Port Arızası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('merve.celik@sirket.com', 'Merve Celik', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'İnternet Kesintisi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'merve.celik@sirket.com', v_user_id, 'btdestek@sirket.com', 'İstanbul Lojistik Katı Switch Port Arızası',
        'İstanbul B Blok lojistik katında 15 kişilik açık ofis alanında tüm kablolu ağ bağlantıları aynı anda koptu.', 'IT-Ag', 'İstanbul', 'in_progress',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'merve.celik@sirket.com', 'customer', 'İstanbul B Blok lojistik katında 15 kişilik açık ofis alanında tüm kablolu ağ bağlantıları aynı anda koptu.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Ag', 'oncelik', 'urgent', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Ag', 'İstanbul B Blok lojistik katında 15 kişilik açık ofis alanında tüm kablolu ağ bağlantıları aynı anda koptu.', 'Kat switch cihazı (HP 2530) üzerinde POE modülü arıza verdiği tespit edildi, yedek switch ile değiştirildi.', true);

    ---------------------------------------------------------------------------
    -- [68/120] Yozgat Fabrika Site-to-Site VPN Tünel Konfigürasyonu
    INSERT INTO users (email, full_name, role, region)
    VALUES ('oguz.cetin@sirket.com', 'Oguz Cetin', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'VPN Bağlantı Sorunları' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'oguz.cetin@sirket.com', v_user_id, 'btdestek@sirket.com', 'Yozgat Fabrika Site-to-Site VPN Tünel Konfigürasyonu',
        'Yozgat fabrikası ile İstanbul merkez arasında yeni kurulan yedek IPsec VPN tünelinin konfigüre edilmesi ve failover testinin yapılması talep edilmektedir.', 'IT-Ag', 'Yozgat', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'oguz.cetin@sirket.com', 'customer', 'Yozgat fabrikası ile İstanbul merkez arasında yeni kurulan yedek IPsec VPN tünelinin konfigüre edilmesi ve failover testinin yapılması talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Ag', 'oncelik', 'medium', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Ag', 'Yozgat fabrikası ile İstanbul merkez arasında yeni kurulan yedek IPsec VPN tünelinin konfigüre edilmesi ve failover testinin yapılması talep edilmektedir.', 'FortiGate üzerinde Phase1/Phase2 IPsec tünel parametreleri tanımlandı ve SD-WAN failover testi başarıyla geçildi.', true);

    ---------------------------------------------------------------------------
    -- [69/120] Sakarya Üretim Hattı VLAN Segmentasyon Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('can.turan@sirket.com', 'Can Turan', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Firma Dışı Erişim / Port Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'can.turan@sirket.com', v_user_id, 'btdestek@sirket.com', 'Sakarya Üretim Hattı VLAN Segmentasyon Talebi',
        'Sakarya üretim hattındaki PLC ve SCADA cihazlarının ofis ağından ayrılması için ayrı bir VLAN segmentasyonu yapılması talep edilmektedir.', 'IT-Ag', 'Sakarya', 'resolved',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'can.turan@sirket.com', 'customer', 'Sakarya üretim hattındaki PLC ve SCADA cihazlarının ofis ağından ayrılması için ayrı bir VLAN segmentasyonu yapılması talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Ag', 'oncelik', 'medium', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Ag', 'Sakarya üretim hattındaki PLC ve SCADA cihazlarının ofis ağından ayrılması için ayrı bir VLAN segmentasyonu yapılması talep edilmektedir.', 'VLAN 50 (OT_Network) oluşturuldu, switch portları ilgili VLAN''a atandı ve inter-VLAN routing ACL kuralları ile kısıtlandı.', true);

    ---------------------------------------------------------------------------
    -- [70/120] İstanbul Ofis Genel İnternet Hızı Düşük
    INSERT INTO users (email, full_name, role, region)
    VALUES ('selin.yurt@sirket.com', 'Selin Yurt', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Erişim Yavaşlığı' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'selin.yurt@sirket.com', v_user_id, 'btdestek@sirket.com', 'İstanbul Ofis Genel İnternet Hızı Düşük',
        'İstanbul genel merkezde son 3 gündür internet hızı normal seviyenin yarısına düşmüş, dosya indirme ve bulut uygulamalar çok yavaş açılıyor.', 'IT-Ag', 'İstanbul', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'selin.yurt@sirket.com', 'customer', 'İstanbul genel merkezde son 3 gündür internet hızı normal seviyenin yarısına düşmüş, dosya indirme ve bulut uygulamalar çok yavaş açılıyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Ag', 'oncelik', 'high', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Ag', 'İstanbul genel merkezde son 3 gündür internet hızı normal seviyenin yarısına düşmüş, dosya indirme ve bulut uygulamalar çok yavaş açılıyor.', 'Firewall trafik analiziyle bir kullanıcının büyük boyutlu dosya senkronizasyonu yaptığı tespit edildi, QoS band limiti uygulandı.', true);

    ---------------------------------------------------------------------------
    -- [71/120] Yozgat Fabrika Kat Yazıcısı Toner Sıkışması ve Çizgili Baskı
    INSERT INTO users (email, full_name, role, region)
    VALUES ('kemal.arslan@sirket.com', 'Kemal Arslan', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'salih.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yazıcı Arızası' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'kemal.arslan@sirket.com', v_user_id, 'btdestek@sirket.com', 'Yozgat Fabrika Kat Yazıcısı Toner Sıkışması ve Çizgili Baskı',
        'Yozgat idari katındaki HP LaserJet yazıcı çıktılarda dikey siyah çizgi veriyor ve 10 sayfada bir ''Toner sıkışması'' hatası çıkıyor.', 'IT-Donanim', 'Yozgat', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'kemal.arslan@sirket.com', 'customer', 'Yozgat idari katındaki HP LaserJet yazıcı çıktılarda dikey siyah çizgi veriyor ve 10 sayfada bir ''Toner sıkışması'' hatası çıkıyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Donanim', 'oncelik', 'high', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Donanim', 'Yozgat idari katındaki HP LaserJet yazıcı çıktılarda dikey siyah çizgi veriyor ve 10 sayfada bir ''Toner sıkışması'' hatası çıkıyor.', 'Yozgat destek uzmanı toner kartuşunu çıkarıp drum ünitesini temizledi, çizgi kalkmasına rağmen kartuş ömrü dolduğu için yenisiyle değiştirildi.', true);

    ---------------------------------------------------------------------------
    -- [72/120] Ankara Ofisi Docking Station USB Port Tanımıyor
    INSERT INTO users (email, full_name, role, region)
    VALUES ('mert.aydin@sirket.com', 'Mert Aydin', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'faruk.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Bilgisayar Çevre Birimleri Arızası' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'mert.aydin@sirket.com', v_user_id, 'btdestek@sirket.com', 'Ankara Ofisi Docking Station USB Port Tanımıyor',
        'Ankara operasyon müdürünün Dell WD19S docking station cihazı USB portlarına takılan hiçbir aygıtı algılamıyor.', 'IT-Donanim', 'Ankara', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'mert.aydin@sirket.com', 'customer', 'Ankara operasyon müdürünün Dell WD19S docking station cihazı USB portlarına takılan hiçbir aygıtı algılamıyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Donanim', 'oncelik', 'medium', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Donanim', 'Ankara operasyon müdürünün Dell WD19S docking station cihazı USB portlarına takılan hiçbir aygıtı algılamıyor.', 'Ankara destek uzmanı docking station firmware güncellemesi yaparak ve USB-C kablosunu değiştirerek sorun giderildi.', true);

    ---------------------------------------------------------------------------
    -- [73/120] İstanbul Muhasebe Katı Bilgisayar Rastgele Kapanıyor
    INSERT INTO users (email, full_name, role, region)
    VALUES ('fatma.guler@sirket.com', 'Fatma Guler', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'emirhan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Bilgisayar Arızası' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'fatma.guler@sirket.com', v_user_id, 'btdestek@sirket.com', 'İstanbul Muhasebe Katı Bilgisayar Rastgele Kapanıyor',
        'İstanbul finans katındaki masaüstü bilgisayar günde 2-3 kez ani kapanma yapıyor, mavi ekran (BSOD) veriyor.', 'IT-Donanim', 'İstanbul', 'in_progress',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'fatma.guler@sirket.com', 'customer', 'İstanbul finans katındaki masaüstü bilgisayar günde 2-3 kez ani kapanma yapıyor, mavi ekran (BSOD) veriyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Donanim', 'oncelik', 'high', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Donanim', 'İstanbul finans katındaki masaüstü bilgisayar günde 2-3 kez ani kapanma yapıyor, mavi ekran (BSOD) veriyor.', 'İstanbul destek uzmanı Event Viewer loglarından termal kapanma olduğunu belirledi, işlemci termal macunu yenilenerek fan temizlendi.', true);

    ---------------------------------------------------------------------------
    -- [74/120] Sakarya Toplantı Odası Projeksiyon Cihazı Arızası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('turgay.yilmaz@sirket.com', 'Turgay Yilmaz', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Bilgisayar Çevre Birimleri Arızası' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'turgay.yilmaz@sirket.com', v_user_id, 'btdestek@sirket.com', 'Sakarya Toplantı Odası Projeksiyon Cihazı Arızası',
        'Sakarya fabrika toplantı odasındaki Epson projeksiyon cihazı lamba uyarısı vererek otomatik kapanmaktadır.', 'IT-Donanim', 'Sakarya', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'turgay.yilmaz@sirket.com', 'customer', 'Sakarya fabrika toplantı odasındaki Epson projeksiyon cihazı lamba uyarısı vererek otomatik kapanmaktadır.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Donanim', 'oncelik', 'medium', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Donanim', 'Sakarya fabrika toplantı odasındaki Epson projeksiyon cihazı lamba uyarısı vererek otomatik kapanmaktadır.', 'Sakarya BT sorumlusu projeksiyon cihazının lamba kullanım saatinin ömrünü aştığını tespit etti, yedek lamba ile değiştirildi.', true);

    ---------------------------------------------------------------------------
    -- [75/120] İstanbul Yeni İşe Başlayan Personele Laptop Kurulum Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('nihal.sari@sirket.com', 'Nihal Sari', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yusuf.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Laptop Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'nihal.sari@sirket.com', v_user_id, 'btdestek@sirket.com', 'İstanbul Yeni İşe Başlayan Personele Laptop Kurulum Talebi',
        'İstanbul pazarlama departmanına başlayacak yeni personel için 1 adet dizüstü bilgisayar kurulumu, domain''e ekleme ve standart yazılım yüklemesi talep edilmektedir.', 'IT-Donanim', 'İstanbul', 'resolved',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'nihal.sari@sirket.com', 'customer', 'İstanbul pazarlama departmanına başlayacak yeni personel için 1 adet dizüstü bilgisayar kurulumu, domain''e ekleme ve standart yazılım yüklemesi talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Donanim', 'oncelik', 'medium', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Donanim', 'İstanbul pazarlama departmanına başlayacak yeni personel için 1 adet dizüstü bilgisayar kurulumu, domain''e ekleme ve standart yazılım yüklemesi talep edilmektedir.', 'Envanter stoğundan Dell Latitude 5540 hazırlanarak Windows imajı yüklendi, AD''ye eklendi ve Office + SAP GUI kurularak teslim edildi.', true);

    ---------------------------------------------------------------------------
    -- [76/120] Outlook Profili Bozuldu ve Maillere Erişilemiyor
    INSERT INTO users (email, full_name, role, region)
    VALUES ('mehmet.can@sirket.com', 'Mehmet Can', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'mustafa.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'E-Posta / Dağıtım Grubu Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'mehmet.can@sirket.com', v_user_id, 'btdestek@sirket.com', 'Outlook Profili Bozuldu ve Maillere Erişilemiyor',
        'Sakarya ofisindeki kullanıcının Outlook uygulaması açılırken ''Profil yüklenemiyor'' hatası vererek kapanıyor, web mail üzerinden erişim sağlanabiliyor.', 'IT-Hesap', 'Sakarya', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'mehmet.can@sirket.com', 'customer', 'Sakarya ofisindeki kullanıcının Outlook uygulaması açılırken ''Profil yüklenemiyor'' hatası vererek kapanıyor, web mail üzerinden erişim sağlanabiliyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Hesap', 'oncelik', 'high', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Hesap', 'Sakarya ofisindeki kullanıcının Outlook uygulaması açılırken ''Profil yüklenemiyor'' hatası vererek kapanıyor, web mail üzerinden erişim sağlanabiliyor.', 'Bozuk Outlook profili Denetim Masası''ndan silinerek yeni profil oluşturuldu ve Autodiscover ile hesap yeniden yapılandırıldı.', true);

    ---------------------------------------------------------------------------
    -- [77/120] Departman Değişen Personelin AD Güvenlik Grubu Güncellenmesi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('ik@sirket.com', 'Ik', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Kullanıcı Hesabı Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'ik@sirket.com', v_user_id, 'btdestek@sirket.com', 'Departman Değişen Personelin AD Güvenlik Grubu Güncellenmesi',
        'İstanbul merkezde Satınalma''dan Finans''a geçen 2 personelin eski departman AD gruplarından çıkarılıp yeni departman gruplarına eklenmesi rica olunur.', 'IT-Hesap', 'İstanbul', 'resolved',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'ik@sirket.com', 'customer', 'İstanbul merkezde Satınalma''dan Finans''a geçen 2 personelin eski departman AD gruplarından çıkarılıp yeni departman gruplarına eklenmesi rica olunur.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Hesap', 'oncelik', 'medium', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Hesap', 'İstanbul merkezde Satınalma''dan Finans''a geçen 2 personelin eski departman AD gruplarından çıkarılıp yeni departman gruplarına eklenmesi rica olunur.', 'Active Directory''den eski güvenlik grupları kaldırıldı, yeni Finans OU ve dağıtım gruplarına eklenerek file share yetkileri güncellendi.', true);

    ---------------------------------------------------------------------------
    -- [78/120] Ankara Ofisi Paylaşımlı Posta Kutusuna Erişim Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('elif.sahin@sirket.com', 'Elif Sahin', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'turgut.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'E-Posta / Dağıtım Grubu Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'elif.sahin@sirket.com', v_user_id, 'btdestek@sirket.com', 'Ankara Ofisi Paylaşımlı Posta Kutusuna Erişim Talebi',
        'Ankara müşteri hizmetleri ekibinin ''ankara-musteri@sirket.com'' paylaşımlı posta kutusuna 2 yeni personelin eklenmesi talep edilmektedir.', 'IT-Hesap', 'Ankara', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'elif.sahin@sirket.com', 'customer', 'Ankara müşteri hizmetleri ekibinin ''ankara-musteri@sirket.com'' paylaşımlı posta kutusuna 2 yeni personelin eklenmesi talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Hesap', 'oncelik', 'medium', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Hesap', 'Ankara müşteri hizmetleri ekibinin ''ankara-musteri@sirket.com'' paylaşımlı posta kutusuna 2 yeni personelin eklenmesi talep edilmektedir.', 'Exchange Online yönetim panelinden shared mailbox iznine 2 yeni kullanıcı Send As ve Full Access yetkisiyle eklendi.', true);

    ---------------------------------------------------------------------------
    -- [79/120] Yozgat Fabrika Vardiya Personeli Ortak Hesap Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('selami.ustun@sirket.com', 'Selami Ustun', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'mustafa.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Kullanıcı Hesabı Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'low' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'selami.ustun@sirket.com', v_user_id, 'btdestek@sirket.com', 'Yozgat Fabrika Vardiya Personeli Ortak Hesap Talebi',
        'Yozgat fabrika üretim hattında 3 vardiya arasında kullanılacak ortak bir kiosk Windows hesabı ve sınırlı internet erişimi açılması talep edilmektedir.', 'IT-Hesap', 'Yozgat', 'assigned',
        'low', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'selami.ustun@sirket.com', 'customer', 'Yozgat fabrika üretim hattında 3 vardiya arasında kullanılacak ortak bir kiosk Windows hesabı ve sınırlı internet erişimi açılması talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Hesap', 'oncelik', 'low', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Hesap', 'Yozgat fabrika üretim hattında 3 vardiya arasında kullanılacak ortak bir kiosk Windows hesabı ve sınırlı internet erişimi açılması talep edilmektedir.', 'AD''de kiosk kullanıcısı oluşturuldu, GPO ile kiosk modu kısıtlamaları ve web filtresi uygulanarak teslim edildi.', true);

    ---------------------------------------------------------------------------
    -- [80/120] VPN Uzaktan Erişim Hesabı Açılması Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('buse.kara@sirket.com', 'Buse Kara', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'turgut.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Kullanıcı Hesabı Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'buse.kara@sirket.com', v_user_id, 'btdestek@sirket.com', 'VPN Uzaktan Erişim Hesabı Açılması Talebi',
        'İstanbul merkez ofis çalışanının evden çalışma günlerinde kurumsal ağa bağlanabilmesi için FortiClient VPN hesabı açılması rica olunur.', 'IT-Hesap', 'İstanbul', 'resolved',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'buse.kara@sirket.com', 'customer', 'İstanbul merkez ofis çalışanının evden çalışma günlerinde kurumsal ağa bağlanabilmesi için FortiClient VPN hesabı açılması rica olunur.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Hesap', 'oncelik', 'medium', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Hesap', 'İstanbul merkez ofis çalışanının evden çalışma günlerinde kurumsal ağa bağlanabilmesi için FortiClient VPN hesabı açılması rica olunur.', 'FortiGate VPN Local User olarak tanımlandı, SSL-VPN grubuna eklendi ve kullanıcıya bağlantı profili dosyası gönderildi.', true);

    ---------------------------------------------------------------------------
    -- [81/120] FK10N Satıcı Bakiye Raporunda Şirket Kodu Çapraz Görünüm Eksikliği
    INSERT INTO users (email, full_name, role, region)
    VALUES ('cemre.ozturk@sirket.com', 'Cemre Ozturk', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'ogulcan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Fiyatlama / Muhasebe / Vergi / Rapor Uyuşmazlığı' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'cemre.ozturk@sirket.com', v_user_id, 'sapdestek@sirket.com', 'FK10N Satıcı Bakiye Raporunda Şirket Kodu Çapraz Görünüm Eksikliği',
        'İstanbul merkez muhasebe birimi FK10N ile satıcı bakiyelerini çekerken Yozgat şirket kodundaki bakiyeler rapora dahil edilmemektedir.', 'SAP-FI', 'İstanbul', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'cemre.ozturk@sirket.com', 'customer', 'İstanbul merkez muhasebe birimi FK10N ile satıcı bakiyelerini çekerken Yozgat şirket kodundaki bakiyeler rapora dahil edilmemektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-FI', 'oncelik', 'medium', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-FI', 'İstanbul merkez muhasebe birimi FK10N ile satıcı bakiyelerini çekerken Yozgat şirket kodundaki bakiyeler rapora dahil edilmemektedir.', 'FK10N rapor varyantında şirket kodu seçim parametresi tek kodla sınırlanmıştı, tüm kodlar eklenerek varyant güncellendi.', true);

    ---------------------------------------------------------------------------
    -- [82/120] Sakarya Şubesi Yıl Sonu Kapanış (FAGLB03) Bakiye Aktarım Hatası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('ozan.demirel@sirket.com', 'Ozan Demirel', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'ogulcan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Dönem Açılış / Kapanış' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'ozan.demirel@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Sakarya Şubesi Yıl Sonu Kapanış (FAGLB03) Bakiye Aktarım Hatası',
        'Sakarya şirket kodu için yıl sonu kapanışında bilanço hesaplarının açılış bakiyesi bir sonraki yıla aktarılmamaktadır.', 'SAP-FI', 'Sakarya', 'in_progress',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'ozan.demirel@sirket.com', 'customer', 'Sakarya şirket kodu için yıl sonu kapanışında bilanço hesaplarının açılış bakiyesi bir sonraki yıla aktarılmamaktadır.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-FI', 'oncelik', 'urgent', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-FI', 'Sakarya şirket kodu için yıl sonu kapanışında bilanço hesaplarının açılış bakiyesi bir sonraki yıla aktarılmamaktadır.', 'FAGLGVTR bakiye aktarım programı çalıştırıldığında kar/zarar aktarım hesabının eksik olduğu tespit edildi, OBY2 ile hesap atanarak aktarım tamamlandı.', true);

    ---------------------------------------------------------------------------
    -- [83/120] Ankara Bölge Masraf Yeri (KS01) Hiyerarşi Tanım Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('nalan.efe@sirket.com', 'Nalan Efe', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'ogulcan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Şirket / Şube / Tesis Tanımı' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'nalan.efe@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Ankara Bölge Masraf Yeri (KS01) Hiyerarşi Tanım Talebi',
        'Ankara bölge müdürlüğü altında yeni kurulan dijital pazarlama birimi için masraf yeri oluşturulması ve hiyerarşiye bağlanması gerekmektedir.', 'SAP-FI', 'Ankara', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'nalan.efe@sirket.com', 'customer', 'Ankara bölge müdürlüğü altında yeni kurulan dijital pazarlama birimi için masraf yeri oluşturulması ve hiyerarşiye bağlanması gerekmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-FI', 'oncelik', 'medium', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-FI', 'Ankara bölge müdürlüğü altında yeni kurulan dijital pazarlama birimi için masraf yeri oluşturulması ve hiyerarşiye bağlanması gerekmektedir.', 'KS01 ile ANK-DPZ masraf yeri oluşturularak OKEON hiyerarşisinde Ankara Bölge düğümü altına bağlandı.', true);

    ---------------------------------------------------------------------------
    -- [84/120] FB50 Yevmiye Kaydında Belge Tipi Uyumsuzluğu
    INSERT INTO users (email, full_name, role, region)
    VALUES ('adem.polat@sirket.com', 'Adem Polat', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'ogulcan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Geliştirme / Uyarlama Hatası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'adem.polat@sirket.com', v_user_id, 'sapdestek@sirket.com', 'FB50 Yevmiye Kaydında Belge Tipi Uyumsuzluğu',
        'Yozgat muhasebe uzmanı FB50 ile serbest kayıt girerken ''Belge tipi SA bu hesap türü için geçersiz'' uyarısı almaktadır.', 'SAP-FI', 'Yozgat', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'adem.polat@sirket.com', 'customer', 'Yozgat muhasebe uzmanı FB50 ile serbest kayıt girerken ''Belge tipi SA bu hesap türü için geçersiz'' uyarısı almaktadır.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-FI', 'oncelik', 'high', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-FI', 'Yozgat muhasebe uzmanı FB50 ile serbest kayıt girerken ''Belge tipi SA bu hesap türü için geçersiz'' uyarısı almaktadır.', 'OBA7 belge tipi konfigürasyonunda SA tipi için izin verilen hesap gruplarına ilgili GL hesap grubu eklendi.', true);

    ---------------------------------------------------------------------------
    -- [85/120] FI Modülü Yeni Muhasebe Dönemi Açılması (OB52)
    INSERT INTO users (email, full_name, role, region)
    VALUES ('merve.celik@sirket.com', 'Merve Celik', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'ogulcan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Dönem Açılış / Kapanış' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'FI' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'merve.celik@sirket.com', v_user_id, 'sapdestek@sirket.com', 'FI Modülü Yeni Muhasebe Dönemi Açılması (OB52)',
        'İstanbul finans ekibi yeni mali yılın ilk döneminde kayıt girerken ''Dönem açık değil'' hatası alıyor, OB52 üzerinden dönem açılması gerekmektedir.', 'SAP-FI', 'İstanbul', 'resolved',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'merve.celik@sirket.com', 'customer', 'İstanbul finans ekibi yeni mali yılın ilk döneminde kayıt girerken ''Dönem açık değil'' hatası alıyor, OB52 üzerinden dönem açılması gerekmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-FI', 'oncelik', 'urgent', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-FI', 'İstanbul finans ekibi yeni mali yılın ilk döneminde kayıt girerken ''Dönem açık değil'' hatası alıyor, OB52 üzerinden dönem açılması gerekmektedir.', 'OB52 dönem kontrol tablosunda yeni yıl dönemi tüm hesap tipleri için açılarak kayıt girişi sağlandı.', true);

    ---------------------------------------------------------------------------
    -- [86/120] ME51N Satınalma Talebi Onay Sürecinde Sonsuz Döngü
    INSERT INTO users (email, full_name, role, region)
    VALUES ('can.turan@sirket.com', 'Can Turan', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'sena.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Geliştirme / Uyarlama Hatası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'can.turan@sirket.com', v_user_id, 'sapdestek@sirket.com', 'ME51N Satınalma Talebi Onay Sürecinde Sonsuz Döngü',
        'Ankara biriminde oluşturulan satınalma talepleri onay iş akışında 1. onaydan sonra tekrar başa dönüyor ve 2. onay adımına geçmiyor.', 'SAP-MM', 'Ankara', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'can.turan@sirket.com', 'customer', 'Ankara biriminde oluşturulan satınalma talepleri onay iş akışında 1. onaydan sonra tekrar başa dönüyor ve 2. onay adımına geçmiyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-MM', 'oncelik', 'high', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-MM', 'Ankara biriminde oluşturulan satınalma talepleri onay iş akışında 1. onaydan sonra tekrar başa dönüyor ve 2. onay adımına geçmiyor.', 'SWI1 workflow logunda koşul ifadesindeki döngü tespit edildi, onay şemasının 2. adıma geçiş koşulu düzeltilerek akış normale döndü.', true);

    ---------------------------------------------------------------------------
    -- [87/120] MM60 Tekrarlı Sipariş Malzeme Listesi Oluşturma Hatası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('burak.kaya@sirket.com', 'Burak Kaya', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'omer.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Veri Düzeltme' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'burak.kaya@sirket.com', v_user_id, 'sapdestek@sirket.com', 'MM60 Tekrarlı Sipariş Malzeme Listesi Oluşturma Hatası',
        'İstanbul tedarik zinciri birimi MM60 raporunda otomatik sipariş önerisi çalıştırdığında MRP alanı eksik malzemeler listelenmiyor.', 'SAP-MM', 'İstanbul', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'burak.kaya@sirket.com', 'customer', 'İstanbul tedarik zinciri birimi MM60 raporunda otomatik sipariş önerisi çalıştırdığında MRP alanı eksik malzemeler listelenmiyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-MM', 'oncelik', 'medium', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-MM', 'İstanbul tedarik zinciri birimi MM60 raporunda otomatik sipariş önerisi çalıştırdığında MRP alanı eksik malzemeler listelenmiyor.', 'İlgili malzemelerin MM02 MRP-1 görünümünde MRP tipi ''ND'' olarak ayarlanmıştı, ''PD'' (planlama) olarak değiştirilerek önerilere dahil edildi.', true);

    ---------------------------------------------------------------------------
    -- [88/120] Yozgat Tesisi İçin Yeni Satıcı Ana Veri Açılışı (XK01)
    INSERT INTO users (email, full_name, role, region)
    VALUES ('zeynep.avci@sirket.com', 'Zeynep Avci', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'sena.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Şirket / Şube / Tesis Tanımı' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'zeynep.avci@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Yozgat Tesisi İçin Yeni Satıcı Ana Veri Açılışı (XK01)',
        'Yozgat fabrikasına yeni hammadde tedarik edecek firma için XK01 üzerinden satıcı ana veri kartının açılması rica olunur.', 'SAP-MM', 'Yozgat', 'resolved',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'zeynep.avci@sirket.com', 'customer', 'Yozgat fabrikasına yeni hammadde tedarik edecek firma için XK01 üzerinden satıcı ana veri kartının açılması rica olunur.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-MM', 'oncelik', 'medium', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-MM', 'Yozgat fabrikasına yeni hammadde tedarik edecek firma için XK01 üzerinden satıcı ana veri kartının açılması rica olunur.', 'XK01 ile satıcı genel verileri, satınalma organizasyonu ve muhasebe verileri girilerek vergi ve ödeme koşulları tanımlandı.', true);

    ---------------------------------------------------------------------------
    -- [89/120] MIGO İade Hareketi (122) Stok Güncellenmesi Sorunu
    INSERT INTO users (email, full_name, role, region)
    VALUES ('hasan.koc@sirket.com', 'Hasan Koc', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'omer.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Entegrasyon Hataları' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'hasan.koc@sirket.com', v_user_id, 'sapdestek@sirket.com', 'MIGO İade Hareketi (122) Stok Güncellenmesi Sorunu',
        'Sakarya deposundan tedarikçiye yapılan malzeme iadesinde MIGO 122 hareketiyle işlem kaydedilmesine rağmen stok miktarı düşmüyor.', 'SAP-MM', 'Sakarya', 'in_progress',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'hasan.koc@sirket.com', 'customer', 'Sakarya deposundan tedarikçiye yapılan malzeme iadesinde MIGO 122 hareketiyle işlem kaydedilmesine rağmen stok miktarı düşmüyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-MM', 'oncelik', 'urgent', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-MM', 'Sakarya deposundan tedarikçiye yapılan malzeme iadesinde MIGO 122 hareketiyle işlem kaydedilmesine rağmen stok miktarı düşmüyor.', 'Hareket tipinde depo yeri atama kuralı kontrol edildi, 122 hareketi için stok güncelleme göstergesi aktif edilerek işlem tekrarlandı.', true);

    ---------------------------------------------------------------------------
    -- [90/120] SAP MM Modülü Dönem Sonu Kapanış Kontrol Listesi Eğitimi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('mualla.kurt@sirket.com', 'Mualla Kurt', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'sena.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Eğitim Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'MM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'low' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'mualla.kurt@sirket.com', v_user_id, 'sapdestek@sirket.com', 'SAP MM Modülü Dönem Sonu Kapanış Kontrol Listesi Eğitimi',
        'İstanbul ve Ankara satınalma birimlerindeki personele dönem sonu envanter mutabakatı ve açık sipariş kontrolü eğitimi verilmesi talep edilmektedir.', 'SAP-MM', 'İstanbul', 'assigned',
        'low', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'mualla.kurt@sirket.com', 'customer', 'İstanbul ve Ankara satınalma birimlerindeki personele dönem sonu envanter mutabakatı ve açık sipariş kontrolü eğitimi verilmesi talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-MM', 'oncelik', 'low', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-MM', 'İstanbul ve Ankara satınalma birimlerindeki personele dönem sonu envanter mutabakatı ve açık sipariş kontrolü eğitimi verilmesi talep edilmektedir.', 'MB5L, ME2M açık sipariş ve MMPV dönem kapanış adımlarını kapsayan eğitim materyali hazırlanarak online eğitim verildi.', true);

    ---------------------------------------------------------------------------
    -- [91/120] VF01 Toplu Fatura Oluşturmada Eksik Teslimat Seçimi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('cemre.ozturk@sirket.com', 'Cemre Ozturk', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'gizem.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Geliştirme / Uyarlama Hatası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'cemre.ozturk@sirket.com', v_user_id, 'sapdestek@sirket.com', 'VF01 Toplu Fatura Oluşturmada Eksik Teslimat Seçimi',
        'İstanbul satış ekibi VF01 ile toplu fatura kesmeye çalışırken bazı teslim edilen siparişler fatura havuzunda görünmüyor.', 'SAP-SD', 'İstanbul', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'cemre.ozturk@sirket.com', 'customer', 'İstanbul satış ekibi VF01 ile toplu fatura kesmeye çalışırken bazı teslim edilen siparişler fatura havuzunda görünmüyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-SD', 'oncelik', 'high', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-SD', 'İstanbul satış ekibi VF01 ile toplu fatura kesmeye çalışırken bazı teslim edilen siparişler fatura havuzunda görünmüyor.', 'Eksik teslimatların fatura bloku aktif olduğu tespit edildi, VL02N ile blok kaldırılarak fatura havuzuna düşmesi sağlandı.', true);

    ---------------------------------------------------------------------------
    -- [92/120] Ankara Bayisi Müşteri Ana Veri Kredi Blokaj Açılması
    INSERT INTO users (email, full_name, role, region)
    VALUES ('nalan.efe@sirket.com', 'Nalan Efe', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'sena.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Veri Düzeltme' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'nalan.efe@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Ankara Bayisi Müşteri Ana Veri Kredi Blokaj Açılması',
        'Ankara bayisinin ödeme yapmasına rağmen siparişleri kredi blokajına düşmeye devam ediyor, FD33 kredi limitinin güncellenmesi gerekmektedir.', 'SAP-SD', 'Ankara', 'assigned',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'nalan.efe@sirket.com', 'customer', 'Ankara bayisinin ödeme yapmasına rağmen siparişleri kredi blokajına düşmeye devam ediyor, FD33 kredi limitinin güncellenmesi gerekmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-SD', 'oncelik', 'urgent', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-SD', 'Ankara bayisinin ödeme yapmasına rağmen siparişleri kredi blokajına düşmeye devam ediyor, FD33 kredi limitinin güncellenmesi gerekmektedir.', 'FD33 üzerinden bayinin kredi limiti güncellendi ve UKM_RELEASED ile bekleyen siparişlerin blokajı kaldırıldı.', true);

    ---------------------------------------------------------------------------
    -- [93/120] Yozgat Deposundan Kısmi Sevkiyat Sonrası Bakiye Teslimat Oluşmuyor
    INSERT INTO users (email, full_name, role, region)
    VALUES ('ozan.demirel@sirket.com', 'Ozan Demirel', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'gizem.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Entegrasyon Hataları' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'ozan.demirel@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Yozgat Deposundan Kısmi Sevkiyat Sonrası Bakiye Teslimat Oluşmuyor',
        'Yozgat deposundan kısmi sevkiyat yapılan sipariş için kalan miktara ait bakiye teslimat belgesi otomatik oluşmamaktadır.', 'SAP-SD', 'Yozgat', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'ozan.demirel@sirket.com', 'customer', 'Yozgat deposundan kısmi sevkiyat yapılan sipariş için kalan miktara ait bakiye teslimat belgesi otomatik oluşmamaktadır.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-SD', 'oncelik', 'high', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-SD', 'Yozgat deposundan kısmi sevkiyat yapılan sipariş için kalan miktara ait bakiye teslimat belgesi otomatik oluşmamaktadır.', 'Siparişteki teslimat göstergesinde ''Tam teslimat'' ayarlıydı, ''Kısmi teslimat izin'' olarak değiştirilip bakiye teslimat oluşturuldu.', true);

    ---------------------------------------------------------------------------
    -- [94/120] Sakarya Bölgesi İçin Yeni Nakliye Güzergahı ve Taşıma Maliyeti Tanımlama
    INSERT INTO users (email, full_name, role, region)
    VALUES ('adem.polat@sirket.com', 'Adem Polat', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'sena.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Geliştirme / Ekip Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'adem.polat@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Sakarya Bölgesi İçin Yeni Nakliye Güzergahı ve Taşıma Maliyeti Tanımlama',
        'Sakarya-Ankara arası yeni nakliye güzergahı için taşıma koşulları ve navlun maliyet hesabının sisteme tanımlanması talep edilmektedir.', 'SAP-SD', 'Sakarya', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'adem.polat@sirket.com', 'customer', 'Sakarya-Ankara arası yeni nakliye güzergahı için taşıma koşulları ve navlun maliyet hesabının sisteme tanımlanması talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-SD', 'oncelik', 'medium', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-SD', 'Sakarya-Ankara arası yeni nakliye güzergahı için taşıma koşulları ve navlun maliyet hesabının sisteme tanımlanması talep edilmektedir.', 'OVRO güzergah belirleme kurallarına yeni hat eklendi ve VK11 ile nakliye koşul kaydı (KF00) tanımlandı.', true);

    ---------------------------------------------------------------------------
    -- [95/120] SD Modülü Satış Süreci Yeni Personel Eğitim Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('selim.kaya@sirket.com', 'Selim Kaya', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'gizem.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Eğitim Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'low' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'selim.kaya@sirket.com', v_user_id, 'sapdestek@sirket.com', 'SD Modülü Satış Süreci Yeni Personel Eğitim Talebi',
        'Ankara satış ofisine yeni katılan 4 personele VA01-VL01N-VF01 temel sipariş-teslimat-fatura döngüsü eğitimi verilmesi talep edilmektedir.', 'SAP-SD', 'Ankara', 'resolved',
        'low', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'selim.kaya@sirket.com', 'customer', 'Ankara satış ofisine yeni katılan 4 personele VA01-VL01N-VF01 temel sipariş-teslimat-fatura döngüsü eğitimi verilmesi talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-SD', 'oncelik', 'low', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-SD', 'Ankara satış ofisine yeni katılan 4 personele VA01-VL01N-VF01 temel sipariş-teslimat-fatura döngüsü eğitimi verilmesi talep edilmektedir.', 'VA01→VL01N→VF01 akışını adım adım gösteren eğitim dokümanı ve video kaydı hazırlanarak online eğitim gerçekleştirildi.', true);

    ---------------------------------------------------------------------------
    -- [96/120] SAP Kernel Güncelleme Sonrası ICM Servisi Başlamıyor
    INSERT INTO users (email, full_name, role, region)
    VALUES ('tayfun.bilgin@sirket.com', 'Tayfun Bilgin', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'mustafa.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Server / Sanallaştırma Arızası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'tayfun.bilgin@sirket.com', v_user_id, 'sapdestek@sirket.com', 'SAP Kernel Güncelleme Sonrası ICM Servisi Başlamıyor',
        'İstanbul canlı sistemde planlı kernel güncellemesi sonrası Internet Communication Manager (ICM) servisi start etmiyor ve Fiori erişimi durdu.', 'SAP-Basis', 'İstanbul', 'in_progress',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'tayfun.bilgin@sirket.com', 'customer', 'İstanbul canlı sistemde planlı kernel güncellemesi sonrası Internet Communication Manager (ICM) servisi start etmiyor ve Fiori erişimi durdu.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Basis', 'oncelik', 'urgent', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Basis', 'İstanbul canlı sistemde planlı kernel güncellemesi sonrası Internet Communication Manager (ICM) servisi start etmiyor ve Fiori erişimi durdu.', 'Yeni kernel sürümünde ICM parametrelerinin uyumsuz olduğu tespit edildi, icm/server_port_0 parametresi düzeltilerek ICM başlatıldı.', true);

    ---------------------------------------------------------------------------
    -- [97/120] Ankara SAP GUI 7.80 Versiyon Yükseltme ve Dağıtım
    INSERT INTO users (email, full_name, role, region)
    VALUES ('mehmet.can@sirket.com', 'Mehmet Can', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Geliştirme / Ekip Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'mehmet.can@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Ankara SAP GUI 7.80 Versiyon Yükseltme ve Dağıtım',
        'Ankara ofisindeki tüm kullanıcıların SAP GUI istemcisinin 7.70''den 7.80 sürümüne toplu olarak güncellenmesi talep edilmektedir.', 'SAP-Basis', 'Ankara', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'mehmet.can@sirket.com', 'customer', 'Ankara ofisindeki tüm kullanıcıların SAP GUI istemcisinin 7.70''den 7.80 sürümüne toplu olarak güncellenmesi talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Basis', 'oncelik', 'medium', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Basis', 'Ankara ofisindeki tüm kullanıcıların SAP GUI istemcisinin 7.70''den 7.80 sürümüne toplu olarak güncellenmesi talep edilmektedir.', 'SCCM üzerinden SAP GUI 7.80 paketi hazırlanarak Ankara OU''sundaki bilgisayarlara sıralı dağıtım planlandı ve uygulandı.', true);

    ---------------------------------------------------------------------------
    -- [98/120] HANA DB Disk Alanı %95 Doluluk Uyarısı
    INSERT INTO users (email, full_name, role, region)
    VALUES ('cengiz.kaya@sirket.com', 'Cengiz Kaya', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'mustafa.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yedekleme / Snapshot Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'cengiz.kaya@sirket.com', v_user_id, 'sapdestek@sirket.com', 'HANA DB Disk Alanı %95 Doluluk Uyarısı',
        'Yozgat üretim sistemi HANA veritabanı disk kullanımı %95 seviyesine ulaştı, acil alan açılması ve log temizliği gerekmektedir.', 'SAP-Basis', 'Yozgat', 'assigned',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'cengiz.kaya@sirket.com', 'customer', 'Yozgat üretim sistemi HANA veritabanı disk kullanımı %95 seviyesine ulaştı, acil alan açılması ve log temizliği gerekmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Basis', 'oncelik', 'urgent', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Basis', 'Yozgat üretim sistemi HANA veritabanı disk kullanımı %95 seviyesine ulaştı, acil alan açılması ve log temizliği gerekmektedir.', 'Eski backup catalog girişleri temizlendi, trace dosyaları silinerek ve data volume genişletilerek doluluk %72''ye düşürüldü.', true);

    ---------------------------------------------------------------------------
    -- [99/120] Sakarya Ofisi SAP Logon Bağlantı Parametreleri Güncelleme
    INSERT INTO users (email, full_name, role, region)
    VALUES ('nermin.aslan@sirket.com', 'Nermin Aslan', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Active Directory Arızası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'nermin.aslan@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Sakarya Ofisi SAP Logon Bağlantı Parametreleri Güncelleme',
        'Sakarya ofisindeki kullanıcıların SAP Logon''da sunucu IP değişikliği nedeniyle sisteme bağlanamaması, SAPLogon.ini güncellenmesi gerekmektedir.', 'SAP-Basis', 'Sakarya', 'resolved',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'nermin.aslan@sirket.com', 'customer', 'Sakarya ofisindeki kullanıcıların SAP Logon''da sunucu IP değişikliği nedeniyle sisteme bağlanamaması, SAPLogon.ini güncellenmesi gerekmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Basis', 'oncelik', 'high', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Basis', 'Sakarya ofisindeki kullanıcıların SAP Logon''da sunucu IP değişikliği nedeniyle sisteme bağlanamaması, SAPLogon.ini güncellenmesi gerekmektedir.', 'Merkezi SAP Logon XML konfigürasyon dosyasındaki message server IP adresi güncellenerek GPO ile dağıtıldı.', true);

    ---------------------------------------------------------------------------
    -- [100/120] SAP Solution Manager ITSM İçin Destek Bağlantısı Kurulumu
    INSERT INTO users (email, full_name, role, region)
    VALUES ('sevgi.can@sirket.com', 'Sevgi Can', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'mustafa.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Entegrasyon Hataları' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'sevgi.can@sirket.com', v_user_id, 'sapdestek@sirket.com', 'SAP Solution Manager ITSM İçin Destek Bağlantısı Kurulumu',
        'İstanbul IT yönetimi SAP Solution Manager ile ticket yönetim entegrasyonu için RFC bağlantısı ve servis yapılandırması yapılmasını talep ediyor.', 'SAP-Basis', 'İstanbul', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'sevgi.can@sirket.com', 'customer', 'İstanbul IT yönetimi SAP Solution Manager ile ticket yönetim entegrasyonu için RFC bağlantısı ve servis yapılandırması yapılmasını talep ediyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Basis', 'oncelik', 'medium', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Basis', 'İstanbul IT yönetimi SAP Solution Manager ile ticket yönetim entegrasyonu için RFC bağlantısı ve servis yapılandırması yapılmasını talep ediyor.', 'SM59 ile çift yönlü RFC bağlantısı kuruldu, SOLMAN_SETUP üzerinden managed system olarak kayıt tamamlandı.', true);

    ---------------------------------------------------------------------------
    -- [101/120] CO01 Üretim Emri Açma Yetkisi Eksikliği
    INSERT INTO users (email, full_name, role, region)
    VALUES ('mert.aydin@sirket.com', 'Mert Aydin', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yetki Hatası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'PP' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'mert.aydin@sirket.com', v_user_id, 'sapdestek@sirket.com', 'CO01 Üretim Emri Açma Yetkisi Eksikliği',
        'Yozgat fabrikasında üretim planlama uzmanı CO01 ile üretim emri açmaya çalışırken ''C_AFKO_WRK yetki nesnesi eksik'' hatası almaktadır.', 'SAP-Yetki', 'Yozgat', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'mert.aydin@sirket.com', 'customer', 'Yozgat fabrikasında üretim planlama uzmanı CO01 ile üretim emri açmaya çalışırken ''C_AFKO_WRK yetki nesnesi eksik'' hatası almaktadır.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Yetki', 'oncelik', 'high', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Yetki', 'Yozgat fabrikasında üretim planlama uzmanı CO01 ile üretim emri açmaya çalışırken ''C_AFKO_WRK yetki nesnesi eksik'' hatası almaktadır.', 'Z_PP_PLANNER rolüne C_AFKO_WRK ve C_AFKO_AUF yetki nesneleri Yozgat tesis değeriyle eklenerek kullanıcıya atandı.', true);

    ---------------------------------------------------------------------------
    -- [102/120] Ankara Satış Ekibi Fiyat Koşulu Değiştirme Yetkisi Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('oguz.cetin@sirket.com', 'Oguz Cetin', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yetki Hatası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'SD' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'oguz.cetin@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Ankara Satış Ekibi Fiyat Koşulu Değiştirme Yetkisi Talebi',
        'Ankara satış temsilcileri VA02 üzerinden sipariş fiyatını güncellemek istediğinde ''V_KONH_VKO yetkisi yok'' uyarısı almaktadır.', 'SAP-Yetki', 'Ankara', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'oguz.cetin@sirket.com', 'customer', 'Ankara satış temsilcileri VA02 üzerinden sipariş fiyatını güncellemek istediğinde ''V_KONH_VKO yetkisi yok'' uyarısı almaktadır.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Yetki', 'oncelik', 'high', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Yetki', 'Ankara satış temsilcileri VA02 üzerinden sipariş fiyatını güncellemek istediğinde ''V_KONH_VKO yetkisi yok'' uyarısı almaktadır.', 'PFCG''de Z_SD_SATIS rolüne V_KONH_VKO yetki nesnesinde koşul tablosu ve değiştirme aktivitesi eklenerek yetki üretildi.', true);

    ---------------------------------------------------------------------------
    -- [103/120] SOD (Görev Ayrılığı) Çakışma Analizi ve Düzeltme
    INSERT INTO users (email, full_name, role, region)
    VALUES ('sinan.kurt@sirket.com', 'Sinan Kurt', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Geliştirme / Ekip Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'Basis' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'sinan.kurt@sirket.com', v_user_id, 'sapdestek@sirket.com', 'SOD (Görev Ayrılığı) Çakışma Analizi ve Düzeltme',
        'İstanbul iç denetim birimi yıllık SOD analizinde 5 kullanıcıda satınalma siparişi oluşturma ve fatura onaylama yetkilerinin aynı anda bulunduğunu tespit etti.', 'SAP-Yetki', 'İstanbul', 'in_progress',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'sinan.kurt@sirket.com', 'customer', 'İstanbul iç denetim birimi yıllık SOD analizinde 5 kullanıcıda satınalma siparişi oluşturma ve fatura onaylama yetkilerinin aynı anda bulunduğunu tespit etti.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Yetki', 'oncelik', 'urgent', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Yetki', 'İstanbul iç denetim birimi yıllık SOD analizinde 5 kullanıcıda satınalma siparişi oluşturma ve fatura onaylama yetkilerinin aynı anda bulunduğunu tespit etti.', 'SUIM raporlarıyla çakışan roller belirlendi, 5 kullanıcıdan biri sipariş diğeri fatura rolüne ayrılarak SOD ihlalleri giderildi.', true);

    ---------------------------------------------------------------------------
    -- [104/120] Sakarya QM Laboratuvar Sonuç Girişi İçin Yeni Rol Oluşturma
    INSERT INTO users (email, full_name, role, region)
    VALUES ('fatma.teyze@sirket.com', 'Fatma Teyze', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yeni Yetki / Rol Talebi' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'QM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'fatma.teyze@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Sakarya QM Laboratuvar Sonuç Girişi İçin Yeni Rol Oluşturma',
        'Sakarya kalite laboratuvarında işe başlayan 2 kimyager için QE01/QE02 sonuç girişi ve QA02 muayene lotu görüntüleme yetkilerini içeren yeni bir rol oluşturulması gerekmektedir.', 'SAP-Yetki', 'Sakarya', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'fatma.teyze@sirket.com', 'customer', 'Sakarya kalite laboratuvarında işe başlayan 2 kimyager için QE01/QE02 sonuç girişi ve QA02 muayene lotu görüntüleme yetkilerini içeren yeni bir rol oluşturulması gerekmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Yetki', 'oncelik', 'medium', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Yetki', 'Sakarya kalite laboratuvarında işe başlayan 2 kimyager için QE01/QE02 sonuç girişi ve QA02 muayene lotu görüntüleme yetkilerini içeren yeni bir rol oluşturulması gerekmektedir.', 'PFCG''de Z_QM_LAB_SONUC rolü oluşturularak QE01, QE02, QA02, QA03 işlem kodları ve Q_INSP yetki nesneleri tanımlandı.', true);

    ---------------------------------------------------------------------------
    -- [105/120] Yozgat Bakım Teknisyeni PM İş Emri Yetkisi Genişletme
    INSERT INTO users (email, full_name, role, region)
    VALUES ('aylin.toprak@sirket.com', 'Aylin Toprak', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'SAP Danışman Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yetki Hatası' LIMIT 1;
    SELECT id INTO v_sap_id FROM sap_modules WHERE code = 'PM' LIMIT 1;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'aylin.toprak@sirket.com', v_user_id, 'sapdestek@sirket.com', 'Yozgat Bakım Teknisyeni PM İş Emri Yetkisi Genişletme',
        'Yozgat fabrikası bakım teknisyeni IW32 ile iş emri teyidi yapamıyor, ''I_AUFK_IWK yetki nesnesi eksik'' uyarısı almaktadır.', 'SAP-Yetki', 'Yozgat', 'resolved',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'aylin.toprak@sirket.com', 'customer', 'Yozgat fabrikası bakım teknisyeni IW32 ile iş emri teyidi yapamıyor, ''I_AUFK_IWK yetki nesnesi eksik'' uyarısı almaktadır.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'SAP-Yetki', 'oncelik', 'medium', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'SAP-Yetki', 'Yozgat fabrikası bakım teknisyeni IW32 ile iş emri teyidi yapamıyor, ''I_AUFK_IWK yetki nesnesi eksik'' uyarısı almaktadır.', 'Z_PM_TEKNISYEN rolüne I_AUFK_IWK, I_AUFK_ART yetki nesneleri ve Yozgat planlama tesisi eklenerek iş emri teyidi sağlandı.', true);

    ---------------------------------------------------------------------------
    -- [106/120] Sakarya Fabrika DHCP Sunucusu IP Havuzu Tükendi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('adem.polat@sirket.com', 'Adem Polat', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'İnternet Kesintisi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'adem.polat@sirket.com', v_user_id, 'btdestek@sirket.com', 'Sakarya Fabrika DHCP Sunucusu IP Havuzu Tükendi',
        'Sakarya üretim tesisinde yeni bağlanan cihazlar IP adresi alamıyor, DHCP scope''undaki adres havuzu dolmuş durumda.', 'IT-Ag', 'Sakarya', 'assigned',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'adem.polat@sirket.com', 'customer', 'Sakarya üretim tesisinde yeni bağlanan cihazlar IP adresi alamıyor, DHCP scope''undaki adres havuzu dolmuş durumda.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Ag', 'oncelik', 'urgent', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Ag', 'Sakarya üretim tesisinde yeni bağlanan cihazlar IP adresi alamıyor, DHCP scope''undaki adres havuzu dolmuş durumda.', 'DHCP scope genişletilerek /23 subnet''e çıkarıldı, eski lease kayıtları temizlenerek yeni cihazlar IP alabilir hale getirildi.', true);

    ---------------------------------------------------------------------------
    -- [107/120] Yozgat Fabrika IP Kamera Ağı Bant Genişliği Sorunu
    INSERT INTO users (email, full_name, role, region)
    VALUES ('ali.dogan@sirket.com', 'Ali Dogan', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Erişim Yavaşlığı' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'ali.dogan@sirket.com', v_user_id, 'btdestek@sirket.com', 'Yozgat Fabrika IP Kamera Ağı Bant Genişliği Sorunu',
        'Yozgat fabrikasındaki 20 IP kameranın aynı anda yayın yapması ofis ağını yavaşlatıyor, kamera trafiği ayrıştırılması gerekmektedir.', 'IT-Ag', 'Yozgat', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'ali.dogan@sirket.com', 'customer', 'Yozgat fabrikasındaki 20 IP kameranın aynı anda yayın yapması ofis ağını yavaşlatıyor, kamera trafiği ayrıştırılması gerekmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Ag', 'oncelik', 'high', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Ag', 'Yozgat fabrikasındaki 20 IP kameranın aynı anda yayın yapması ofis ağını yavaşlatıyor, kamera trafiği ayrıştırılması gerekmektedir.', 'Kamera trafiği ayrı VLAN''a taşınarak QoS ile bant genişliği sınırlandırıldı, ofis ağı performansı normale döndü.', true);

    ---------------------------------------------------------------------------
    -- [108/120] İstanbul Ofis Firewall Firmware Güncelleme Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('cemre.ozturk@sirket.com', 'Cemre Ozturk', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Firma Dışı Erişim / Port Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'cemre.ozturk@sirket.com', v_user_id, 'btdestek@sirket.com', 'İstanbul Ofis Firewall Firmware Güncelleme Talebi',
        'İstanbul merkez FortiGate firewall''un firmware sürümü 2 major versiyon geride kaldı, güvenlik açıkları nedeniyle güncelleme planlanması gerekmektedir.', 'IT-Ag', 'İstanbul', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'cemre.ozturk@sirket.com', 'customer', 'İstanbul merkez FortiGate firewall''un firmware sürümü 2 major versiyon geride kaldı, güvenlik açıkları nedeniyle güncelleme planlanması gerekmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Ag', 'oncelik', 'medium', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Ag', 'İstanbul merkez FortiGate firewall''un firmware sürümü 2 major versiyon geride kaldı, güvenlik açıkları nedeniyle güncelleme planlanması gerekmektedir.', 'Mesai sonrası bakım penceresinde FortiGate firmware v7.4''e güncellendi, konfigürasyon yedeklenerek tüm policy kuralları doğrulandı.', true);

    ---------------------------------------------------------------------------
    -- [109/120] Ankara Ofisi Kablosuz Ağ Sertifika Doğrulaması Başarısız
    INSERT INTO users (email, full_name, role, region)
    VALUES ('ozan.demirel@sirket.com', 'Ozan Demirel', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Wi-Fi / Misafir Ağı Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'ozan.demirel@sirket.com', v_user_id, 'btdestek@sirket.com', 'Ankara Ofisi Kablosuz Ağ Sertifika Doğrulaması Başarısız',
        'Ankara ofisinde WPA2-Enterprise kablosuz ağa bağlanmaya çalışan cihazlar ''Sertifika doğrulaması başarısız'' hatası alıyor.', 'IT-Ag', 'Ankara', 'resolved',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'ozan.demirel@sirket.com', 'customer', 'Ankara ofisinde WPA2-Enterprise kablosuz ağa bağlanmaya çalışan cihazlar ''Sertifika doğrulaması başarısız'' hatası alıyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Ag', 'oncelik', 'high', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Ag', 'Ankara ofisinde WPA2-Enterprise kablosuz ağa bağlanmaya çalışan cihazlar ''Sertifika doğrulaması başarısız'' hatası alıyor.', 'RADIUS sunucusundaki SSL sertifikası süresinin dolduğu tespit edildi, yeni sertifika yüklenerek Wi-Fi erişimi normale döndü.', true);

    ---------------------------------------------------------------------------
    -- [110/120] İstanbul Ofis Belirli Web Sitelerine Erişim Engeli Kaldırma
    INSERT INTO users (email, full_name, role, region)
    VALUES ('nalan.efe@sirket.com', 'Nalan Efe', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Erişim Engeli' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'low' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'nalan.efe@sirket.com', v_user_id, 'btdestek@sirket.com', 'İstanbul Ofis Belirli Web Sitelerine Erişim Engeli Kaldırma',
        'İstanbul pazarlama departmanı sosyal medya yönetim araçlarına (Hootsuite, Buffer) erişmek istiyor ancak web filtresi tarafından engellenmektedir.', 'IT-Ag', 'İstanbul', 'resolved',
        'low', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'nalan.efe@sirket.com', 'customer', 'İstanbul pazarlama departmanı sosyal medya yönetim araçlarına (Hootsuite, Buffer) erişmek istiyor ancak web filtresi tarafından engellenmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Ag', 'oncelik', 'low', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Ag', 'İstanbul pazarlama departmanı sosyal medya yönetim araçlarına (Hootsuite, Buffer) erişmek istiyor ancak web filtresi tarafından engellenmektedir.', 'FortiGate web filter profilinde pazarlama departmanı IP grubuna özel whitelist kuralı eklenerek ilgili URL''lere erişim açıldı.', true);

    ---------------------------------------------------------------------------
    -- [111/120] Ankara Ofisi UPS Cihazı Alarm Veriyor ve Bypass Modunda
    INSERT INTO users (email, full_name, role, region)
    VALUES ('tarik.yildiz@sirket.com', 'Tarik Yildiz', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'faruk.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Server Donanımı Arızası' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'tarik.yildiz@sirket.com', v_user_id, 'btdestek@sirket.com', 'Ankara Ofisi UPS Cihazı Alarm Veriyor ve Bypass Modunda',
        'Ankara sunucu odasındaki APC Smart-UPS 3000 cihazı sürekli alarm sesi çıkarıyor ve bypass moduna geçmiş, kesintisiz güç koruması devre dışı.', 'IT-Donanim', 'Ankara', 'assigned',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'tarik.yildiz@sirket.com', 'customer', 'Ankara sunucu odasındaki APC Smart-UPS 3000 cihazı sürekli alarm sesi çıkarıyor ve bypass moduna geçmiş, kesintisiz güç koruması devre dışı.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Donanim', 'oncelik', 'urgent', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Donanim', 'Ankara sunucu odasındaki APC Smart-UPS 3000 cihazı sürekli alarm sesi çıkarıyor ve bypass moduna geçmiş, kesintisiz güç koruması devre dışı.', 'Ankara destek uzmanı UPS bataryalarının ömrünü tamamladığını tespit etti, yedek batarya takılarak cihaz normal moda alındı.', true);

    ---------------------------------------------------------------------------
    -- [112/120] İstanbul Toplantı Odası Video Konferans Kamerası Arızası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('aylin.sen@sirket.com', 'Aylin Sen', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'emirhan.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Bilgisayar Çevre Birimleri Arızası' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'aylin.sen@sirket.com', v_user_id, 'btdestek@sirket.com', 'İstanbul Toplantı Odası Video Konferans Kamerası Arızası',
        'İstanbul A Blok toplantı odasındaki Logitech Rally kamera sistemi Teams ve Zoom toplantılarında görüntü vermiyor, LED ışığı yanmıyor.', 'IT-Donanim', 'İstanbul', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'aylin.sen@sirket.com', 'customer', 'İstanbul A Blok toplantı odasındaki Logitech Rally kamera sistemi Teams ve Zoom toplantılarında görüntü vermiyor, LED ışığı yanmıyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Donanim', 'oncelik', 'high', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Donanim', 'İstanbul A Blok toplantı odasındaki Logitech Rally kamera sistemi Teams ve Zoom toplantılarında görüntü vermiyor, LED ışığı yanmıyor.', 'İstanbul destek uzmanı USB hub firmware güncellemesi yaparak ve kamera sürücüsünü yeniden yükleyerek görüntü sorununu çözdü.', true);

    ---------------------------------------------------------------------------
    -- [113/120] Sakarya Fabrikası Endüstriyel PC Disk Arızası
    INSERT INTO users (email, full_name, role, region)
    VALUES ('sabri.guler@sirket.com', 'Sabri Guler', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yucel.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Bilgisayar Arızası' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'urgent' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'sabri.guler@sirket.com', v_user_id, 'btdestek@sirket.com', 'Sakarya Fabrikası Endüstriyel PC Disk Arızası',
        'Sakarya üretim hattındaki SCADA izleme bilgisayarının SSD diskinde ''S.M.A.R.T. failure'' uyarısı çıkıyor ve sistem aşırı yavaşladı.', 'IT-Donanim', 'Sakarya', 'in_progress',
        'urgent', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'sabri.guler@sirket.com', 'customer', 'Sakarya üretim hattındaki SCADA izleme bilgisayarının SSD diskinde ''S.M.A.R.T. failure'' uyarısı çıkıyor ve sistem aşırı yavaşladı.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Donanim', 'oncelik', 'urgent', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Donanim', 'Sakarya üretim hattındaki SCADA izleme bilgisayarının SSD diskinde ''S.M.A.R.T. failure'' uyarısı çıkıyor ve sistem aşırı yavaşladı.', 'Sakarya BT sorumlusu mevcut disk imajını yedekledikten sonra yeni SSD''ye klonlayarak üretim hattı kesintisi minimize edildi.', true);

    ---------------------------------------------------------------------------
    -- [114/120] Yozgat Fabrikası El Terminali Batarya Şişmesi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('hasan.tatar@sirket.com', 'Hasan Tatar', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'salih.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Bilgisayar Çevre Birimleri Arızası' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'hasan.tatar@sirket.com', v_user_id, 'btdestek@sirket.com', 'Yozgat Fabrikası El Terminali Batarya Şişmesi',
        'Yozgat depo personelinin kullandığı Zebra MC33 el terminalinin bataryası şişmiş ve cihaz açılmıyor, güvenlik riski oluşturmaktadır.', 'IT-Donanim', 'Yozgat', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'hasan.tatar@sirket.com', 'customer', 'Yozgat depo personelinin kullandığı Zebra MC33 el terminalinin bataryası şişmiş ve cihaz açılmıyor, güvenlik riski oluşturmaktadır.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Donanim', 'oncelik', 'high', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Donanim', 'Yozgat depo personelinin kullandığı Zebra MC33 el terminalinin bataryası şişmiş ve cihaz açılmıyor, güvenlik riski oluşturmaktadır.', 'Yozgat destek uzmanı şişmiş bataryayı güvenli şekilde çıkardı ve garanti kapsamında yeni batarya takarak cihazı devreye aldı.', true);

    ---------------------------------------------------------------------------
    -- [115/120] İstanbul Finans Katı Yeni Çok Fonksiyonlu Yazıcı Kurulumu
    INSERT INTO users (email, full_name, role, region)
    VALUES ('deniz.kor@sirket.com', 'Deniz Kor', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'yusuf.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Yazıcı Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'deniz.kor@sirket.com', v_user_id, 'btdestek@sirket.com', 'İstanbul Finans Katı Yeni Çok Fonksiyonlu Yazıcı Kurulumu',
        'İstanbul finans katına yeni alınan HP Color LaserJet Enterprise yazıcının ağa bağlanması, sürücü dağıtımı ve departman print queue tanımlanması talep edilmektedir.', 'IT-Donanim', 'İstanbul', 'resolved',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'deniz.kor@sirket.com', 'customer', 'İstanbul finans katına yeni alınan HP Color LaserJet Enterprise yazıcının ağa bağlanması, sürücü dağıtımı ve departman print queue tanımlanması talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Donanim', 'oncelik', 'medium', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Donanim', 'İstanbul finans katına yeni alınan HP Color LaserJet Enterprise yazıcının ağa bağlanması, sürücü dağıtımı ve departman print queue tanımlanması talep edilmektedir.', 'Yazıcı statik IP ile ağa bağlanarak print server üzerinde paylaşım ve GPO ile sürücü dağıtımı yapıldı.', true);

    ---------------------------------------------------------------------------
    -- [116/120] OneDrive Eşitleme Hatası ve Dosya Çakışması
    INSERT INTO users (email, full_name, role, region)
    VALUES ('cengiz.kaya@sirket.com', 'Cengiz Kaya', 'customer', 'Ankara')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'turgut.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Kullanıcı Hesabı Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'cengiz.kaya@sirket.com', v_user_id, 'btdestek@sirket.com', 'OneDrive Eşitleme Hatası ve Dosya Çakışması',
        'Ankara ofisindeki kullanıcının OneDrive dosyaları eşitlenmiyor, birden fazla ''conflict'' kopyası oluşmuş ve belgeler kaybolma riski taşıyor.', 'IT-Hesap', 'Ankara', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'cengiz.kaya@sirket.com', 'customer', 'Ankara ofisindeki kullanıcının OneDrive dosyaları eşitlenmiyor, birden fazla ''conflict'' kopyası oluşmuş ve belgeler kaybolma riski taşıyor.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Hesap', 'oncelik', 'high', 'region', 'Ankara')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Hesap', 'Ankara ofisindeki kullanıcının OneDrive dosyaları eşitlenmiyor, birden fazla ''conflict'' kopyası oluşmuş ve belgeler kaybolma riski taşıyor.', 'OneDrive istemcisi sıfırlanarak çakışan dosyalar manuel olarak birleştirildi ve eşitleme yeniden başlatıldı.', true);

    ---------------------------------------------------------------------------
    -- [117/120] İstanbul Ofisi Toplu Microsoft 365 Lisans Ataması
    INSERT INTO users (email, full_name, role, region)
    VALUES ('pelin.ozcan@sirket.com', 'Pelin Ozcan', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'esra.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Kullanıcı Hesabı Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'pelin.ozcan@sirket.com', v_user_id, 'btdestek@sirket.com', 'İstanbul Ofisi Toplu Microsoft 365 Lisans Ataması',
        'İstanbul merkeze aynı anda başlayan 6 yeni personele Microsoft 365 Business Standard lisanslarının atanması ve Teams hesaplarının açılması gerekmektedir.', 'IT-Hesap', 'İstanbul', 'assigned',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'pelin.ozcan@sirket.com', 'customer', 'İstanbul merkeze aynı anda başlayan 6 yeni personele Microsoft 365 Business Standard lisanslarının atanması ve Teams hesaplarının açılması gerekmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Hesap', 'oncelik', 'medium', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Hesap', 'İstanbul merkeze aynı anda başlayan 6 yeni personele Microsoft 365 Business Standard lisanslarının atanması ve Teams hesaplarının açılması gerekmektedir.', 'Entra ID (Azure AD) üzerinden 6 kullanıcıya toplu lisans ataması yapılarak Teams, OneDrive ve Exchange Online erişimleri açıldı.', true);

    ---------------------------------------------------------------------------
    -- [118/120] Sakarya Ofisi Dağıtım Listesi (DL) Sahiplik Değişikliği
    INSERT INTO users (email, full_name, role, region)
    VALUES ('kemal.arslan@sirket.com', 'Kemal Arslan', 'customer', 'Sakarya')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'mustafa.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'E-Posta / Dağıtım Grubu Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'medium' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'kemal.arslan@sirket.com', v_user_id, 'btdestek@sirket.com', 'Sakarya Ofisi Dağıtım Listesi (DL) Sahiplik Değişikliği',
        'Sakarya ''uretim-bildirim@sirket.com'' dağıtım listesinin sahibi şirketten ayrıldığı için yeni bir sahip atanması ve üye listesinin güncellenmesi gerekmektedir.', 'IT-Hesap', 'Sakarya', 'resolved',
        'medium', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'kemal.arslan@sirket.com', 'customer', 'Sakarya ''uretim-bildirim@sirket.com'' dağıtım listesinin sahibi şirketten ayrıldığı için yeni bir sahip atanması ve üye listesinin güncellenmesi gerekmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Hesap', 'oncelik', 'medium', 'region', 'Sakarya')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Hesap', 'Sakarya ''uretim-bildirim@sirket.com'' dağıtım listesinin sahibi şirketten ayrıldığı için yeni bir sahip atanması ve üye listesinin güncellenmesi gerekmektedir.', 'Exchange Online''da dağıtım listesinin ownership''i yeni üretim müdürüne aktarıldı, eski personel listeden çıkarıldı.', true);

    ---------------------------------------------------------------------------
    -- [119/120] Yozgat Personeli Azure AD Conditional Access Blokajı
    INSERT INTO users (email, full_name, role, region)
    VALUES ('tayfun.bilgin@sirket.com', 'Tayfun Bilgin', 'customer', 'Yozgat')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'turgut.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'Kullanıcı Hesabı Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'high' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'tayfun.bilgin@sirket.com', v_user_id, 'btdestek@sirket.com', 'Yozgat Personeli Azure AD Conditional Access Blokajı',
        'Yozgat fabrikasında kişisel telefonundan e-postaya erişmeye çalışan personel ''Koşullu erişim politikası tarafından engellendi'' hatası almaktadır.', 'IT-Hesap', 'Yozgat', 'assigned',
        'high', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'tayfun.bilgin@sirket.com', 'customer', 'Yozgat fabrikasında kişisel telefonundan e-postaya erişmeye çalışan personel ''Koşullu erişim politikası tarafından engellendi'' hatası almaktadır.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Hesap', 'oncelik', 'high', 'region', 'Yozgat')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Hesap', 'Yozgat fabrikasında kişisel telefonundan e-postaya erişmeye çalışan personel ''Koşullu erişim politikası tarafından engellendi'' hatası almaktadır.', 'Intune uyumluluk politikası incelendi, cihaz Intune''a kaydedilerek compliant hale getirildi ve erişim sağlandı.', true);

    ---------------------------------------------------------------------------
    -- [120/120] Doğum İzni Süresince Geçici E-Posta Yönlendirme Talebi
    INSERT INTO users (email, full_name, role, region)
    VALUES ('ik@sirket.com', 'Ik', 'customer', 'İstanbul')
    ON CONFLICT (email) DO UPDATE SET region = EXCLUDED.region
    RETURNING id INTO v_user_id;

    SELECT id INTO v_agent_id FROM users WHERE email = 'mustafa.teknoloji@sirket.com' LIMIT 1;
    SELECT id INTO v_group_id FROM support_groups WHERE name = 'BT Destek Ekibi' LIMIT 1;
    SELECT id INTO v_subcat_id FROM alt_kategoriler WHERE name = 'E-Posta / Dağıtım Grubu Talebi' LIMIT 1;
    v_sap_id := NULL;
    SELECT id INTO v_sla_id FROM sla_policies WHERE priority_key = 'low' LIMIT 1;

    INSERT INTO tickets (
        customer_email, customer_id, recipient_email, subject,
        raw_issue_description, extracted_category, region, status,
        priority, assigned_group_id, assigned_agent_id, sub_category_id,
        sap_module_id, sla_policy_id
    ) VALUES (
        'ik@sirket.com', v_user_id, 'btdestek@sirket.com', 'Doğum İzni Süresince Geçici E-Posta Yönlendirme Talebi',
        'İstanbul İK biriminden doğum iznine ayrılan personelin gelen e-postalarının 4 ay süreyle yerine bakan kişiye otomatik yönlendirilmesi talep edilmektedir.', 'IT-Hesap', 'İstanbul', 'resolved',
        'low', v_group_id, v_agent_id, v_subcat_id,
        v_sap_id, v_sla_id
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, sender_email, sender_type, message_body)
    VALUES (v_ticket_id, 'ik@sirket.com', 'customer', 'İstanbul İK biriminden doğum iznine ayrılan personelin gelen e-postalarının 4 ay süreyle yerine bakan kişiye otomatik yönlendirilmesi talep edilmektedir.') RETURNING id INTO v_msg_id;

    INSERT INTO routing_logs (ticket_id, decision_factors, assigned_group_id, assigned_agent_id, confidence_score)
    VALUES (v_ticket_id, json_build_object('modul', 'IT-Hesap', 'oncelik', 'low', 'region', 'İstanbul')::jsonb, v_group_id, v_agent_id, 0.95);

    INSERT INTO ticket_solutions (ticket_id, category, problem_text, solution_text, is_verified)
    VALUES (v_ticket_id, 'IT-Hesap', 'İstanbul İK biriminden doğum iznine ayrılan personelin gelen e-postalarının 4 ay süreyle yerine bakan kişiye otomatik yönlendirilmesi talep edilmektedir.', 'Exchange Online üzerinden mail flow transport rule ile otomatik yönlendirme kuralı 4 aylık bitiş tarihiyle oluşturuldu.', true);

    ---------------------------------------------------------------------------
    RAISE NOTICE '120 adet ticket başarıyla oluşturuldu!';
END $$;