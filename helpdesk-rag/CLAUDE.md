# Proje: Şirket İçi Yerel AI Help Desk (RAG + L1 Triyaj)

Bu dosya projenin bağlamını taşır. Yeni bir Claude Code oturumu bunu okuyarak
projenin neresinde olduğumuzu ve neden bu kararların alındığını anlar.

## Amaç

Şirket için **tamamen yerel (on-prem)** çalışan bir AI help desk sistemi.
Veri şirket dışına ÇIKMAMALI — bulut AI servisleri bu yüzden tercih edilmiyor.

- **Faz 1 (mevcut):** Help desk RAG — dokümanlardan kaynaklı cevap.
- **Faz 1.5 (mevcut):** L1 triyaj — ticket'ları sınıflandırıp doğru uzmana atama.
- **Faz 2 (planlanan):** Servis entegrasyonu (fatura oluşturma/girme) — tool-calling.
- **Faz 2.5 (planlanan):** Multimodal — fatura fotoğrafı okuma.

## Hedef donanım

**Mac mini, 48 GB RAM.** HENÜZ TESLİM ALINMADI. Geliştirme şu ana kadar
kullanıcının kendi makinesinde yapıldı.

## Kritik mimari kararlar (değiştirmeden önce nedenini oku)

1. **Ollama host'ta native çalışır, Docker'da DEĞİL.**
   Mac'te Docker, Apple Silicon GPU'ya (Metal) erişemez; Ollama container'da
   çalışırsa model CPU'ya düşer ve 5-10x yavaşlar. Container'lar Ollama'ya
   `host.docker.internal:11434` üzerinden bağlanır (compose'da `extra_hosts`).
   *Windows'ta bu kısıt yoktur* — orada Docker Desktop + WSL2 sorunsuz, NVIDIA
   GPU varsa Ollama CUDA ile çok hızlı çalışır.

2. **Model: Qwen3.5** (Ollama). Native tool-calling + thinking + multimodal +
   256K context. Boyutlar: `9b` (~6.6GB, başlangıç), `27b` (~17GB Q4, 48GB'de rahat).
   Embedding: `bge-m3` (1024 boyut, çok dilli).

3. **`think: false`** — Qwen3.5'in thinking modu help desk'te bazen tüm çıktıyı
   `thinking` alanına yazıp `content`'i boş bırakıyordu. Kapatıldı; ayrıca
   content boşsa thinking'e düşen bir yedek var (`app/rag/ollama_client.py`).

4. **pgvector** ayrı vektör DB yerine — tek Postgres'te hem uygulama verisi hem
   embedding. Basit başla; gerekirse Qdrant'a taşınır.

5. **Sistem prompt'u "önce cevapla"** olacak şekilde sıkılaştırıldı. Önceki
   sürümde model bilgi sorularında gevezeliğe/selam moduna kaçıyordu.
   Bkz. `app/rag/pipeline.py:SYSTEM_PROMPT`.

6. **L1 triyajda güven eşiği (0.6)** — güven düşükse veya kategori `Diger` ise
   otomatik atama YAPILMAZ, insan triyaj kuyruğuna düşer. Yanlış uzmana atama
   riskini kontrol eder. Faz 2'de fatura gibi geri alınamaz işlemlerde de aynı
   prensip: **insan onayı şart**.

## Yapı

```
app/
├── main.py              # FastAPI: /health /ingest /ask /triage
├── config.py            # ortam ayarları (.env)
├── rag/
│   ├── ollama_client.py # embed + chat (tool-calling ve fmt='json' destekli)
│   ├── store.py         # pgvector yaz/ara (cosine)
│   ├── ingest.py        # PDF/metin → chunk → embed → DB
│   └── pipeline.py      # soru → retrieve → Qwen3.5 → kaynaklı cevap
└── triage/
    ├── routing_rules.json # kategori → ekip → uzman (GERÇEK EKİPLE DOLDURULMALI)
    ├── classifier.py      # ticket → modul/oncelik/ozet/guven (JSON)
    ├── router.py          # kural tabanlı yönlendirme + güven eşiği
    └── service.py         # sınıflandır → yönlendir → RAG çözüm → tickets'a kaydet
db/
├── init.sql             # pgvector + documents + chunks
└── tickets.sql          # tickets tablosu
eval/
├── dataset.json         # değerlendirme seti
└── run_eval.py          # retrieval recall@k + cevap doğruluğu (+ --judge)
docker-compose.yml       # postgres(pgvector) + api + open-webui
helpdesk-rag.postman_collection.json
```

## Mevcut durum

- ✅ RAG uçtan uca çalışıyor; gerçek SAP dokümanı (`data/docs/START_OP2025.pdf`,
  S/4HANA Getting Started) indeksli ve doğru cevap veriyor.
- ✅ Halüsinasyon reddi çalışıyor ("Bu konuda elimde bilgi yok...").
- ✅ L1 triyaj çalışıyor: SAP-FI/IT-Hesap/IT-Ag doğru sınıflandırılıyor,
  doğru uzmana atanıyor; parola/VPN gibi bilinen sorunlar RAG ile otomatik
  çözülüyor; alakasız mesaj insan kuyruğuna düşüyor.
- ✅ Eval sistemi çalışıyor (örnek setle 9/9).
- ⏸️ **Docker denenmedi.** Colima kuruldu ama geliştirme makinesinde disk doluydu
  (228GB'de ~1GB boş). Docker doğrulaması Mac mini'ye (veya Windows'a) ertelendi.

## Şirket bağlamı

- ERP: **SAP S/4HANA**.
- Geçmiş ticket verisi var ama **dağınık/erişilmez** → bu yüzden triyaj kural
  tabanlı başladı, geçmişten öğrenme sonraya bırakıldı.
- `routing_rules.json`'daki uzman isimleri (`ayse.k`, `deniz.a` vb.) ÖRNEKTİR,
  gerçek ekip yapısıyla değiştirilmeli.

## Çalıştırma

### Ollama (host, native)
```bash
ollama serve
ollama pull qwen3.5:9b
ollama pull bge-m3
```

### Yerel geliştirme (Docker'sız)
`.env` içinde `OLLAMA_BASE_URL` ve `DATABASE_URL` yerel makineye göre ayarlı olmalı.
```bash
python -m venv .venv
.venv/bin/pip install -r app/requirements.txt   # Windows: .venv\Scripts\pip
.venv/bin/uvicorn app.main:app --reload
```
API: http://localhost:8000/docs

### Docker
```bash
cp .env.example .env
docker compose up -d --build
```
Not: compose'da postgres host portu **5433**'e eşli (geliştirme makinesinde
Postgres.app 5432'yi kullanıyordu).

### Eval
```bash
.venv/bin/python eval/run_eval.py           # hızlı
.venv/bin/python eval/run_eval.py --judge   # + LLM-hakem
```

## Platform notları

- Geliştirme şu ana kadar **macOS**'ta yapıldı (Postgres.app 18.3 + venv).
- Sistem Python'u 3.9 olduğu için kodda `from __future__ import annotations`
  kullanıldı (3.10+ union sözdizimi için). Docker imajı Python 3.12.
- **Windows'a taşınırsa:** Ollama'yı Windows için kur; Docker Desktop (WSL2)
  kullan; venv yolları `.venv\Scripts\`; `host.docker.internal` zaten çalışır.

## Prod planlaması (netleşti)

- **Kimlik:** Şirkette Microsoft 365 var (Teams/OneDrive) → **Entra ID OIDC SSO**.
  IT'den app registration talep edilmeli: `client_id`, `client_secret`,
  `tenant_id`, redirect URI. `open-webui` OIDC env'leri `.env.prod.example`'da
  hazır; `api` tarafında token doğrulama HENÜZ YAZILMADI.
- **Erişim:** İç ağ + VPN'den dışarıdan.
- **Model:** ÇİFT MODEL kararı — `qwen3.5:27b` (Q4, ~17GB) kullanıcı cevapları
  için, `qwen3.5:9b` (~6.6GB) triyaj için. 48GB M4 Pro Mac mini'de rahat sığar.
  `TRIAGE_MODEL` `.env.prod.example`'da var ama kodda (`classifier.py`) henüz
  bağlanmadı — hâlâ tek `LLM_MODEL` kullanılıyor. Eval ile 9b/27b farkı
  doğrulanmalı; fark küçükse tek 9b ile devam etme opsiyonu açık.
- **Fırsat (henüz yapılmadı):** M365 sayesinde SharePoint/OneDrive'dan Graph
  API ile otomatik doküman senkronu ve Teams bot arayüzü mümkün.

## Prod dosyaları

- `docker-compose.prod.yml` — 7 servis: caddy (TLS+tek giriş), api, worker,
  redis, postgres (host portu yok, iç ağ only), open-webui, backup.
- `deploy/Caddyfile` — reverse proxy, `/api`→api, gerisi→open-webui.
- `.env.prod.example` — kopyalanıp `.env.prod` yapılmalı (git'e girmez).
- Bellek limitleri sabitlendi (container'lar toplam ~13GB, Ollama'ya ~30GB payı).
- **Kurulumdan önce yapılması gerekenler:** `open-webui` image tag'ini
  sabitle (`:main` hareketli), yedekleri (`./backups`) dışarı kopyalama
  (NAS/başka makine) ayarla, `.env.prod`'u doldur.

## Asenkron ingest (worker + Redis)

Büyük dokümanlar (SAP kılavuzu gibi) embedding üretimi uzun sürdüğü için
`/ingest` artık iki modda çalışır:
- **Redis varsa (prod):** iş kuyruğa alınır, `{mod:"kuyruk", job_id}` döner.
  Durum: `GET /jobs/{job_id}`. Worker: `arq app.worker.WorkerSettings`.
- **Redis yoksa (dev, mevcut durum):** senkron indeksler,
  `{mod:"senkron", document_id}` döner. Davranış değişmedi, geriye uyumlu.

`app/queue.py`'deki Redis havuzu önbelleklidir ve kısa timeout kullanır —
Redis yoksa istek uzun süre beklemez (~anında None döner).

## Sıradaki adımlar

1. IT'den Entra ID app registration talep etmek (süre alabilir, şimdiden aç).
2. Çift model desteğini `config.py`/`classifier.py`/`pipeline.py`'ye bağlamak
   (`TRIAGE_MODEL` şu an sadece ortam değişkeni, kod tarafı yok).
3. `api` tarafında OIDC token doğrulama (Entra kaydı gelmeden test edilemez).
4. `open-webui` image sürümünü sabitlemek.
5. Gerçek help desk / SAP **son-kullanıcı** dokümanlarını toplayıp ingest etmek
   (resmî SAP "Getting Started" kılavuzu IT/kurulum odaklı, help desk için
   Application Help veya şirket iç dokümanları / SharePoint senkronu daha uygun).
6. `routing_rules.json`'u gerçek ekip ve uzmanlarla doldurmak.
7. Eval setini gerçek sorularla 30-50 maddeye çıkarmak; Mac mini gelince
   9b/27b karşılaştırmasını eval ile yapmak.
8. Docker kurulumunu doğrulamak (Mac mini veya Windows — dev makinesinde
   disk dolu olduğu için Colima/Docker denenemedi).
9. Triyajda iş yükü dengeleme, sonra biriken `tickets` verisinden benzerlik
   tabanlı öğrenme.
