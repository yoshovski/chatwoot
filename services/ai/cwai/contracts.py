import base64
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

MAX_TEXT = 100_000
MAX_ORIGINAL = 10 * 1024 * 1024


class Contract(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)


class BaseCreate(Contract):
    name: str = Field(min_length=1, max_length=200)


class BaseUpdate(Contract):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    enabled: bool | None = None

    @model_validator(mode="after")
    def supplied_values(self):
        if not self.model_fields_set or any(
            getattr(self, f) is None for f in self.model_fields_set
        ):
            raise ValueError("Supply non-null fields")
        return self


class SourceCreate(Contract):
    name: str = Field(min_length=1, max_length=200)
    text: str = Field(min_length=1, max_length=MAX_TEXT)
    source_url: str | None = Field(default=None, max_length=2000)
    provenance: dict = Field(default_factory=dict)
    original_base64: str | None = Field(default=None, max_length=(MAX_ORIGINAL + 2) // 3 * 4)
    filename: str | None = Field(default=None, min_length=1, max_length=200)
    media_type: str | None = Field(default=None, min_length=1, max_length=100)

    @model_validator(mode="after")
    def original_metadata(self):
        supplied = [
            self.original_base64 is not None,
            self.filename is not None,
            self.media_type is not None,
        ]
        if any(supplied) and not all(supplied):
            raise ValueError("Original bytes, filename and media type must be supplied together")
        if self.original_base64 is not None:
            try:
                data = base64.b64decode(self.original_base64, validate=True)
            except ValueError:
                raise ValueError("Original must be valid base64") from None
            if not data or len(data) > MAX_ORIGINAL:
                raise ValueError("Original must contain 1 byte to 10 MiB")
        return self


class EntryCreate(Contract):
    question: str = Field(min_length=1, max_length=MAX_TEXT)
    answer: str = Field(min_length=1, max_length=MAX_TEXT)
    source_id: str | None = None
    source_revision_id: str | None = None
    provenance: dict = Field(default_factory=dict)
    review_state: Literal["draft", "approved"] = "approved"

    @model_validator(mode="after")
    def source_ids(self):
        if (self.source_id is None) != (self.source_revision_id is None):
            raise ValueError("Supply source and source revision together")
        for value in (self.source_id, self.source_revision_id):
            if value is not None:
                UUID(value)
        return self


class StateUpdate(Contract):
    enabled: bool


class ReviewUpdate(Contract):
    review_state: Literal["draft", "approved"]


class AgentCreate(Contract):
    chatwoot_agent_bot_id: int = Field(gt=0)


class Retrieval(Contract):
    query: str = Field(min_length=1, max_length=2000)
    top_k: int = Field(default=5, ge=1, le=20)


class SearchDataset(Contract):
    dataset_id: str = Field(pattern=r"^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$")
    kind: Literal["faq", "document", "catalog", "extra"]
    limit: int = Field(default=6, ge=1, le=20)


class KnowledgeSearch(Contract):
    account_id: int = Field(gt=0)
    query: str = Field(min_length=1, max_length=10_000)
    keywords: str = Field(default="", max_length=420)
    datasets: list[SearchDataset] = Field(min_length=1, max_length=20)

    @model_validator(mode="after")
    def unique_datasets(self):
        if not self.query.strip():
            raise ValueError("Query must contain text")
        if len({dataset.dataset_id for dataset in self.datasets}) != len(self.datasets):
            raise ValueError("Supply each dataset only once")
        return self


class KnowledgePassage(Contract):
    id: int
    kind: Literal["faq", "document", "catalog", "extra"]
    dataset_id: str
    document_id: str
    title: str
    content: str = Field(max_length=8000)
    url: str | None
    handle: str | None
    score: float


class KnowledgeSearchResult(Contract):
    status: Literal["ok", "no_match"]
    query: str
    passages: list[KnowledgePassage] = Field(max_length=5)


class Citations(Contract):
    binding_ids: list[str] = Field(min_length=1, max_length=20)


class EntryEdit(EntryCreate):
    expected_version: int = Field(gt=0)


class SourceEdit(SourceCreate):
    expected_version: int = Field(gt=0)


class CSVUpload(Contract):
    csv: str = Field(min_length=1, max_length=5 * 1024 * 1024)
