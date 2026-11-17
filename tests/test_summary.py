import asyncio
import json
from unittest.mock import AsyncMock

import httpx
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from main import app
from routers.journal_router import get_entry_service
from services.summary_service import summarize


@pytest.fixture
def config(monkeypatch):
    monkeypatch.setenv("AZURE_OPENAI_ENDPOINT", "https://test-resource.openai.azure.com")
    monkeypatch.setenv("AZURE_OPENAI_DEPLOYMENT", "gpt-5-mini")
    monkeypatch.setenv("AZURE_OPENAI_API_KEY", "test-only-secret")
    monkeypatch.delenv("AZURE_OPENAI_API_KEY_FILE", raising=False)


def test_full_notes_server_request_and_safe_result(config, monkeypatch):
    captured = []
    def handle(request):
        captured.append(request)
        return httpx.Response(200, json={"choices": [{"message": {"content": "Terraform und DNS gelernt."},
                                                      "finish_reason": "stop"}]})
    real_client = httpx.AsyncClient
    monkeypatch.setattr("services.summary_service.httpx.AsyncClient",
                        lambda **kwargs: real_client(transport=httpx.MockTransport(handle), **kwargs))
    result = asyncio.run(summarize([
        {"id": "2", "created_at": "2026-11-17", "work": "DNS", "struggle": "TTL", "intention": "Test"},
        {"id": "1", "created_at": "2026-11-16", "work": "Terraform", "struggle": "State", "intention": "DNS"},
    ]))
    payload = json.loads(captured[0].content)
    assert [n["work"] for n in json.loads(payload["messages"][1]["content"])] == ["Terraform", "DNS"]
    assert captured[0].headers["api-key"] == "test-only-secret"
    assert payload["store"] is False
    assert result["entry_count"] == 2
    assert "test-only-secret" not in json.dumps(result)


@pytest.mark.parametrize("kind", ["empty", "upstream", "oversize", "incomplete", "endpoint"])
def test_failures_are_closed_and_sanitized(config, monkeypatch, kind):
    def handle(request):
        if kind == "incomplete":
            return httpx.Response(200, json={"choices": [{"message": {"content": "partial"}, "finish_reason": "length"}]})
        return httpx.Response(401, text="test-only-secret private note")
    real_client = httpx.AsyncClient
    monkeypatch.setattr("services.summary_service.httpx.AsyncClient",
                        lambda **kwargs: real_client(transport=httpx.MockTransport(handle), **kwargs))
    entries = [{"work": "private note"}]
    if kind == "empty":
        entries = []
    if kind == "oversize":
        entries = [{"work": "x" * 60001}]
    if kind == "endpoint":
        monkeypatch.setenv("AZURE_OPENAI_ENDPOINT", "https://attacker.example")
    with pytest.raises(HTTPException) as exc:
        asyncio.run(summarize(entries))
    assert exc.value.status_code == {"empty": 422, "oversize": 413, "endpoint": 503}.get(kind, 502)
    assert "test-only-secret" not in str(exc.value.detail)
    assert "private note" not in str(exc.value.detail)


def test_route_uses_saved_notes_and_requires_same_origin_header(monkeypatch):
    service = AsyncMock()
    service.get_all_entries.return_value = [{"work": "Saved note"}]
    previous = app.dependency_overrides.copy()
    app.dependency_overrides[get_entry_service] = lambda: service
    summary = AsyncMock(return_value={"summary": "Saved summary", "entry_count": 1, "model": "gpt-5-mini"})
    monkeypatch.setattr("routers.summary_router.summarize", summary)
    try:
        client = TestClient(app)
        assert client.post("/ai/summary").status_code == 403
        result = client.post("/ai/summary", headers={"X-LearningSteps-Request": "summary"})
        assert result.status_code == 200
        assert result.headers["cache-control"] == "no-store"
        summary.assert_awaited_once_with(service.get_all_entries.return_value)
        assert "api-key" not in client.get("/static/app.js").text
    finally:
        app.dependency_overrides.clear()
        app.dependency_overrides.update(previous)
