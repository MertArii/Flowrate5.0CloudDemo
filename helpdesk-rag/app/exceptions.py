"""Uygulama genelinde kullanılan özel exception sınıfları.

Her exception sınıfının bir `status_code` özelliği vardır — global
exception handler bu kodu HTTP yanıt koduna çevirir. `detail` alanı
ise kullanıcıya döndürülecek mesajdır.

İsimlendirme: hatanın *nerede* oluştuğunu değil, *ne olduğunu*
anlatır (OllamaUnavailableError, DatabaseConnectionError...).
"""
from __future__ import annotations


class AppError(Exception):
    """Tüm uygulama hatalarının temel sınıfı.

    Alt sınıflar status_code ve varsayılan detail tanımlar; her ikisi de
    instance'da geçersiz kılınabilir (ör. daha spesifik mesajlarla).
    """

    status_code: int = 500
    default_detail: str = "Beklenmeyen bir hata oluştu."

    def __init__(self, detail: str | None = None, *, status_code: int | None = None):
        self.detail = detail or self.default_detail
        if status_code is not None:
            self.status_code = status_code
        super().__init__(self.detail)


# ---- Ollama / LLM hataları --------------------------------------------------

class OllamaUnavailableError(AppError):
    """Ollama sunucusuna TCP bağlantısı kurulamadı (container kapalı, ağ
    hatası, yanlış URL, vb.)."""
    status_code = 503
    default_detail = "Ollama sunucusuna bağlanılamıyor. Lütfen daha sonra tekrar deneyin."


class OllamaTimeoutError(AppError):
    """Ollama isteği zaman aşımına uğradı (model çok yüklü veya prompt
    aşırı uzun olabilir)."""
    status_code = 504
    default_detail = "Ollama yanıt vermedi (zaman aşımı). Lütfen daha sonra tekrar deneyin."


class OllamaModelError(AppError):
    """Ollama HTTP 4xx/5xx döndü (model bulunamadı, geçersiz payload,
    sunucu iç hatası, vb.)."""
    status_code = 502
    default_detail = "Ollama modeli yanıt veremedi."


# ---- Veritabanı hataları -----------------------------------------------------

class DatabaseConnectionError(AppError):
    """Veritabanı bağlantı havuzu boş / bağlantı kurulamadı."""
    status_code = 503
    default_detail = "Veritabanına bağlanılamıyor. Lütfen daha sonra tekrar deneyin."


class DatabaseIntegrityError(AppError):
    """Unique constraint ihlali, FK hatası, vb. — genelde çakışan kayıt."""
    status_code = 409
    default_detail = "Çakışan veya geçersiz kayıt."


# ---- OCR / görsel hataları ---------------------------------------------------

class OCRError(AppError):
    """Görsel açılamadı veya Tesseract OCR başarısız oldu."""
    status_code = 422
    default_detail = "Görsel işlenemedi. Desteklenen formatlar: PNG, JPEG, WebP."


class TesseractNotInstalledError(AppError):
    """Tesseract OCR binary'si sistemde bulunamadı."""
    status_code = 503
    default_detail = "OCR motoru (Tesseract) sunucuda yüklü değil."


# ---- Triyaj pipeline hataları -----------------------------------------------

class TriageError(AppError):
    """Triyaj pipeline'ının herhangi bir adımında yakalanmamış hata."""
    status_code = 500
    default_detail = "Triyaj işlemi sırasında bir hata oluştu."
