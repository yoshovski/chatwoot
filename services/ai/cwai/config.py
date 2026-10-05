from functools import lru_cache
from pathlib import Path

from pydantic import BaseModel, ConfigDict, Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class DifyConnection(BaseModel):
    model_config = ConfigDict(extra="forbid")
    url: str
    api_key: SecretStr
    embedding_provider: str
    embedding_model: str
    reranking_provider: str | None = None
    reranking_model: str | None = None


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="CWAI_", env_file=".env", extra="ignore", hide_input_in_errors=True
    )
    enabled: bool = False
    database_url: str
    signing_key: SecretStr = Field(min_length=32)
    installation_id: str
    audience: str = "cwai-knowledge"
    originals_path: Path = Path("/data/originals")
    dify_connections: dict[str, DifyConnection]
    knowledge_search_score_threshold: float = Field(default=0.35, ge=0, le=1)


@lru_cache
def settings() -> Settings:
    return Settings()
