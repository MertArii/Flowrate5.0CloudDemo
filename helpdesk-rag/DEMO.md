# Bulut Demo Kurulumu (Linux VM / Cloud Shell)

CPU-only bir Linux VM'de tek komutla çalışan demo. Mac mini prod kurgusundan
farklı olarak Ollama da container içinde (GPU olmadığı için sakınca yok) ve
model `qwen3.5:4b` (CPU'da makul hız için).

## Adımlar

```bash
# 1. Repo'yu çek
git clone https://github.com/MertArii/Flowrate5.0CloudDemo.git
cd Flowrate5.0CloudDemo/helpdesk-rag

# 2. Her şeyi ayağa kaldır (modeller ilk açılışta otomatik iner, ~5GB, birkaç dk)
docker compose -f docker-compose.demo.yml up -d --build

# 3. Model indirmesini izle (bitince 'Modeller hazir.' yazar)
docker compose -f docker-compose.demo.yml logs -f ollama-pull

# 4. Yerel test (tünel açmadan ÖNCE)
curl http://localhost:8000/health
curl -X POST http://localhost:8000/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"merhaba"}'
```

`/ask` dolu bir cevap dönerse sistem hazır.

## Doküman yükleme + triyaj denemesi

```bash
# Bir doküman indeksle (repo'da örnek SAP PDF'i data/docs altında değil;
# kendi .txt/.pdf'ini yükle)
curl -F "file=@data/docs/DOSYAN.pdf" -F "title=SAP" http://localhost:8000/ingest

# Triyaj
curl -X POST http://localhost:8000/triage \
  -H "Content-Type: application/json" \
  -d '{"text":"Fatura kaydinda hesap belirleme hatasi aliyorum"}'
```

## Dışarı açma (Cloudflare Tunnel)

```bash
# Arayüz (sunum için)
cloudflared tunnel --url http://localhost:3000

# İstersen API için ayrı tünel (Postman demosu)
cloudflared tunnel --url http://localhost:8000
```

Tünel `*.trycloudflare.com` linki verir — **kimlik doğrulamasız, herkese açık**.
Sadece demo için; bittiğinde `Ctrl+C` ile kapat.

## Kapatma / temizlik

```bash
docker compose -f docker-compose.demo.yml down          # durdur
docker compose -f docker-compose.demo.yml down -v        # + verileri sil
```

## Notlar

- Bu VM CPU-only; `4b` bile ilk cevapta modeli belleğe yüklerken ~10-20 sn
  gecikebilir, sonraki cevaplar hızlanır. `9b`/`27b` bu makinede KULLANMA.
- `WEBUI_AUTH=false` — demo kolaylığı için arayüz girişi kapalı. Gerçek prod
  için `docker-compose.prod.yml` + Entra ID SSO kullanılır.
- Cloud Shell geçici bir ortamdır (oturum kapanınca sıfırlanabilir); kalıcı
  demo için Compute Engine VM gerekir.
