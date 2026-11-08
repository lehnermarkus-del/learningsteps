from datetime import datetime, timezone
from uuid import uuid4
from pydantic import BaseModel, ConfigDict, Field


class EntryCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    work: str = Field(min_length=1, max_length=256, description="Was hast du heute gelernt?")
    struggle: str = Field(min_length=1, max_length=256, description="Was war schwierig?")
    intention: str = Field(min_length=1, max_length=256, description="Was ist dein nächstes Ziel?")


class EntryUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    work: str = Field(default=None, min_length=1, max_length=256)
    struggle: str = Field(default=None, min_length=1, max_length=256)
    intention: str = Field(default=None, min_length=1, max_length=256)


class Entry(EntryCreate):
    id: str = Field(default_factory=lambda: str(uuid4()))
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
