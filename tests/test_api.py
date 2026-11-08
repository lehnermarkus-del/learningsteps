from unittest.mock import AsyncMock
from fastapi.testclient import TestClient
from main import app
from routers.journal_router import get_entry_service

service = AsyncMock()
app.dependency_overrides[get_entry_service] = lambda: service
client = TestClient(app)


def test_create_and_validation():
    service.create_entry.return_value = {"id": "abc", "work": "Terraform"}
    response = client.post("/entries", json={"work": "Terraform", "struggle": "DNS", "intention": "Tests"})
    assert response.status_code == 201
    assert response.json()["entry"]["id"] == "abc"
    assert client.post("/entries", json={"work": "", "struggle": "DNS", "intention": "Tests"}).status_code == 422


def test_get_and_missing():
    service.get_entry.return_value = {"id": "abc"}
    assert client.get("/entries/abc").json()["id"] == "abc"
    service.get_entry.return_value = None
    assert client.get("/entries/missing").status_code == 404


def test_delete_and_missing():
    service.get_entry.return_value = {"id": "abc"}
    assert client.delete("/entries/abc").status_code == 204
    service.delete_entry.assert_awaited_with("abc")
    service.get_entry.return_value = None
    assert client.delete("/entries/missing").status_code == 404


def test_patch_rejects_internal_fields_and_null():
    assert client.patch("/entries/abc", json={"id": "new"}).status_code == 422
    assert client.patch("/entries/abc", json={"work": None}).status_code == 422


def test_partial_update_preserves_fields():
    from services.entry_service import EntryService
    import asyncio
    db = AsyncMock()
    db.get_entry.return_value = {"id": "abc", "work": "alt", "struggle": "DNS", "intention": "Tests", "created_at": "2026-01-01"}
    result = asyncio.run(EntryService(db).update_entry("abc", {"work": "neu"}))
    assert result["work"] == "neu"
    assert result["struggle"] == "DNS"
    assert result["intention"] == "Tests"
    assert result["created_at"] == "2026-01-01"


def test_health():
    assert client.get("/health/live").status_code == 200
    app.state.pool = AsyncMock()
    assert client.get("/health/ready").status_code == 200
    app.state.pool.fetchval.side_effect = RuntimeError("nicht verfügbar")
    assert client.get("/health/ready").status_code == 503
    assert b'learningsteps_database_up 0.0' in client.get("/metrics").content
