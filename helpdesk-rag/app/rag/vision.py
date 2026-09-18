"""Görselden gerçek OCR (Tesseract) ile metin çıkarır.

Not: Qwen3.5 kendisi de multimodal (görseli doğrudan okuyabilir), ama karakter
seviyesinde kesinlik gerektiren durumlarda (hata kodları, stack trace'ler)
genel bir "görseli açıkla" isteği parafraz/yuvarlama riski taşır. Bu yüzden
gerçek bir OCR motoru kullanılıyor; Qwen3.5 sadece çıkan METNİ yorumlayıp
cevap üretiyor, görselin kendisini görmüyor.

Hata dayanıklılığı:
  - Bozuk/desteklenmeyen görsel formatı → OCRError
  - Tesseract yüklü değilse → TesseractNotInstalledError
  - Boş görsel → OCRError
"""
from __future__ import annotations

import io

from app.exceptions import OCRError, TesseractNotInstalledError
from app.logging_config import get_logger

logger = get_logger(__name__)


def ocr_image(image_bytes: bytes) -> str:
    """Görsel bytes -> OCR ile çıkarılan metin. Türkçe + İngilizce birlikte
    denenir (ekran görüntülerinde ikisi de sık karışık geçebiliyor).

    Hata durumlarında anlamlı exception fırlatır (ham traceback yerine)."""
    if not image_bytes:
        raise OCRError("Boş görsel verisi gönderildi.")

    # PIL import'u burada — modül seviyesinde import başarısız olursa
    # tüm uygulama başlamaz, lazy import daha güvenli.
    try:
        from PIL import Image, UnidentifiedImageError
    except ImportError:
        logger.error("Pillow kütüphanesi yüklü değil")
        raise OCRError("Görsel işleme kütüphanesi (Pillow) sunucuda yüklü değil.")

    try:
        import pytesseract
    except ImportError:
        logger.error("pytesseract kütüphanesi yüklü değil")
        raise TesseractNotInstalledError(
            "OCR kütüphanesi (pytesseract) sunucuda yüklü değil."
        )

    # 1. Görseli aç
    try:
        img = Image.open(io.BytesIO(image_bytes))
        img.verify()  # bozuk dosya kontrolü
        # verify() sonrası img kullanılamaz, yeniden açılmalı
        img = Image.open(io.BytesIO(image_bytes))
    except UnidentifiedImageError:
        logger.warning("Desteklenmeyen görsel formatı")
        raise OCRError(
            "Görsel formatı tanınamadı. Desteklenen formatlar: PNG, JPEG, WebP."
        )
    except Exception as exc:
        logger.warning("Görsel açılamadı: %s", exc)
        raise OCRError(f"Görsel dosyası açılamadı: {exc}")

    # 2. OCR uygula
    try:
        text = pytesseract.image_to_string(img, lang="tur+eng")
    except pytesseract.TesseractNotFoundError:
        logger.error("Tesseract binary bulunamadı")
        raise TesseractNotInstalledError(
            "Tesseract OCR motoru sunucuda yüklü değil. "
            "Dockerfile'da 'tesseract-ocr' paketinin kurulu olduğundan emin olun."
        )
    except Exception as exc:
        logger.warning("OCR sırasında hata: %s", exc)
        raise OCRError(f"OCR işlemi başarısız oldu: {exc}")

    raw_text = text.strip()
    
    stop_words = [
        "açıklama", "kime:", "tasnif dışı", "unclassified", "merhaba", 
        "daha fazlasını gör", "tümünü yanitla", "cevapla", "ilet", "konuşmalar", 
        "e-posta", "sistem bildirmleri", "notlar", "iyi çalışmalar", "acil"
    ]
    
    cleaned_lines = []
    for line in raw_text.split('\n'):
        line_lower = line.lower().strip()
        
        if not line_lower:
            continue
            
        if any(sw in line_lower for sw in stop_words) and len(line_lower) < 60:
            continue
            
        cleaned_lines.append(line.strip())

    result = " | ".join(cleaned_lines)

    if not result:
        logger.info("OCR sonucu boş veya tamamı filtrelendi")

    return result
