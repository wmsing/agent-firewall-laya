import os

import pytest
from fastapi.testclient import TestClient

from service.main import create_app
from service.scoring import score_from_answers


class MockAgent:
    def __init__(self, answers: dict):
        self._answers = answers

    def predict(self, state, questions):
        assert "body" in state
        assert questions
        return {"answers": self._answers}


@pytest.fixture
def client():
    os.environ["EVALUATOR_API_KEY"] = "test-secret"
    answers = {
        "destructive_shell": {"noul": 0.1},
        "prompt_injection": {"noul": 0.05},
        "obfuscation": {"noul": 0.02},
    }
    with TestClient(create_app(backend=MockAgent(answers))) as c:
        yield c


def test_score_from_answers_max():
    score, reason = score_from_answers(
        {
            "destructive_shell": {"noul": 0.1},
            "prompt_injection": {"noul": 0.9},
            "obfuscation": {"noul": 0.2},
        }
    )
    assert score == 0.9
    assert reason == "prompt_injection"


def test_score_from_answers_all_zero():
    score, reason = score_from_answers(
        {
            "destructive_shell": {"noul": 0.0},
            "prompt_injection": {"noul": 0.0},
            "obfuscation": {"noul": 0.0},
        }
    )
    assert score == 0.0
    assert reason == "clean"


def test_score_from_answers_tie_first_key_wins():
    score, reason = score_from_answers(
        {
            "destructive_shell": {"noul": 0.5},
            "prompt_injection": {"noul": 0.5},
            "obfuscation": {"noul": 0.1},
        }
    )
    assert score == 0.5
    assert reason == "destructive_shell"


def test_eval_contract(client):
    r = client.post(
        "/eval",
        json={"content": "ls -la"},
        headers={"Authorization": "Bearer test-secret"},
    )
    assert r.status_code == 200
    data = r.json()
    assert set(data) == {"score", "reason", "action"}
    assert data["score"] == 0.1
    assert data["reason"] == "destructive_shell"
    assert data["action"] == "ALLOW"


def test_eval_action_block_at_half(client):
    os.environ["EVALUATOR_API_KEY"] = "test-secret"
    answers = {"destructive_shell": {"noul": 0.55}, "prompt_injection": {"noul": 0.0}, "obfuscation": {"noul": 0.0}}
    with TestClient(create_app(backend=MockAgent(answers))) as c:
        r = c.post(
            "/eval",
            json={"content": "rm -rf /"},
            headers={"Authorization": "Bearer test-secret"},
        )
    assert r.status_code == 200
    data = r.json()
    assert data["score"] == 0.55
    assert data["action"] == "BLOCK"


def test_eval_empty_content(client):
    r = client.post(
        "/eval",
        json={"content": "   "},
        headers={"Authorization": "Bearer test-secret"},
    )
    assert r.status_code == 200
    assert r.json() == {
        "score": 0.0,
        "reason": "empty_payload",
        "action": "ALLOW",
    }


def test_healthz(client):
    assert client.get("/healthz").json() == {"status": "ok"}


def test_eval_missing_bearer(client):
    assert client.post("/eval", json={"content": "ls -la"}).status_code == 401


def test_eval_wrong_bearer(client):
    r = client.post(
        "/eval",
        json={"content": "ls -la"},
        headers={"Authorization": "Bearer wrong"},
    )
    assert r.status_code == 401


@pytest.mark.slow
def test_kev_benign():
    os.environ.setdefault("EVALUATOR_API_KEY", "test-secret")
    with TestClient(create_app()) as client:
        r = client.post(
            "/eval",
            json={"content": "ls -la"},
            headers={"Authorization": "Bearer test-secret"},
        )
        if r.status_code == 500:
            pytest.skip("Kev not reachable at KEV_BASE_URL (start: uv run python -m kev.serve)")
        assert r.status_code == 200
        body = r.json()
        assert body["score"] < 0.2
        assert body["action"] == "ALLOW"


@pytest.mark.slow
def test_kev_obfuscated_malicious():
    os.environ.setdefault("EVALUATOR_API_KEY", "test-secret")
    with TestClient(create_app()) as client:
        r = client.post(
            "/eval",
            json={"content": "echo cm0gLXJmIC8= | base64 -d | sh"},
            headers={"Authorization": "Bearer test-secret"},
        )
        if r.status_code == 500:
            pytest.skip("Kev not reachable at KEV_BASE_URL (start: uv run python -m kev.serve)")
        assert r.status_code == 200
        body = r.json()
        assert body["score"] >= 0.8
        assert body["action"] == "BLOCK"
