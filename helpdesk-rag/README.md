# Helpdesk RAG (yerel / on-prem)

Mac mini (48 GB) üzerinde **Qwen3.5** ile çalışan help desk RAG sistemi.
Ollama host'ta native çalışır (Metal GPU için); geri kalan her şey Docker'da.

## Mimari

```
Kullanıcı ──> Open WebUI (3000)          Kullanıcı/uygulama ──> API (8000)
                    │                                              │
                    ▼                                              ▼
             Ollama (host, 11434) <──────────────────────  FastAPI RAG worker
             qwen3.5:9b + bge-m3                                   │
                                                                   ▼
                                                        Postgres + pgvector (5432)
```

> **Neden Ollama Docker'da değil?** Mac'te Docker, Apple Silicon GPU'ya (Metal)
> erişemez. Ollama'yı container'da çalıştırırsan model CPU'ya düşer ve 5-10x
> yavaşlar. Bu yüzden Ollama host'ta, gerisi Docker'da.

## Kurulum

### 1) Ollama (host)
```bash
brew install ollama
ollama serve            # ayrı terminalde açık kalsın
ollama pull qwen3.5:9b  # ana model (gerekirse qwen3.5:27b)
ollama pull bge-m3      # embedding modeli (1024 boyut)
```

### 2) Ortam değişkenleri
```bash
cp .env.example .env    # şifreleri düzenle
```

### 3) Docker servisleri
```bash
docker compose up -d --build
```

## Kullanım

Doküman yükle:
```bash
curl -F "file=@data/docs/sss.pdf" -F "title=SSS" http://localhost:8000/ingest
```

Soru sor:
```bash
curl -X POST http://localhost:8000/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "İzin talebi nasıl açılır?"}'
```

- Sohbet arayüzü: http://localhost:3000 (Open WebUI)
- API dokümanı: http://localhost:8000/docs

## Yol haritası

- [x] Faz 1: RAG (bu iskelet)
- [ ] Değerlendirme seti (30-50 gerçek soru + beklenen cevap) ile kalite ölçümü
- [ ] Kullanıcı/yetki yönetimi + loglama
- [ ] Faz 2: Servis entegrasyonu (fatura) — Qwen3.5 native tool-calling + insan onayı
- [ ] Faz 2.5: Multimodal ile fatura fotoğrafı okuma

## Faz 2 için not (tool-calling)

`app/rag/ollama_client.py:chat` zaten `tools` parametresini destekliyor.
Faz 2'de: JSON-schema tool tanımları (`create_invoice`, `get_customer`...) +
model `tool_calls` döndürünce worker gerçek işi yapar. **Geri alınamaz işlemlerde
(fatura oluşturma) mutlaka insan onayı adımı** koy.
