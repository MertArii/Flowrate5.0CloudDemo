# Komut Referansı

Bu projede kullanılan tüm komutlar, sırasıyla ve karşılaşılan sorunların
çözümleriyle birlikte.

---

## 1. Bulut Demo Kurulumu (Linux VM / GCP)

Sıfırdan çalışır hale getirmek için gereken tam dizi. **Sorunlara takılmamak
için bu sırayı takip et** (bölüm 4'teki tuzaklar bu sıraya göre önlendi).

### 1.1 Docker kurulumu

```bash
# Docker + Compose plugin (Ubuntu/Debian)
curl -fsSL https://get.docker.com | sudo sh

# sudo'suz kullanabilmek için gruba ekle
sudo usermod -aG docker $USER
newgrp docker

# doğrula (hata vermemeli)
docker ps
docker compose version
```

### 1.2 Docker DNS ayarı (ZORUNLU)

Container'lar varsayılan olarak host'un `127.0.0.53` çözümleyicisini alır ve
bu container içinde çalışmaz. Bu adım atlanırsa model indirme ve container'lar
arası iletişim başarısız olur.

```bash
echo '{"dns":["8.8.8.8","8.8.4.4"]}' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker
```

### 1.3 Host'taki Ollama'yı devre dışı bırak (varsa)

Host'ta bir Ollama servisi varsa 11434 portunu tutar ve container ollama
başlayamaz.

```bash
sudo systemctl stop ollama
sudo systemctl disable ollama

# port boş mu kontrol
sudo lsof -i :11434
```

### 1.4 Projeyi çek ve başlat

```bash
git clone https://github.com/MertArii/Flowrate5.0CloudDemo.git
cd Flowrate5.0CloudDemo/helpdesk-rag

docker compose -f docker-compose.demo.yml up -d --build
```

### 1.5 Modelleri indir

```bash
docker compose -f docker-compose.demo.yml exec ollama ollama pull qwen3.5:4b
docker compose -f docker-compose.demo.yml exec ollama ollama pull bge-m3

# doğrula: iki model de listelenmeli
docker compose -f docker-compose.demo.yml exec ollama ollama list
```

### 1.6 Test

```bash
curl http://localhost:8000/health

curl -X POST http://localhost:8000/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"merhaba"}'
```

İlk `/ask` çağrısı modeli CPU belleğine yüklerken 30-60 sn sürer.

---

## 2. Dışarı Açma (Cloudflare Tunnel)

### 2.1 cloudflared kurulumu

```bash
curl -L --output cloudflared.deb \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
cloudflared --version
```

### 2.2 Tüneli aç ve adresi al

Log kalabalığında adresi kaybetmemek için arka planda çalıştırıp ayıkla:

```bash
cloudflared tunnel --url http://localhost:8000 > /tmp/cf.log 2>&1 &
sleep 8
grep trycloudflare.com /tmp/cf.log
```

Çıkan `https://xxxx.trycloudflare.com` adresi demo adresindir.

**Tarayıcıda kullanırken sonuna `/docs` ekle:**
```
https://xxxx.trycloudflare.com/docs
```

Kök adres (`/`) `{"detail":"Not Found"}` döner — bu normaldir, API'nin kökünde
sayfa yoktur. Arayüz `/docs` altındadır.

### 2.3 Tüneli kapat

```bash
pkill cloudflared
```

---

## 3. Günlük Kullanım Komutları

```bash
# durum
docker compose -f docker-compose.demo.yml ps

# loglar
docker compose -f docker-compose.demo.yml logs --tail 40 api
docker compose -f docker-compose.demo.yml logs -f ollama

# yeniden başlat
docker compose -f docker-compose.demo.yml restart api

# durdur / tamamen sil
docker compose -f docker-compose.demo.yml down
docker compose -f docker-compose.demo.yml down -v    # + veriler silinir
```

### Doküman yükleme ve sorgulama

```bash
# örnek doküman oluştur ve indeksle
echo "Yıllık izin talebi için İK portalına girip Yeni Talep açılır. Onay 2 iş günü sürer." > /tmp/sss.txt
curl -F "file=@/tmp/sss.txt" -F "title=SSS" http://localhost:8000/ingest

# RAG sorgusu
curl -X POST http://localhost:8000/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"İzin talebini nasıl açarım?"}'

# L1 triyaj
curl -X POST http://localhost:8000/triage \
  -H "Content-Type: application/json" \
  -d '{"text":"Fatura kaydinda hesap belirleme hatasi aliyorum"}'
```

---

## 4. Karşılaşılan Sorunlar ve Çözümleri

Kurulum sırasında yaşananlar. Aynı hatayı görürsen buraya bak.

### `permission denied ... /var/run/docker.sock`
Kullanıcı `docker` grubunda değil.
```bash
sudo usermod -aG docker $USER
newgrp docker      # veya SSH oturumunu tamamen yenile
```

### `failed to bind host port 0.0.0.0:11434: address already in use`
Host'ta Ollama servisi çalışıyor, container'ın portunu tutuyor.
```bash
sudo systemctl stop ollama
sudo systemctl disable ollama
```

### `Temporary failure in name resolution` (api → ollama)
### `lookup registry.ollama.ai on 127.0.0.53:53: connection refused`
Her ikisi de aynı kök nedenden: container DNS'i bozuk. Bölüm 1.2'deki
`daemon.json` ayarını uygula.

### `ollama-pull` container'ı DNS hatasıyla çıkıyor
Container hazır olmadan pull denemesi. Modelleri doğrudan container içinden çek:
```bash
docker compose -f docker-compose.demo.yml exec ollama ollama pull qwen3.5:4b
```

### `/ask` → `Internal Server Error`
Genelde Ollama'ya ulaşılamıyor demektir. Sırayla kontrol et:
```bash
docker compose -f docker-compose.demo.yml ps                          # ollama Up mı
docker compose -f docker-compose.demo.yml exec ollama ollama list     # modeller var mı
docker compose -f docker-compose.demo.yml logs --tail 30 api          # gerçek hata
```

### Tünel adresi log'da bulunamıyor
Bölüm 2.2'deki `grep` yöntemini kullan.

---

## 5. Yerel Geliştirme (macOS)

Mac'te Docker'sız, native çalıştırma.

### Ollama (host'ta native — Metal GPU için)

```bash
brew install ollama
ollama serve                # ayrı terminalde açık kalsın
ollama pull qwen3.5:9b
ollama pull bge-m3
```

### Postgres (Postgres.app)

```bash
PGBIN="/Applications/Postgres.app/Contents/Versions/latest/bin"
"$PGBIN/createdb" helpdesk
"$PGBIN/psql" -d helpdesk -f db/init.sql
"$PGBIN/psql" -d helpdesk -f db/tickets.sql
```

### Python ortamı ve API

```bash
python3 -m venv .venv
./.venv/bin/pip install -r app/requirements.txt
./.venv/bin/uvicorn app.main:app --reload
```

API: http://localhost:8000/docs

### Değerlendirme (eval)

```bash
./.venv/bin/python eval/run_eval.py            # hızlı
./.venv/bin/python eval/run_eval.py --judge    # + LLM-hakem
```

---

## 6. Notlar

- **Model seçimi:** CPU-only VM'de `qwen3.5:4b`. GPU'lu / 48GB Mac mini'de
  `qwen3.5:27b` (cevap) + `qwen3.5:9b` (triyaj). `9b`/`27b` CPU'da çok yavaştır.
- **Cloudflare tüneli kimlik doğrulamasızdır** — link kimdeyse erişir. Demo
  bitince `pkill cloudflared`.
- **Cloud Shell geçicidir**; kalıcı demo için Compute Engine VM gerekir.
- Prod kurulumu için `docker-compose.prod.yml` ve `DEMO.md` dosyalarına bak.
