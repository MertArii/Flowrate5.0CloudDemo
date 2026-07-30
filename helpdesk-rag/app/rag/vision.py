"""Görselden gerçek OCR (Tesseract) ile metin çıkarır.

Not: Qwen3.5 kendisi de multimodal (görseli doğrudan okuyabilir), ama karakter
seviyesinde kesinlik gerektiren durumlarda (hata kodları, stack trace'ler)
genel bir "görseli açıkla" isteği parafraz/yuvarlama riski taşır. Bu yüzden
gerçek bir OCR motoru kullanılıyor; Qwen3.5 sadece çıkan METNİ yorumlayıp
cevap üretiyor, görselin kendisini görmüyor.
"""
from __future__ import annotations

import io

import pytesseract
from PIL import Image


def ocr_image(image_bytes: bytes) -> str:
    """Görsel bytes -> OCR ile çıkarılan metin. Türkçe + İngilizce birlikte
    denenir (ekran görüntülerinde ikisi de sık karışık geçebiliyor)."""
    img = Image.open(io.BytesIO(image_bytes))
    text = pytesseract.image_to_string(img, lang="tur+eng")
    return text.strip()
