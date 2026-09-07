-- ============================================================================
-- ADIM 1/3 -- Tutulacak 125 ticket'i GERCEK uzmanlara guncelle
--
-- Bu ticket'lar tickets_125_yeniden_atanmis.xlsx'te (icerik bazli mantikla)
-- yeniden atanmisti. Once bunlari DB'de gercek uzmana baglamamiz lazim;
-- yoksa adim 3'te sahte user'lari silerken routing_logs.assigned_agent_id
-- FK'si (ON DELETE kurali YOK -> RESTRICT) devrilir.
--
-- routing_logs bir KARAR GECMISI oldugu icin satirlari silmiyoruz, sadece
-- assigned_agent_id / assigned_group_id kolonlarini duzeltiyoruz (decision_factors
-- JSON'u -- yani orijinal siniflandirma -- oldugu gibi kaliyor, sadece kime
-- atandigi guncelleniyor).
-- ============================================================================

BEGIN;

CREATE TEMP TABLE tmp_ticket_reassign (
    ticket_id  uuid PRIMARY KEY,
    new_agent_id uuid NOT NULL,
    new_group_id  uuid NOT NULL
);

INSERT INTO tmp_ticket_reassign (ticket_id, new_agent_id, new_group_id) VALUES
  ('35223499-bcbe-4225-8a47-b228aee74d50'::uuid, 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('711ccde9-713e-497c-a4b8-1c0d27a39429'::uuid, '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('47275353-1d4b-4afd-8427-e8aff7f29a7f'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('6101b9d6-4ebe-4ac6-b217-eb94c71b1c95'::uuid, '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('83095217-d5ad-48b8-ae82-7e2ca44c13ee'::uuid, '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('f724bd60-7419-490b-93cb-7901d6b51241'::uuid, '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('d01b9acd-905c-422b-bdbd-fa9576c558fa'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('d0a408aa-1385-4cbb-a8e7-a22ca8c96aea'::uuid, '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('f40f70d8-5edd-4202-b2e2-8b7701e56d46'::uuid, '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('0028c55f-2190-477b-83a0-5360b104b2ed'::uuid, '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('913c4b42-3940-4b7b-85dd-687b4919f504'::uuid, '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('d8ba8399-7a58-40b8-ae76-02cbb2e69f80'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('f60a76cf-6bf1-49e8-a7d9-02c7e4edfc6f'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('43a6b3b1-b2c8-4b9a-84e4-45aa49ae1c4c'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('35c9313b-e20f-4538-a8a6-a0024093d1a6'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('cdf24f28-2a17-4aec-8b23-50d6f0bf48c2'::uuid, 'f3144acb-ba7a-44b0-b1fc-ff5ed9185315'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('9a228976-4b92-4ed7-9d44-6e6508366250'::uuid, '54195b9f-ad77-4780-8147-38559d459fc2'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('d7890f59-c266-4520-b881-5de71ed9f685'::uuid, 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('7dbc7c05-aa2f-4490-8ae3-a019b89454e4'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('ed6e3c13-fafd-43dd-bf6f-e6f77c3c9518'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('084080a8-a219-4f7e-8fe9-0071be63c3e0'::uuid, '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('a012c905-4328-4028-b0e5-243fb0fb648a'::uuid, 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('1fa507cf-3ca0-474e-9a1f-eab4acbaa6e9'::uuid, '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('fcb9a22d-f75d-4537-9934-42b3058a21c2'::uuid, '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('25e6ab52-5703-430b-af1f-37c6c27c092b'::uuid, '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('96a8d952-ca18-4513-a1b1-580841b51a35'::uuid, '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('1c58ea53-5cbc-4849-868b-3ac6750be6b5'::uuid, '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('3185275f-c8b4-40cc-ae69-0ac1777c9c41'::uuid, '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('9b802679-8c60-4ce0-9fdc-b5e90e11edc1'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('512021a5-07e5-45f9-9a56-c5f23a425c1e'::uuid, '2a1a849e-9db9-4cf7-a0f9-a6b652f5fefb'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('e12b8285-04e5-429c-8df4-15455eea1e91'::uuid, '2a1a849e-9db9-4cf7-a0f9-a6b652f5fefb'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('03339dca-99f2-4019-bb5b-21567c16a8b6'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('9e474c58-8f8b-4c22-991e-e405a50fef65'::uuid, '9e25d672-0cf8-451d-981a-d10530a30c5b'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('a907778f-c918-48cb-bd44-0d5be8a94910'::uuid, '9e25d672-0cf8-451d-981a-d10530a30c5b'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('28be8878-961d-417c-9f5e-916e6db303c4'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('eb5f4461-fb5b-4c09-a027-06cac63bd478'::uuid, '9e25d672-0cf8-451d-981a-d10530a30c5b'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('9f477304-88bc-43a4-988c-84f11cff1c47'::uuid, 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('81dcc5d7-466d-4b55-b820-cf0888086104'::uuid, '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('80480fa2-6b30-44e0-aebf-5c8014431b81'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('eaeaff5e-4058-49ac-8621-54cd512e357b'::uuid, '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('eb7fae5a-2c3d-406c-a58c-bfaa0857f330'::uuid, '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('6992d751-6b9f-4bee-833d-ec8e6e7bfab9'::uuid, '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('03143309-cab3-442f-9246-200dcba4a2b0'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('f0e9e61a-9263-40f4-b5a5-1af618ea750b'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('cc4a8a49-e1a7-4662-8938-beaf8f2e5bdf'::uuid, '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('c0c7ae23-ebba-486a-9bcd-9414f1468e66'::uuid, '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('bd467ffa-f1b8-42ba-bfcb-78177a38049f'::uuid, '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('19f9af63-fe7b-4476-89c7-50ed255c5528'::uuid, '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('6689e7b0-29f0-47d2-8f2e-52d526f06129'::uuid, 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('98f06333-4afb-4942-8c61-cbcb6bfc0d9d'::uuid, '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('2effec90-f696-41d3-a496-91815cf5c8d5'::uuid, '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('db05be94-67ef-43bc-8fee-22a22c891cb9'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('9cd70d0e-d4c0-42a6-9529-e61d5a0ae143'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('502fb15c-2439-43ee-bcdc-613b4d2859fd'::uuid, '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('e501664f-8636-4974-b069-779ec4e03d61'::uuid, 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('15ebe85d-8800-4c84-9389-65c74f45b4fc'::uuid, '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('56ec44f8-22e4-4dc6-bed9-7cec5ff52555'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('2f6c1a02-379c-4c24-b607-c10db9494f54'::uuid, 'd452be79-656c-4651-817d-1a200da15727'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('fdc704f8-b2e3-4de2-8f90-4588efd08485'::uuid, 'd452be79-656c-4651-817d-1a200da15727'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('628b698e-9e8e-4e15-a3bb-b6d4d7e506bf'::uuid, 'd452be79-656c-4651-817d-1a200da15727'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('b1aa9397-9e36-4d23-ab24-dbaf5338d847'::uuid, '68f7cf53-5de5-41d5-a6f5-cfa527a96871'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('68f61ba7-ebb9-44f9-b2c9-c364e6c04945'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('bdf9ebae-e7ba-4df9-ae09-974020be2a49'::uuid, 'd452be79-656c-4651-817d-1a200da15727'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('8cedc7f6-4778-48ee-b3cc-3da5832db386'::uuid, '68f7cf53-5de5-41d5-a6f5-cfa527a96871'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('58500715-a670-4126-aac9-c57fdc8ab619'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('4b35ee5f-5b3e-4120-aed6-af2250d381dc'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('7fe01e5d-fbc8-4aa7-be30-9339264d2e20'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('e375201b-b599-4f23-a724-fbfe8427f2ab'::uuid, 'd452be79-656c-4651-817d-1a200da15727'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('0a4aba50-f460-4041-99f3-4a76817fd3c0'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('e3428dbf-b149-4f82-aba0-c2751ee345cb'::uuid, 'd452be79-656c-4651-817d-1a200da15727'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('6c931096-4bd6-4e86-8d90-2504fba4bcca'::uuid, '68f7cf53-5de5-41d5-a6f5-cfa527a96871'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('8ff710f8-f16b-4912-877c-a34ba2af28cc'::uuid, '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('40ba46c8-0ba5-4263-8f03-91a457147292'::uuid, '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('5ca7e42a-a911-49dd-b086-a15adc4ce83e'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('b533509d-fb69-4e1e-a0c3-114843692e6c'::uuid, '9e25d672-0cf8-451d-981a-d10530a30c5b'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('a2dad4aa-d924-4d7d-9c96-b1e10549f3ce'::uuid, 'ee1245eb-bda3-4e19-8450-31173141f861'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('12188be8-3228-491e-8fe2-789e01450d10'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('071b3529-dbee-4c35-96df-f51aa711f37a'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('e36d59b6-8f2b-46af-a62c-dd30113d2854'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('1f5ae26b-540f-4587-99dd-0f7f542f8854'::uuid, 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('0b16cb34-8b3d-4272-b5a5-7b93a3d25464'::uuid, 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('b460c44b-ee81-426d-9d34-b7c2852e2bd7'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('fbbeec72-5b70-4f75-beb8-0eb199b0900e'::uuid, '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('cbbdff0d-899d-4ae5-8255-fe500c452f01'::uuid, '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('894e1bff-5991-4c69-a828-a52ee43635d7'::uuid, 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('99c9fff9-1cb9-4ec6-903e-34d146149c60'::uuid, '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('fecec3ff-7d78-43e1-95a1-7c98abe5e1a0'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('224e8e8e-07db-462d-b986-4205b4059e19'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('2def92c6-c78c-4f12-8226-14c8a6674936'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('763e9b4f-9615-4b19-b7bb-6ac5218a0814'::uuid, '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('13712efb-6a84-48b0-9b35-f9184afaae43'::uuid, '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('6c367dad-756f-4001-a86f-080e4b2c2eb6'::uuid, 'd452be79-656c-4651-817d-1a200da15727'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('6751557f-dcc5-4409-9e8b-60ae624e7580'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('4289db19-b479-4de9-bc84-0a84736c051b'::uuid, 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('859d96f2-bb33-4867-9d92-1ad510a67ee4'::uuid, 'fd71f8a2-7884-47be-b7e0-0624ec2aeb19'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('0c570c1d-f390-4669-a929-0089cfedb20e'::uuid, '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('f5f2dc5b-8b29-4ea5-b854-552af3d1b2c9'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('3146e2d1-56a9-4d66-8fe8-906eaabfb189'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('d2ffa292-9e12-40d5-b7f4-0b8f7ca68475'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('84712920-de00-4f05-8e7b-be1d508d43bb'::uuid, '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('f8c497fd-7a23-4b09-89d1-9df8113e7855'::uuid, 'f3144acb-ba7a-44b0-b1fc-ff5ed9185315'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('93516cf8-11b6-424d-b34d-282646aafa1c'::uuid, '2a1a849e-9db9-4cf7-a0f9-a6b652f5fefb'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('e613f035-2a40-4f88-a523-609aa24a426f'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('b3698670-46bd-4160-b363-0894fd98c3c1'::uuid, '2a1a849e-9db9-4cf7-a0f9-a6b652f5fefb'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('b3d0efa5-1f7b-431a-b62c-f8def025db18'::uuid, '68f7cf53-5de5-41d5-a6f5-cfa527a96871'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('7d7e99bc-3e31-4d35-9be3-054572c9e564'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('846c3e95-36ec-4840-89f0-dc226cbf3b77'::uuid, '9e25d672-0cf8-451d-981a-d10530a30c5b'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('271cf952-3d03-44d5-906c-15a4d5d8043f'::uuid, '2a1a849e-9db9-4cf7-a0f9-a6b652f5fefb'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('3d0f4669-d6c4-4b81-8027-dd8c3a04403f'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('1fd60982-52ce-475b-92b5-3e0dba41cd46'::uuid, '68f7cf53-5de5-41d5-a6f5-cfa527a96871'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('856fc641-b20c-4892-8c69-48b37eb480d0'::uuid, '2a1a849e-9db9-4cf7-a0f9-a6b652f5fefb'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('4d7b942e-361c-4831-929d-7eaea6c7de25'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('63cfbd2c-b3bd-47d3-a77b-8a973b332d9f'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('5c7e7273-4c24-4d1f-b7c2-555f17d56105'::uuid, '78cc4401-f73a-4447-9943-5a3bddec63dc'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('a67adf05-9d12-46ed-b119-9d40228907f6'::uuid, '68f7cf53-5de5-41d5-a6f5-cfa527a96871'::uuid, 'e7d5dc65-8d42-4763-a249-4103927ff431'::uuid),
  ('d465975e-f660-4658-ae6e-e487f140c89f'::uuid, '8cfa7028-25a9-49ba-9532-b85f4c8be422'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('367d51d5-7b84-48c2-b5c1-adb4675e403e'::uuid, '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('22773daf-0f84-4ee7-9435-6785e54bcfcd'::uuid, '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('71171141-b29e-48af-9589-2e13ff544e89'::uuid, '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('980635ab-4148-4d8b-8011-6400471c7940'::uuid, '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('0999c2b1-d5e0-483b-9134-c50dd6caf56e'::uuid, '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('2e7af195-8391-4d77-9cbf-7b51b743c087'::uuid, '64ac6896-d57d-43a1-b0b8-8e098acc470e'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('5d1d43b6-a790-41d1-a87d-f198a83d00bb'::uuid, 'fe167612-09a1-4d39-9b5d-b66f3110d815'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('7c5c1630-a589-4406-8c02-357e24b0071f'::uuid, '992aa8db-0eec-455c-acb0-1f75c2119bb7'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid),
  ('a74d31f4-03ee-4014-af5b-217b60fa10eb'::uuid, '8905071e-51f8-4c75-9e65-bd6e09ec63b1'::uuid, '8cd82ed0-91f8-4b33-9e6d-f55af97f43f2'::uuid);

-- kontrol: 125 olmali
SELECT count(*) FROM tmp_ticket_reassign;

-- 1a) tickets tablosu
UPDATE tickets t
SET assigned_agent_id = m.new_agent_id,
    assigned_group_id = m.new_group_id,
    updated_at = now()
FROM tmp_ticket_reassign m
WHERE t.id = m.ticket_id;

-- 1b) routing_logs (ayni ticket'lara ait TUM routing_logs kayitlari --
-- normalde ticket basina tek satir olur ama garanti olsun diye ticket_id'ye gore guncelliyoruz)
UPDATE routing_logs rl
SET assigned_agent_id = m.new_agent_id,
    assigned_group_id = m.new_group_id
FROM tmp_ticket_reassign m
WHERE rl.ticket_id = m.ticket_id;

-- kontrol: bu 125 ticket icin guncelleme dogru gitti mi (ikisi de 0 donmeli)
SELECT count(*)
FROM tickets t
JOIN tmp_ticket_reassign m ON m.ticket_id = t.id
WHERE t.assigned_agent_id <> m.new_agent_id OR t.assigned_group_id <> m.new_group_id;

SELECT count(*)
FROM routing_logs rl
JOIN tmp_ticket_reassign m ON m.ticket_id = rl.ticket_id
WHERE rl.assigned_agent_id <> m.new_agent_id OR rl.assigned_group_id <> m.new_group_id;

-- Yukaridaki iki sayim da 0 ise:
-- COMMIT;
-- Degilse:
-- ROLLBACK;
