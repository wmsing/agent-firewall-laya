import logging
import os
from contextlib import asynccontextmanager
from typing import Annotated, Any

from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel
from starlette.concurrency import run_in_threadpool

from service.scoring import KevBackend, evaluate

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("kev-evaluator")


class EvalRequest(BaseModel):
    content: str


class EvalResponse(BaseModel):
    score: float
    reason: str
    action: str


def _get_api_key() -> str:
    key = os.environ.get("EVALUATOR_API_KEY", "").strip()
    if not key:
        raise RuntimeError("Environment variable EVALUATOR_API_KEY is required")
    return key


def _kev_backend_from_env() -> KevBackend:
    base = os.environ.get("KEV_BASE_URL", "http://127.0.0.1:8009").strip().rstrip("/")
    key = os.environ.get("KEV_API_KEY", "local").strip()
    model = os.environ.get("KEV_MODEL", "kev-latest").strip() or "kev-latest"
    return KevBackend(base, key, model)


def _check_bearer(authorization: str | None, expected_key: str) -> None:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="missing or invalid authorization header")
    token = authorization.removeprefix("Bearer ").strip()
    if token != expected_key:
        raise HTTPException(status_code=401, detail="unauthorized")


def create_app(backend: Any = None) -> FastAPI:
    expected_key = _get_api_key()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        if backend is not None:
            app.state.backend = backend
            logger.info("Using injected mock/custom backend")
        else:
            loaded = _kev_backend_from_env()
            logger.info("Kev backend: %s model=%s", loaded.base_url, loaded.model)
            try:
                evaluate(loaded, "echo ready")
                logger.info("Kev warmup ok")
            except Exception as e:
                logger.warning("Kev warmup failed (is kev.serve running?): %s", e)
            app.state.backend = loaded
        yield
        logger.info("Shutting down evaluator service.")

    app = FastAPI(title="Semantic Evaluator Sidecar", lifespan=lifespan)

    def require_auth(authorization: Annotated[str | None, Header()] = None) -> None:
        _check_bearer(authorization, expected_key)

    @app.post("/eval", response_model=EvalResponse)
    async def eval_route(body: EvalRequest, _: Annotated[None, Depends(require_auth)]):
        if not body.content.strip():
            return EvalResponse(score=0.0, reason="empty_payload", action="ALLOW")

        try:
            score, reason = await run_in_threadpool(evaluate, app.state.backend, body.content)
        except Exception as exc:
            logger.exception("Inference error occurred")
            raise HTTPException(status_code=500, detail=f"evaluation error: {str(exc)}") from exc

        action = "BLOCK" if score >= 0.5 else "ALLOW"
        return EvalResponse(score=round(score, 4), reason=reason, action=action)

    @app.get("/healthz")
    async def health():
        return {"status": "ok"}

    return app
