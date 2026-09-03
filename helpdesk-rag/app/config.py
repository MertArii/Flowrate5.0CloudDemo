from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    ollama_base_url: str = "http://host.docker.internal:11434"
    # BİLEREK varsayılanı yok: DATABASE_URL ortam değişkeni/.env'den
    # sağlanmazsa uygulama net bir hatayla AÇILAMAMALI — sessizce
    # "changeme" gibi sahte bir şifreyle yanlış bir DB'ye (ya da yanlış
    # yapılandırılmış bir container'a) bağlanmaya çalışmamalı. Bu tam
    # olarak 2026-09-02'deki veri kaybı olayının kök nedenlerinden biriydi.
    database_url: str
    redis_url: str = "redis://redis:6379/0"

    # Yüklenen dosyaların api ve worker arasında paylaşıldığı dizin.
    upload_dir: str = "data/uploads"

    # Loglama
    log_level: str = "INFO"
    log_format: str = "json"  # "json" veya "text"

    llm_model: str = "qwen3.5:9b"
    embed_model: str = "bge-m3"
    embed_dim: int = 1024

    chunk_size: int = 800
    chunk_overlap: int = 120
    top_k: int = 5

    # Opsiyonel benzerlik eşiği (cosine skoru). 0.0 = kapalı (varsayılan).
    # Bu değerin altındaki parçalar bağlamdan elenir; hiçbiri geçemezse
    # sistem "elimde bilgi yok" ile reddeder (modele hiç sormadan).
    min_score: float = 0.0

    # Triyaj sınıflandırma güven eşiği. Altındaysa otomatik atama yapılmaz,
    # insan triyajına düşer. (Kategori/ekip verisi DB'de; bu eşik bir ayar
    # olduğu için MIN_SCORE ile aynı mantıkla config'te tutuluyor.)
    triage_guven_esigi: float = 0.6


settings = Settings()
