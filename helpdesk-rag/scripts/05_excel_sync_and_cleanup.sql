-- ============================================================================
-- Excel'deki (tickets_125_notlara_gore_guncel.xlsx) 116 ticket'i DB'ye isle.
--
-- ONEMLI BULGU: Excel bu 116 ticket'in KENDI ticket_id'sini tasiyor, ama
-- daha once calisan subject-bazli dedup SQL'i (cleanup_sahte_agent_kopyalari.sql)
-- her subject grubunda "en eski" satiri tuttugu icin, Excel'in orijinal
-- DISTINCT ON sorgusunun sectiginden FARKLI bir fiziksel satiri tutmus olabilir.
-- 116 satirin sadece 45'i ticket_id ile birebir eslesiyordu; geri kalan 71'i
-- decision_factors + subject icerigine bakilarak DB'deki doGRU fiziksel
-- satiya (dogru id'ye) eslendi. Bu yuzden asagidaki tabloda ESLESEN gercek
-- DB id'si kullaniliyor -- Excel'in kendi ticket_id kolonu DEGIL.
--
-- Guncellenen kolonlar (sadece halihazirda DB'de olanlar):
--   tickets: subject, raw_issue_description, region, extracted_category,
--            assigned_agent_id, assigned_group_id, updated_at
--   routing_logs: assigned_agent_id, assigned_group_id
--
-- BILEREK DOKUNULMAYAN kolonlar: created_at, decision_factors,
-- confidence_score, is_overridden_by_human, correct_group_id -- bunlar o
-- FIZIKSEL satirin kendi orijinal/tarihi degerleri, Excel'deki (farkli bir
-- kopyadan gelen) degerle degistirilmesi anlam ifade etmiyor.
--
-- Excel'de olmayip hala 9 sahte agent'a bagli kalan 13 ticket (hicbir
-- Excel satiriyla eslesmiyor -- gozden gecirilmemis fazlalik/yeni kayit)
-- ADIM 3'te silinecek.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- ADIM 1 -- Guncelleme haritasini gecici tabloya koy
-- ----------------------------------------------------------------------------
BEGIN;

CREATE TEMP TABLE tmp_ticket_updates (
    db_ticket_id        uuid PRIMARY KEY,
    new_subject          text,
    new_raw_description  text,
    new_region           text,
    new_category         text,
    new_agent_id         uuid,
    new_group_id         uuid
);

INSERT INTO tmp_ticket_updates
    (db_ticket_id, new_subject, new_raw_description, new_region, new_category, new_agent_id, new_group_id)
VALUES
  ('746c02e7-63b9-494b-98e0-92057c61901f'::uuid, 'Çalışmıyor Sistem', 'SAP ekranı açılmıyor, garip karakterler çıkıyor ekranda.', 'Ankara', 'IT-Donanim', '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('711ccde9-713e-497c-a4b8-1c0d27a39429'::uuid, 'Ankara Dosya Sunucusuna Erişilemiyor', 'Ankara ofisindeki ortak dosya sunucusuna (paylaşım klasörlerine) kimse bağlanamıyor, ''\\fileserver'' adresi ulaşılamıyor hatası veriyor.', 'Ankara', 'IT-Donanim', '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('47275353-1d4b-4afd-8427-e8aff7f29a7f'::uuid, 'Sakarya Dosya Sunucusuna Erişilemiyor', 'Sakarya ofisindeki ortak dosya sunucusuna (paylaşım klasörlerine) kimse bağlanamıyor, ''\\fileserver'' adresi ulaşılamıyor hatası veriyor.', 'Sakarya', 'IT-Donanim', 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('6101b9d6-4ebe-4ac6-b217-eb94c71b1c95'::uuid, 'Ar-Ge Departmanı SAP''a Erişemiyor', 'İstanbul lokasyonundaki Ar-Ge departmanındaki tüm arkadaşlar SAP''a giriş yapamıyor, ''Kullanıcı oturumu sonlandırıldı'' hatası alıyorlar. Sadece bizim departman etkilendi.', 'İstanbul', 'SAP-Basis', '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('9fba8828-0cbc-4133-a8b3-c3e2313486de'::uuid, 'Bildirim Sesleri Gelmiyor', 'Merhaba, bilgisayarımdan hiçbir bildirim veya sistem sesi gelmiyor, ses seviyesi açık görünüyor. Kolay gelsin.', 'Yozgat', 'IT-Donanim', '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('7226249d-07de-44a6-8ea5-2c69feea3ed8'::uuid, 'Bilgisayar Açılmıyor', 'Sabah geldiğimde bilgisayarım açılmadı, güç düğmesine bastığımda fan sesi geliyor ama ekran hiç gelmioyr.', 'İstanbul', 'IT-Donanim', '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('5f3187ab-8651-409e-9d70-2f610fb14509'::uuid, 'Bilgisayar Ağına Erişim Sorunu', 'Bilgisayarım internete bağlanmıyor, kablo takılı ama ''sınırlı bağlantı'' yazıyor, diğer arkadaşlarımda sorun yok. Teşekkürler.', 'İstanbul', 'IT-Donanim', '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('ee5e9976-8cf7-4b6f-9f23-53ba76f494f2'::uuid, 'Bilgisayarım Beklenmedik Şekilde Kapanıyor', 'Gün içinde bilgisayarım rastgele kendi kendine kapanıp açılıyor, bir uyarı vermeden.', 'Ankara', 'IT-Donanim', '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('9701704a-0d86-4e30-9346-0a163dcbc30a'::uuid, 'Bilgisayarım Yavaş Çalışıyor', 'Son birkaç haftadır bilgisayarım açılışta ve programlar arası geçişte çok yavaş, sabrım taşıyor artık.', 'İstanbul', 'IT-Donanim', '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('ff3d9af5-6a98-4ec8-b075-5fb54883d486'::uuid, 'Bilgisayar Meselesi', 'Geçen sene de böyle bir sorun olmuştu hatırlarsanız, o zaman da uğraşmıştık, neyse şimdi yine benzer bir şey oluyor sanırım, tam olarak neyin bozuk olduğunu bilmiyorum ama genel olarak bir yavaşlık var her yerde, umarım anlatabilmişimdir durumu.', 'Ankara', 'IT-Donanim', '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('2427553d-b9a4-4d57-ae39-37177c631822'::uuid, 'Bilgisayar Sorunu', 'Bilgisayarım çok yavaş açılıyor, bakabilir misiniz.', 'İstanbul', 'IT-Donanim', 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('d8ba8399-7a58-40b8-ae76-02cbb2e69f80'::uuid, 'Bilgi Teknolojileri - Birden Fazla Kullanıcı Ağa Bağlanamıyor', 'Sakarya ofisinde Bilgi Teknolojileri departmanındaki neredeyse herkesin kablolu ağ bağlantısı düşüp kalkıyor, iş yapamıyoruz.', 'Sakarya', 'IT-Donanim', 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('f60a76cf-6bf1-49e8-a7d9-02c7e4edfc6f'::uuid, 'Bilgi Teknolojileri Departmanı SAP''a Erişemiyor', 'İstanbul lokasyonundaki Bilgi Teknolojileri departmanındaki tüm arkadaşlar SAP''a giriş yapamıyor, ''Kullanıcı oturumu sonlandırıldı'' hatası alıyorlar. Sadece bizim departman etkilendi.', 'İstanbul', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('43a6b3b1-b2c8-4b9a-84e4-45aa49ae1c4c'::uuid, 'Sakarya Ofisine Yeni Yazıcı Tanımlanması', 'Sakarya ofisine yeni gelen yazıcının ağa tanımlanıp kullanıma açılması gerekiyor.', 'Sakarya', 'IT-Ag', 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('de891d2c-5aa4-40a5-995e-47f5e21cee92'::uuid, 'CO01 (Üretim Emri) İçin Ek Yetki Talebi', 'CO01 (Üretim Emri) ekranında sadece görüntüleme yetkim var, işlem yapabilmem için ek yetki gerekiyor.', 'Yozgat', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('a5236694-4a69-42c0-95a9-5bbb95c02913'::uuid, 'CO01 (Üretim Emri) Kaydetme Sırasında Kilitleniyor', 'CO01 (Üretim Emri) ekranında kaydet dediğim anda ekran donuyor ve birkaç dakika beklemem gerekiyor.', 'Yozgat', 'SAP-CO', '54195b9f-ad77-4780-8147-38559d459fc2'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('383b3500-a4a1-4244-b904-f7082e447485'::uuid, 'CO01 (Üretim Emri) Üzerinde Yeni Rapor Geliştirme Talebi', 'Muhasebe departmanı için CO01 (Üretim Emri) ekranına bağlı özel bir stok raporu geliştirilmesini talep ediyoruz.', 'Ankara', 'SAP-CO', '54195b9f-ad77-4780-8147-38559d459fc2'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('d7890f59-c266-4520-b881-5de71ed9f685'::uuid, 'Bilgisayar Sorunu', 'Merhaba, bilgisayarım bu sabahtan beri çalışmıyor, en kısa sürede yardımcı olabilir misiniz, teşekkürler.', 'İstanbul', 'IT-Donanim', 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('7dbc7c05-aa2f-4490-8ae3-a019b89454e4'::uuid, 'Yozgat Ofisine Yeni Yazıcı Tanımlanması', 'Yozgat ofisine yeni gelen yazıcının ağa tanımlanıp kullanıma açılması gerekiyor.', 'Yozgat', 'IT-Donanim', '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('6451f2b0-9142-4ab7-8b07-2de59cfb9407'::uuid, 'Dosya Sistemi Yetki Talebi', 'Ortak klasördeki ''Bütçe 2026'' dizinine erişim yetkim yok, projem için gerekli, ekleyebilir misiniz?', 'Ankara', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('9b24628c-3c49-4384-8be8-66e302cfab8d'::uuid, 'Eğitim Salonu İçin Teknik Donanım Desteği', '23 Kasım 2026 tarihinde eğitim salonunda düzenlenecek toplantı için projeksiyon ve ses sistemi kurulumu talep ediyoruz.', 'İstanbul', 'IT-Donanim', '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('ad655ea0-f586-4635-b0ad-2061ff59449e'::uuid, 'Ekran Çözünürlüğü Bozuldu', 'Bilgisayarı açtığımda ekran görüntüsü çok büyük geliyor, çözünürlük değişmiş gibi.', 'Ankara', 'IT-Donanim', '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('1fa507cf-3ca0-474e-9a1f-eab4acbaa6e9'::uuid, 'Ekranda Yatay Çizgiler Var', 'Monitörümde belirli aralıklarla yatay renkli çizgiler beliriyor, çalışmayı zorlaştırıyor.', 'İstanbul', 'IT-Donanim', 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('fcb9a22d-f75d-4537-9934-42b3058a21c2'::uuid, 'İstanbul Dosya Sunucusuna Erişilemiyor', 'İstanbul ofisindeki ortak dosya sunucusuna (paylasim klasorlerine) kimse baglanamiyor, ''\\fileserver'' adresi ulasilamiyor hatasi veriyor.', 'İstanbul', 'IT-Donanim', '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('26d5ee3f-8b2f-44c8-a28c-a6f534c8524d'::uuid, 'Excel Makrosu Hata Veriyor', 'Aylık raporda kullandığım makro çalıştığında ''Run-time error 1004'' hatsaı veriyro, dün sorunsuzdu.', 'İstanbul', 'IT-Donanim', 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('ee530a4a-c245-4ab5-b254-ed85dca1cf2c'::uuid, 'Excel Tablo Sorunu', 'Excel dosyasındaki tabloda hücreler birbirine karışmış, sıralama ve filtreleme düzgün çalışmıyor, veriler yanlış görünüyor.', 'Ankara', 'IT-Donanim', '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('65d1531f-401e-405b-8809-1611fd72d28f'::uuid, 'Fare Bazen Tepki Vermiyor', 'Merhabalar, kablosuz farem bazen brikaç saniye tepki vremiyor, sonra normale dönüyor.', 'Ankara', 'IT-Donanim', '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('9b802679-8c60-4ce0-9fdc-b5e90e11edc1'::uuid, 'FB60 (Satıcı Faturası) İçin Ek Yetki Talebi', 'FB60 (Satıcı Faturası) ekranında sadece görüntüleme yetkim var, işlem yapabilmem için ek yetki gerekiyor.', 'Yozgat', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('a134b2ed-1870-4e56-a8fd-6555b96cfaf4'::uuid, 'FB60 (Satıcı Faturası) Kaydetme Sırasında Kilitleniyor', 'FB60 (Satıcı Faturası) ekranında kaydet dediğim anda ekran donuyor ve birkaç dakika beklemem gerekiyor.', 'Yozgat', 'SAP-FI', '9e25d672-0cf8-451d-981a-d10530a30c5b'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('e12b8285-04e5-429c-8df4-15455eea1e91'::uuid, 'FB60 (Satıcı Faturası) Üzerinde Yeni Rapor Geliştirme Talebi', 'Satış departmanı için FB60 (Satıcı Faturası) ekranına bağlı özel bir stok raporu geliştirilmesini talep ediyoruz.', 'Yozgat', 'SAP-FI', '9e25d672-0cf8-451d-981a-d10530a30c5b'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('03339dca-99f2-4019-bb5b-21567c16a8b6'::uuid, 'FBL5N (Müşteri Hesap Ekstresi) İçin Ek Yetki Talebi', 'Merhaba,

fBL5N (Müşteri Hesap Ekstresi) ekranında sadece görüntüleme yetkim var, işlem yapabilmem için ek yetki gerekiyor.', 'Ankara', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('a6d46c3e-6a27-44da-8213-03a245df3b53'::uuid, 'FBL5N (Müşteri Hesap Ekstresi) Kaydetme Sırasında Kilitleniyor', 'FBL5N (Müşteri Hesap Ekstresi) ekranında kaydet dediğim anda ekran donuyor ve birkaç dakika beklemem gerekiyor.', 'Yozgat', 'SAP-FI', '9e25d672-0cf8-451d-981a-d10530a30c5b'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('a907778f-c918-48cb-bd44-0d5be8a94910'::uuid, 'FBL5N (Müşteri Hesap Ekstresi) Üzerinde Yeni Rapor Geliştirme Talebi', 'İyi günler, satış departmanı için FBL5N (Mşüteri Hesap Ekstresi) ekranına bağlı özle bir stok raporu geliştirilmesini talep ediyoruz.', 'Ankara', 'SAP-FI', '9e25d672-0cf8-451d-981a-d10530a30c5b'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('3afc2e8c-a3e0-43df-9729-ac696d623484'::uuid, 'Finans - Birden Fazla Kullanıcı Ağa Bağlanamıyor', 'İstanbul ofisinde Finans departmanındaki neredeyse herkesin kablolu ağ bağlantısı düşüp kalkıyor, iş yapamıyoruz.', 'İstanbul', 'IT-Donanim', 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('eb5f4461-fb5b-4c09-a027-06cac63bd478'::uuid, 'Finans Departmanı SAP''a Erişemiyor', 'Sakarya lokasyonundaki Finans departmanındaki tüm arkadaşlar SAP''a giriş yapamıyor, ''Kullanıcı oturumu sonlandırıldı'' hatası alıyorlar. Sadece bizim departman etkilendi.', 'Sakarya', 'SAP-Basis', '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('9f477304-88bc-43a4-988c-84f11cff1c47'::uuid, 'Sakarya Ofisine Yeni Yazıcı Tanımlanması', 'Sakarya ofisine yeni gelen yazıcının ağa tanımlanıp kullanıma açılması gerekiyor.', 'Sakarya', 'IT-Donanim', 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('80480fa2-6b30-44e0-aebf-5c8014431b81'::uuid, 'İnsan Kaynakları - Birden Fazla Kullanıcı Ağa Bağlanamıyor', 'İstanbul ofisinde İnsan Kaynakları departmanındaki neredeyse herkesin kablolu ağ bağlantısı düşüp kalkıyor, iş yapamıyoruz.', 'İstanbul', 'IT-Donanim', 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('eaeaff5e-4058-49ac-8621-54cd512e357b'::uuid, 'İnsan Kaynakları Departmanı SAP''a Erişemiyor', 'Sakarya lokasyonundaki İnsan Kaynakları departmanındaki tüm arkadaşlar SAP''a giriş yapamıyor, ''Kullanıcı oturumu sonlandırıldı'' hatası alıyorlar. Sadece bizim departman etkilendi.', 'Sakarya', 'SAP-Basis', '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('eb7fae5a-2c3d-406c-a58c-bfaa0857f330'::uuid, 'İstanbul Dosya Sunucusuna Erişilemiyor', 'İstanbul ofisindeki ortak dosya suncuusuna (paylaşım klasörlerine) kimse bağlanamıyor, ''\\fileserver'' adresi ulaşılamıyor htaası veriyor.', 'İstanbul', 'IT-Donanim', '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('6992d751-6b9f-4bee-833d-ec8e6e7bfab9'::uuid, 'Yozgat Dosya Sunucusuna Erişilemiyor', 'Yozgat ofisindeki ortak dosya sunucusuna (paylaşım klasörlerine) kimse bağlanamıyor, ''\\fileserver'' adresi ulaşılamıyor hatası veriyor.', 'Yozgat', 'IT-Donanim', '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('443cf54b-3753-4634-b38c-6df84c1bf959'::uuid, 'Kalite Kontrol - Birden Fazla Kullanıcı Ağa Bağlanamıyor', 'İstanbul ofisinde Kalite Kontrol departmanındaki neredeyse herkesin kablolu ağ bağlantısı düşüp kalkıyor, iş yapamıyoruz.', 'İstanbul', 'IT-Donanim', '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('f0e9e61a-9263-40f4-b5a5-1af618ea750b'::uuid, 'Kalite Kontrol Departmanı SAP''a Erişemiyor', 'Sakarya lokasyonundaki Kalite Kontrol departmanındaki tüm arkadaşlar SAP''a giriş yapamıyor, ''Kullanıcı oturumu sonlandırıldı'' hatası alıyorlar. Sadece bizim departman etkilendi.', 'Sakarya', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('cc4a8a49-e1a7-4662-8938-beaf8f2e5bdf'::uuid, 'Yozgat Ofisine Yeni Yazıcı Tanımlanması', 'Yozgat ofisine yeni gelen yazıcının ağa tanımlanıp kullanıma açılması gerekiyor.', 'Yozgat', 'IT-Donanim', '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('14597059-a9b5-4d9d-8ef4-8c13ebbb4774'::uuid, 'Klavye Bazı Tuşları Basmıyor', 'Klavyemde ''a'' ve ''s'' tuşları bazen basılı kalıyor, yazı yazarken çok sorun yaşıyorum.', 'Yozgat', 'IT-Donanim', '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('20c2727c-7a3a-402e-9564-82f2e8181175'::uuid, 'Klavye Dili İngilizce Geldi', 'Bilgisayarımı açtığımda klavye dili Türkçe yerine İngilizce (US) geliyor, Türkçe karakterleri yazamıyorum.', 'İstanbul', 'IT-Donanim', 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('19f9af63-fe7b-4476-89c7-50ed255c5528'::uuid, 'Sakarya Dosya Sunucusuna Erişilemiyor', 'Merhaba,

sakarya ofisindeki ortak dosya sunucusuna (paylaşım klasörlerine) kimse bağlanamıyor, ''\\fileserver'' adresi ulaşılamıyor hatası veriyor.', 'Sakarya', 'IT-Donanim', 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('6689e7b0-29f0-47d2-8f2e-52d526f06129'::uuid, 'Ankara Ofisine Yeni Yazıcı Tanımlanması', 'Ankara ofisine yeni gelen yazıcının ağa tanımlanıp kullanıma açılması gerekiyor. Teşekkürler.', 'Ankara', 'IT-Donanim', '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('defb923a-2b9a-4d70-a219-ef907133e6bb'::uuid, 'Kritik Veritabanı Sunucusunda Donanım Arızası', 'DB sunucusundan (DB-PRD-01) srüekli disk hatası uyarıları geliyor, SAP ve raporlama sistemleri buna bağlı olduğu için tüm holding etkilenebilir.', 'Ankara', 'SAP-Basis', '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('80d45493-f678-49d1-a08e-1576499e6e4c'::uuid, 'Kullanıcı Şifre Değiştirme İsteği', 'Şifremi hatırlamıyorum, sıfırlanmasını rica ederim.', 'Ankara', 'IT-Hesap', '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('db05be94-67ef-43bc-8fee-22a22c891cb9'::uuid, 'Lojistik - Birden Fazla Kullanıcı Ağa Bağlanamıyor', 'Yozgat ofisinde Lojistik departmanındaki neredeyse herkesin kablolu ağ bağlantısı düşüp kalkıyor, iş yapamıyoruz.', 'Yozgat', 'IT-Donanim', '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('9cd70d0e-d4c0-42a6-9529-e61d5a0ae143'::uuid, 'Lojistik Departmanı SAP''a Erişemiyor', 'İstanbul lokasyonundaki Lojistik departmanındaki tüm arkadaşlar SAP''a giriş yapamıyor, ''Kullanıcı oturumu sonlandırıldı'' hatası alıyorlar. Sadece bizim departman etkilendi.', 'Yozgat', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('92204beb-aa10-4f2a-9f11-99e41bb5f95e'::uuid, 'İstanbul Dosya Sunucusuna Erişilemiyor', 'İstanbul ofisindeki ortak dosya sunucusuna (paylaşım klasörlerine) kimse bağlanamıyor, ''\\fileserver'' adresi ulaşılamıyor hatası veriyor.', 'İstanbul', 'IT-Donanim', '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('e501664f-8636-4974-b069-779ec4e03d61'::uuid, 'Sakarya Ofisine Yeni Yazıcı Tanımlanması', 'Sakarya ofisine yeni gelen yazıcının ağa tanımlanıp kullanıma açılması gerekiyor.', 'Sakarya', 'IT-Donanim', 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('db36d067-c401-4f86-a523-c5644949606f'::uuid, 'Masaüstü Kısayolları Görülmüyor', 'Selam, bilgisayarımı yeniden başlattıktan sonra masaüstündeki tüm kısayol simgeleri kayboldu.', 'Ankara', 'IT-Donanim', '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('dad54fec-646b-4a23-a14b-022bc20dab2d'::uuid, 'MB52 (Depo Stok Listesi) İçin Ek Yetki Talebi', 'İyi günler, mB25 (Depo Stok Listesi) ekranında sadece görüntüleme yetkim var, işlem yaapbilmem için ek yetki gerekiyor.', 'Sakarya', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('2f6c1a02-379c-4c24-b607-c10db9494f54'::uuid, 'MB52 (Depo Stok Listesi) Kaydetme Sırasında Kilitleniyor', 'MB52 (Depo Stok Listesi) ekranında kaydet dediğim anda ekran donuyor ve birkaç dakika beklemem gerekiyor.', 'Ankara', 'SAP-WM', '68f7cf53-5de5-41d5-a6f5-cfa527a96871'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('fdc704f8-b2e3-4de2-8f90-4588efd08485'::uuid, 'MB52 (Depo Stok Listesi) Üzerinde Yeni Rapor Geliştirme Talebi', 'Kalite Kontrol departmanı için MB52 (Depo Stok Listesi) ekranına bağlı özel bir stok raporu geliştirilmesini talep ediyoruz.', 'Yozgat', 'SAP-MM', 'd452be79-656c-4651-817d-1a200da15727'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('20f1450e-be4c-44f9-ab2f-bcc00b65d81c'::uuid, 'ME21N (Satınalma Siparişi) Kaydetme Sırasında Kilitleniyor', 'ME21N (Satinalma Siparisi) ekraninda kaydet dedigim anda ekran donuyor ve birkac dakika beklemem gerekiyor.', 'Sakarya', 'SAP-MM', '68f7cf53-5de5-41d5-a6f5-cfa527a96871'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('b1aa9397-9e36-4d23-ab24-dbaf5338d847'::uuid, 'ME51N (Satınalma Talebi) Ekranında Hata Alıyorum', 'Merhaba,

mE51N (Satınalma Talebi) ekranında işlem yapmaya çalışırken ''TIMEOUT 0x80070026'' hata kodu ile karşılaşıyorum, işlemi tamamlayamıyorum.', 'Ankara', 'SAP-MM', '68f7cf53-5de5-41d5-a6f5-cfa527a96871'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('2995cab9-033c-48d0-bf21-a8eaf6a8d78b'::uuid, 'ME51N (Satınalma Talebi) İçin Ek Yetki Talebi', 'ME51N (Satınalma Talebi) ekranında sadece görüntüleme yetkim var, işlem yapabilmem için ek yetki gerekiyor. Kolay gelsin.', 'Yozgat', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('db8531ad-11a1-4d08-b6f4-e54d48233167'::uuid, 'ME51N (Satınalma Talebi) Kaydetme Sırasında Kilitleniyor', 'ME51N (Satınalma Talebi) ekranında kaydet dediğim anda ekran donuyor ve birkaç dakika beklemem gerekiyor. Acil bakabilir misiniz?', 'Ankara', 'SAP-MM', '68f7cf53-5de5-41d5-a6f5-cfa527a96871'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('8cedc7f6-4778-48ee-b3cc-3da5832db386'::uuid, 'ME51N (Satınalma Talebi) Üzerinde Yeni Rapor Geliştirme Talebi', 'Finans departmanı için ME51N (Satınalma Talebi) ekranına bağlı özel bir stok raporu geliştirilmesini talep ediyoruz.', 'Sakarya', 'SAP-MM', 'd452be79-656c-4651-817d-1a200da15727'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('2c7bbb2a-44e9-4238-8bb8-eedd56626b83'::uuid, 'Merkez Firewall Arızası - Tüm Lokasyonlar Etkilendi', 'İstanbul ve bağlı tüm şubelerde internet ve VPN erişimi kesildi. Ana firewall cihazının panel ışıkları kırmızı yanıyor, hiçbir trafik geçmiyor.', 'İstanbul', 'IT-Donanim', 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('b1067fca-6a6c-4aff-b4b0-01dd749faf4f'::uuid, 'MIGO (Mal Girişi) İçin Ek Yetki Talebi', 'MIGO (Mal Girişi) ekranında sadece görüntüleme yetkim var, işlem yapabilmem için ek yetki gerekiyor.', 'Ankara', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('d5507cb1-43ff-4342-a44b-2fda3e0cf06b'::uuid, 'MIGO (Mal Girişi) Kaydetme Sırasında Kilitleniyor', 'Merhaba, mIGO (Mal Girişi) ekranında kaydet dediğim anda ekran donuyor ve birkaç dakika beklemem gerekiyor', 'Sakarya', 'SAP-MM', 'd452be79-656c-4651-817d-1a200da15727'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('046b01bb-7180-4f92-ad20-8fee592a9b97'::uuid, 'MMBE (Stok Görüntüleme) İçin Ek Yetki Talebi', 'MMBE (Stok Görüntüleme) ekranında sadece görüntüleme yetkim var, işlem yapabilmem için ek yetki gerekiyor. Kolay gelsin.', 'İstanbul', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('2cef2b18-923e-4c68-8e71-da1e9fbf4979'::uuid, 'MMBE (Stok Görüntüleme) Kaydetme Sırasında Kilitleniyor', 'MMBE (Stok Görüntüleme) ekranında kaydet dediğim anda ekran donuyor ve birkaç dakika beklemem gerekiyor.', 'Yozgat', 'SAP-MM', 'd452be79-656c-4651-817d-1a200da15727'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('575634d0-bafd-42a4-aed8-d633fded25d6'::uuid, 'MMBE (Stok Görüntüleme) Üzerinde Yeni Rapor Geliştirme Talebi', 'Depo departmanı için MMBE (Stok Görüntüleme) ekranına bağlı özel bir stok raporu geliştirilmesini talep ediyoruz.', 'Sakarya', 'SAP-MM', '68f7cf53-5de5-41d5-a6f5-cfa527a96871'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('5a25b9c7-f000-4243-9030-823833249cba'::uuid, 'Mobil E-posta Senkronizasyon Hatası', 'Merhaba,

telefonumda mail bazen 1-2 saat gecikmeli geliyor, senkronizasyon aralığı ile ilgili olabilir mi?', 'İstanbul', 'IT-Donanim', 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('9525d897-4e70-4c5e-82d9-c6470ea27a55'::uuid, 'Monitör Görüntü Vermiyor', 'Çift monitörümden biri sabahtan beri görüntü vermiyor, kablo bağlantılarını kontrol ettim ama ''No Signal'' yazıyor', 'Yozgat', 'IT-Donanim', '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('5ca7e42a-a911-49dd-b086-a15adc4ce83e'::uuid, 'Muhasebe - Birden Fazla Kullanıcı Ağa Bağlanamıyor', 'Yozgat ofisinde Muhasebe departmanındaki neredeyse herkesin kablolu ağ bağlantısı düşüp kalkıyor, iş yapamıyoruz.', 'Yozgat', 'IT-Donanim', '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('7e91886b-ce8a-42f0-ae20-ed3dca16768c'::uuid, 'Muhasebe Departmanı SAP''a Erişemiyor', 'Yozgat lokasyonundaik Muhasebe departmanındaki tüm arkadaşlar SAP''a giriş yapamıyor, ''Kullanıcı oturumu sonlandırıldı'' hatası alıyorlar. Sadece bizim departman etkilendi.', 'Yozgat', 'SAP-Basis', '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('a7826cff-b210-4073-a871-6be2b4c4244f'::uuid, 'Muhasebe E-Fatura Sistemine Bağlanamıyor', 'Muhasebe departmanı e-fatura entegrasyon ekranına bağlanamıyor, fatura kesimi duruyor, ay sonu olduğu için acil çözülmesi lazım.', 'Ankara', 'SAP-EFATURA', 'ee1245eb-bda3-4e19-8450-31173141f861'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('12188be8-3228-491e-8fe2-789e01450d10'::uuid, 'Müşteri Hizmetleri - Birden Fazla Kullanıcı Ağa Bağlanamıyor', 'Ankara ofisinde Müşteri Hizmetleri departmanındaki neredeyse herkesin kablolu ağ bağlantısı düşüp kalkıyor, iş yapamıyoruz.', 'Ankara', 'IT-Donanim', '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('071b3529-dbee-4c35-96df-f51aa711f37a'::uuid, 'Müşteri Hizmetleri Departmanı SAP''a Erişemiyor', 'İstanbul lokasyonundaki Müşteri Hizmetleri departmanındaki tüm arkadaşlar SAP''a giriş yapamıyor, ''Kullanıcı oturumu sonlandırıldı'' hatası alıyorlar. Sadece bizim departman etkilendi.', 'İstanbul', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('85fa01a0-571a-4f5b-9435-73b87b4ec897'::uuid, 'Ortak Klasör Paylaşım İzni Talebi', 'Merhaba, müşteri Hizmetleri departmanı için yeni bir proje klasörü oluşturulup ilgili ekibe paylaşım izni verilmesini rica ederiz.', 'Sakarya', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('464fa344-6429-4a61-a250-e2378588dff5'::uuid, 'Outlook E-posta Göndermiyor', 'Outlook üzerinden mail göndermeye çalıştığımda gönderilemedi hatası alıyorum, webmail üzerinden gönderebiliyorum.', 'İstanbul', 'IT-Donanim', '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('0b16cb34-8b3d-4272-b5a5-7b93a3d25464'::uuid, 'Outlook Sorunu', '<div>Merhaba</div><br><span style=''color:red''>Sorun var</span><signature>Ahmet Bey | Muhasebe</signature>', 'İstanbul', 'IT-Donanim', 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('45bcac01-7607-41d0-bde3-0099d7225863'::uuid, 'Pazarlama Departmanı SAP''a Erişemiyor', 'İstanbul lokasyonundaki Pazarlama departmanındaki tüm arkadaşlar SAP''a giriş yapamıyor, ''Kullanıcı oturumu sonlandırıldı'' hatası alıyorlar. Sadece bizim departman etkilendi.', 'İstanbul', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('5ebfc77c-0dbf-4a28-b7cc-1a1f9f08d5d2'::uuid, 'Saha Ekibi İçin Tablet Talebi', 'Saha ziyaretlerinde kullanmak üzere 3 adet tablet talep ediyoruz, satın alım süreci başlatılabilir mi?', 'Yozgat', 'IT-Donanim', '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('7d44c993-5269-4bc7-a759-039094d0505b'::uuid, 'Sakarya Ofisine Yeni Yazıcı Tanımlanması', 'Sakarya ofisine yeni gelen yazıcının ağa tanımlanıp kullanıma açılması gerekiyor.', 'Sakarya', 'IT-Donanim', 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('894e1bff-5991-4c69-a828-a52ee43635d7'::uuid, 'İstanbul Dosya Sunucusuna Erişilemiyor', 'İstanbul ofisindeki ortak dosya sunucusuna (paylaşım klasörlerine) kimse bağlanamıyor, ''\\fileserver'' adresi ulaşılamıyor hatası veriyor.', 'İstanbul', 'IT-Donanim', '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('22595943-2b49-4a60-a757-76cce9b6f833'::uuid, 'SAP Sistemine Hiç Kimse Giremiyor', 'Az önce farkettik, İstanbul lokasyonundaki tüm kullanıcılar SAP''a giriş yapamıyor. Ekranda ''Connection timed otu'' hatası çıkıyor, tüm departmanlar durud.', 'İstanbul', 'SAP-Basis', '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('763e9b4f-9615-4b19-b7bb-6ac5218a0814'::uuid, 'Şifre Sıfırlama', 'Şifremi unuttum sıfırlanabilir mi', 'Sakarya', 'IT-Hesap', '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('a75a4f80-d9c1-4209-8c55-03ed0e9d2ad1'::uuid, 'Şirket Telefonu Mail Almıyor', 'Telefonumda şirket mailim senkronize olmuyor, uygulama açılıyor ama gelen kutusu boş görünüyor.', 'Ankara', 'IT-Donanim', '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('9048a6c7-fbfa-41de-9f6b-e5efbf0ec063'::uuid, 'Şüpheli Fidye Yazılımı Uyarısı', 'Isik Koc kullanicisinin bilgisayarinda dosya isimlerinin sonuna bilinmeyen bir uzanti eklendigini ve masaustunde okuma talebi iceren bir not belirdigini fark ettik. Agdaki diger cihazlara sicramis olabilir.', 'Sakarya', 'IT-Guvenlik', 'd3bdaa4e-c353-4fd5-b358-09ac5476b912'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('693f0278-e160-4de1-936a-1b7e919936f2'::uuid, 'Teams Toplantısında Ses Gelmiyor', 'Teams toplantılarında karşı taraf beni duyamıyor, mikrofon simgesi açık görünse de ses gitmiyor.', 'Ankara', 'IT-Donanim', '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('0c570c1d-f390-4669-a929-0089cfedb20e'::uuid, 'Sakarya Ofisine Yeni Yazıcı Tanımlanması', 'Sakarya ofisine yeni gelen yazıcının ağa tanımlanıp kullanıma açılması gerekiyor.', 'Sakarya', 'IT-Donanim', 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('2b346668-529e-4a4c-bc51-b49d8bf11856'::uuid, 'Tüm İnternet Bağlantısı Kesildi', 'Sakarya ofisinde internet tamamen gitti, hiçbir cihaz dışarı çıkamıyor, telefon santralimiz de buna bağlı olduğu için aramalar da düşüyor.', 'Sakarya', 'IT-Donanim', 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('17d0dbd4-b75c-4f21-91d0-fb7c547e6d2d'::uuid, 'Tüm Şirket E-postaları Gitmiyor / Gelmiyor', 'Sabahtan beri hicbir departman mail gonderemiyor ve alamiyor. Outlook''ta da webmail''de de ayni sorun var, tum sirket etkilendi, cok acil.', 'Yozgat', 'IT-Donanim', '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('f8c497fd-7a23-4b09-89d1-9df8113e7855'::uuid, 'üretim teyiti sırasında aşağıdaki hatayla karşılaştım', 'üretim teyiti sırasında aşağıdaki hatayla karşılaştım', 'İstanbul', 'SAP-PP', 'f3144acb-ba7a-44b0-b1fc-ff5ed9185315'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('93516cf8-11b6-424d-b34d-282646aafa1c'::uuid, 'VA01 (Satış Siparişi) Ekranında Hata Alıyorum', 'VA01 (Satış Siparişi) ekranında işlem yapmaya çalışırken ''LICENSE_EXPIRED'' hata kodu ile karşılaşıyorum, işlemi tamamlayamıyorum.', 'İstanbul', 'SAP-SD', '2a1a849e-9db9-4cf7-a0f9-a6b652f5fefb'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('3ca5962b-dab8-4384-ba2e-04923b31ec1c'::uuid, 'VA01 (Satış Siparişi) İçin Ek Yetki Talebi', 'VA01 (Satış Siparişi) ekranında sadece görüntüleme yetkim var, işlem yapabilmem için ek yetki gerekiyor.', 'Sakarya', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('49564232-fedf-45bb-a242-64ea15db8867'::uuid, 'VA01 (Satış Siparişi) Kaydetme Sırasında Kilitleniyor', 'Merhaba, vA01 (Satış Siparişi) ekranında kaydet dediğim anda ekran donuyor ve birkaç dakika beklemem gerekiyor.', 'Yozgat', 'SAP-SD', '2a1a849e-9db9-4cf7-a0f9-a6b652f5fefb'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('b3d0efa5-1f7b-431a-b62c-f8def025db18'::uuid, 'VA01 (Satış Siparişi) Üzerinde Yeni Rapor Geliştirme Talebi', 'Merhaba, satış departmanı için VA01 (Satış Siparişi) ekranına bağlı özel bir stok raporu geliştirilmesini talep ediyoruz.', 'Yozgat', 'SAP-SD', '2a1a849e-9db9-4cf7-a0f9-a6b652f5fefb'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('3bf008a0-8ef0-42f5-8056-72e3eafc409d'::uuid, 'VF01 (Fatura Oluşturma) İçin Ek Yetki Talebi', 'İyi günler, vF01 (Fatura Oluşturma) ekranında sadece görüntüleme yetkim var, işlem yapabilmem için ek yetki gerekiyor.', 'Sakarya', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('2e8ec118-7986-4093-8dd7-6faf66b69459'::uuid, 'VF01 (Fatura Oluşturma) Kaydetme Sırasında Kilitleniyor', 'Merhaba, vF01 (Fatura Oluşturma) ekranında kaydet dediğim anda ekran donuyor ve birkaç dakika beklemem gerekiyor.', 'Ankara', 'SAP-FI', '9e25d672-0cf8-451d-981a-d10530a30c5b'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('271cf952-3d03-44d5-906c-15a4d5d8043f'::uuid, 'VF01 (Fatura Oluşturma) Üzerinde Yeni Rapor Geliştirme Talebi', 'İyi günler, finans departmanı için VF01 (Fatura Oluşturma) ekranına bağlı özel bir stok raporu geliştirilmesini talep ediyoruz.', 'Yozgat', 'SAP-FI', '9e25d672-0cf8-451d-981a-d10530a30c5b'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('3d0f4669-d6c4-4b81-8027-dd8c3a04403f'::uuid, 'VL01N (Teslimat) İçin Ek Yetki Talebi', 'VL01N (Teslimat) ekranında sadece görüntüleme yetkim var, işlem yapabilmem için ek yetki gerekiyor.', 'Sakarya', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('0aeaae63-5491-40a4-aae0-8513879848de'::uuid, 'VL01N (Teslimat) Kaydetme Sırasında Kilitleniyor', 'VL01N (Teslimat) ekranında kaydet dediğim anda ekran donuyor ve birkaç dakika beklemem gerekiyor.', 'Ankara', 'SAP-SD', '2a1a849e-9db9-4cf7-a0f9-a6b652f5fefb'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('856fc641-b20c-4892-8c69-48b37eb480d0'::uuid, 'VL01N (Teslimat) Üzerinde Yeni Rapor Geliştirme Talebi', 'Pazarlama departmani icin VL01N (Teslimat) ekranina bagli ozel bir stok raporu gelistirilmesini talep ediyoruz.', 'Ankara', 'SAP-SD', '2a1a849e-9db9-4cf7-a0f9-a6b652f5fefb'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('300fe1ac-946b-428b-b64e-f276733c8d59'::uuid, 'VPN Bağlantısı Çalışmıyor', 'Evden bağlanmaya çalışırken VPN sürekli ''bağlantı zaman aşımına uğradı'' diyor, dün sorunsuz çalışıyordu.', 'Sakarya', 'IT-Ag', 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('104641e8-be4d-44c8-95b4-51120eaa4756'::uuid, 'VPN Toplu Bağlantı Sorunu', 'Sakarya bölgesindeki saha ekibinin neredeyse tamamı VPN''e bağlanamıyor, ''Sertifika doğrulanamadı'' hatası alıyorlar.', 'Sakarya', 'IT-Ag', 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('5c7e7273-4c24-4d1f-b7c2-555f17d56105'::uuid, 'XD01 (Müşteri Oluşturma) İçin Ek Yetki Talebi', 'XD01 (Musteri Olusturma) ekraninda sadece goruntuleme yetkim var, islem yapabilmem icin ek yetki gerekiyor.', 'Yozgat', 'SAP-Yetki', '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('02930d08-c33d-4d84-b0d4-32e50605c4b1'::uuid, 'XD01 (Müşteri Oluşturma) Kaydetme Sırasında Kilitleniyor', 'XD01 (Müşteri Oluşturma) ekranında kaydet dediğim anda ekran donuyor ve birkaç dakika beklemem gerekiyor.', 'Sakarya', 'SAP-FI', '9e25d672-0cf8-451d-981a-d10530a30c5b'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('e5f25d8b-4da1-45c9-8434-a69d9782d60e'::uuid, 'Yazıcı Arızası', 'Yazıcı kağıt sıkıştırıyor sürekli.', 'Yozgat', 'IT-Donanim', '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('8102a0e7-ef57-4e44-9d9b-cf4094979745'::uuid, 'Yazıcı Bağlantısı Kopmuş', 'İstanbul ofisindeki yazıcıya çıktı gönderdiğimde ''yazıcı çevrimdışı'' uyarısı alıyorum, sadece ben etkilenmişim gibi görünüyor.', 'İstanbul', 'IT-Donanim', '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('f6fcabe2-c0d2-4b97-8fb4-b13ce71eb00a'::uuid, 'Yazıcıdan Ses Geliyor', 'Yazıcı kağıt çekerken tıkırtı sesi çıkarıyor ve kağıtları yamuk basıyor.', 'Ankara', 'IT-Donanim', '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('0a19e4e4-1c88-46ac-9ccb-f9e95fd51d09'::uuid, 'Yazıcı Toner Uyarısı Veriyor', 'Yazıcı ekranında ''toner az'' uyarısı çıkıyor, henüz baskı alabiliyorum ama bilginize.', 'İstanbul', 'IT-Donanim', '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('271b0d76-8bad-4aa3-8099-1aecff0f3638'::uuid, 'Yedekleme Sistemi Arızası', 'İyi günler, gece yedekleme işlerinin başarısız olduğuna dair uyarı e-postaları geliyor, aktif iş sürekliliği riks altında olabilir.', 'Sakarya', 'SAP-Basis', '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('3365d2f1-c8c0-4ef1-9681-cbaf8b2701d0'::uuid, 'Yeni Çalışan İçin Bilgisayar Kurulumu', '3 Mayıs 2026 tarihinde Pazarlama departmanına yeni bir arkadaşımız başlıyor, bilgisayar ve e-posta hesabı hazırlanması gerekiyor.', 'Ankara', 'IT-Donanim', '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('2e82bc68-9f59-4787-afd9-de60df7ee675'::uuid, 'Yeni Kullanıcı Oluşturma Talebi', 'Emre Aydın isimli yeni personelimiz için sistem kullanıcısı ve gerekli temel yetkilerin tanımlanmasını rica ederiz.', 'Yozgat', 'IT-Hesap', '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('957ed031-d1dd-4179-8fb2-3674cd70dc76'::uuid, 'Yeni Şube İçin Ağ Altyapısı Kurulumu', 'İstanbul bölgesinde açılacak yeni şube için internet ve yerel ağ altyapısının kurulmasını talep ediyoruz.', 'İstanbul', 'IT-Ag', 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('9ce845d9-ed32-4eec-a419-461df5359c2d'::uuid, 'Yeni Yazıcıya Bağlanamıyorum', 'Geçen hafta kurulan yeni yazıcıyı listede göremiyorum, ekleyebilir misiniz?', 'İstanbul', 'IT-Donanim', 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('31ae8382-203a-4833-a986-6e03a70b8a8e'::uuid, 'Yeni Yazılım Kurulum Talebi', 'Projemiz için Adobe Acrobat Pro lisansına ihtiyacımız var, kurulum yapılabilir mi?', 'İstanbul', 'IT-Donanim', 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('c0dd1195-2f82-4e11-ade8-c3d88f69996f'::uuid, 'VPN Sorunu', 'Merhaba, VPN bağlantım sürekli kopuyor, günde 10 kere bağlanmam gerekiyor, çok yoruldum artık bu durumdan, lütfen ilgilenir misiniz', 'İstanbul', 'IT-Ag', 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid);

-- kontrol: 116 olmali
SELECT count(*) FROM tmp_ticket_updates;


-- ----------------------------------------------------------------------------
-- ADIM 2 -- tickets ve routing_logs guncelle
-- ----------------------------------------------------------------------------
UPDATE tickets t
SET subject               = m.new_subject,
    raw_issue_description = m.new_raw_description,
    region                = m.new_region,
    extracted_category    = m.new_category,
    assigned_agent_id     = m.new_agent_id,
    assigned_group_id     = m.new_group_id,
    updated_at            = now()
FROM tmp_ticket_updates m
WHERE t.id = m.db_ticket_id;

UPDATE routing_logs rl
SET assigned_agent_id = m.new_agent_id,
    assigned_group_id = m.new_group_id
FROM tmp_ticket_updates m
WHERE rl.ticket_id = m.db_ticket_id;

-- kontrol: 116 ticket icin artik sahte agent kalmamali (0 donmeli)
SELECT count(*)
FROM tickets t
JOIN tmp_ticket_updates m ON m.db_ticket_id = t.id
WHERE t.assigned_agent_id <> m.new_agent_id OR t.assigned_group_id <> m.new_group_id;

SELECT count(*)
FROM routing_logs rl
JOIN tmp_ticket_updates m ON m.db_ticket_id = rl.ticket_id
WHERE rl.assigned_agent_id <> m.new_agent_id OR rl.assigned_group_id <> m.new_group_id;

-- Yukaridaki iki sayim da 0 ise ADIM 3'e gecin (hala BEGIN icindesiniz, commit etmeyin).


-- ----------------------------------------------------------------------------
-- ADIM 3 -- Excel'de karsiligi olmayan, hala 9 sahte agent'a bagli 13
-- fazlalik ticket'i sil (yedek onerilir, ADIM 3.0'a bakin)
-- ----------------------------------------------------------------------------

-- ADIM 3.0 -- (opsiyonel ama onerilir) commit etmeden once bu 13 satiri
-- ayri bir sorguyla yedekleyin:
--   SELECT * FROM tickets WHERE id IN (  ('224e8e8e-07db-462d-b986-4205b4059e19'::uuid),   ('c164b17e-c021-4d35-b20e-25f8a8dd3be6'::uuid),   ('859d96f2-bb33-4867-9d92-1ad510a67ee4'::uuid),   ('ad8f6bcc-343b-4953-88b1-79b3b7a4fa14'::uuid),   ('d14c94fe-1a8c-442f-9a05-137795855c28'::uuid),   ('fbb73a40-2fa2-4099-a5f3-78782e4d9a55'::uuid),   ('fecec3ff-7d78-43e1-95a1-7c98abe5e1a0'::uuid),   ('81dcc5d7-466d-4b55-b820-cf0888086104'::uuid),   ('c91d65bc-ea3c-412f-878d-fc8913ebe9d6'::uuid),   ('d2ffa292-9e12-40d5-b7f4-0b8f7ca68475'::uuid),   ('299255ff-209e-4938-b08f-ee37bf754743'::uuid),   ('84712920-de00-4f05-8e7b-be1d508d43bb'::uuid),   ('8570ab71-8ec8-40ea-a8da-8db64817f463'::uuid));

DROP TABLE IF EXISTS tmp_silinecek_fazlalik;
CREATE TEMP TABLE tmp_silinecek_fazlalik (ticket_id uuid PRIMARY KEY);
INSERT INTO tmp_silinecek_fazlalik (ticket_id) VALUES
  ('224e8e8e-07db-462d-b986-4205b4059e19'::uuid),
  ('c164b17e-c021-4d35-b20e-25f8a8dd3be6'::uuid),
  ('859d96f2-bb33-4867-9d92-1ad510a67ee4'::uuid),
  ('ad8f6bcc-343b-4953-88b1-79b3b7a4fa14'::uuid),
  ('d14c94fe-1a8c-442f-9a05-137795855c28'::uuid),
  ('fbb73a40-2fa2-4099-a5f3-78782e4d9a55'::uuid),
  ('fecec3ff-7d78-43e1-95a1-7c98abe5e1a0'::uuid),
  ('81dcc5d7-466d-4b55-b820-cf0888086104'::uuid),
  ('c91d65bc-ea3c-412f-878d-fc8913ebe9d6'::uuid),
  ('d2ffa292-9e12-40d5-b7f4-0b8f7ca68475'::uuid),
  ('299255ff-209e-4938-b08f-ee37bf754743'::uuid),
  ('84712920-de00-4f05-8e7b-be1d508d43bb'::uuid),
  ('8570ab71-8ec8-40ea-a8da-8db64817f463'::uuid);

-- kontrol: 13 olmali
SELECT count(*) FROM tmp_silinecek_fazlalik;

DELETE FROM ticket_solutions WHERE ticket_id IN (SELECT ticket_id FROM tmp_silinecek_fazlalik);
DELETE FROM tickets WHERE id IN (SELECT ticket_id FROM tmp_silinecek_fazlalik);


-- ----------------------------------------------------------------------------
-- ADIM 4 -- Son dogrulama: 9 sahte agent'ta artik SIFIR ticket kalmali
-- ----------------------------------------------------------------------------
SELECT count(*)
FROM tickets t
JOIN routing_logs rl ON rl.ticket_id = t.id
WHERE rl.assigned_agent_id IN (
    '1f31b7ad-852a-4282-b872-9c63bb73193e','64a4c27c-e82f-4e7a-8197-ba93b084c58c',
    '550e173f-86dc-446f-a9c4-12f9edd3fb94','f1bec9fc-8414-4efa-bedb-51fe100299a3',
    '574389d2-d73a-4b51-83c2-58f3c46288ce','9b511a78-766d-4fdb-96e2-3c08f1842e75',
    '98d9db18-fc84-4221-9830-2be35f83afcd','f6db68a8-f3ff-4030-be4b-60e354de603d',
    'a0df5f07-ad44-4392-8d2f-d90fb70a9c5d'
);

-- 0 donerse:
-- COMMIT;
-- Beklenmedik bir sey varsa:
-- ROLLBACK;
