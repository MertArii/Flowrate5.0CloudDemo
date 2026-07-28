from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    ollama_base_url: str = "http://host.docker.internal:11434"
    database_url: str = "postgresql://helpdesk:changeme@postgres:5432/helpdesk"
    redis_url: str = "redis://redis:6379/0"

    # Yüklenen dosyaların api ve worker arasında paylaşıldığı dizin.
    upload_dir: str = "data/uploads"

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


settings = Settings()
