import logging
import os
from contextlib import asynccontextmanager
from typing import Annotated, Any

from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel
from starlette.concurrency import run_in_threadpool

from service.scoring import evaluate

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("laya-evaluator")

DEFAULT_MODEL = "convaiinnovations/laya-typed-decisions"


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


def _check_bearer(authorization: str | None, expected_key: str) -> None:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="missing or invalid authorization header")
    token = authorization.removeprefix("Bearer ").strip()
    if token != expected_key:
        raise HTTPException(status_code=401, detail="unauthorized")


def create_app(agent: Any = None) -> FastAPI:
    expected_key = _get_api_key()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        if agent is not None:
            app.state.agent = agent
            logger.info("Using injected mock/custom agent")
        else:
            import laya

            model_id = os.environ.get("LAYA_MODEL_ID", DEFAULT_MODEL).strip() or DEFAULT_MODEL
            logger.info(f"Loading Laya model: {model_id}...")
            loaded_agent = laya.load(model_id)

            # 🚀 啟動預熱：消除首次推理的冷啟動延遲
            logger.info("Pre-warming Laya model...")
            try:
                evaluate(loaded_agent, "echo ready")
                logger.info("Laya model successfully warmed up and ready.")
            except Exception as e:
                logger.warning(f"Model warmup failed: {e}")

            app.state.agent = loaded_agent
        yield
        logger.info("Shutting down evaluator service.")

    app = FastAPI(title="Laya Semantic Evaluator", lifespan=lifespan)

    def require_auth(authorization: Annotated[str | None, Header()] = None) -> None:
        _check_bearer(authorization, expected_key)

    @app.post("/eval", response_model=EvalResponse)
    async def eval_route(body: EvalRequest, _: Annotated[None, Depends(require_auth)]):
        if not body.content.strip():
            return EvalResponse(score=0.0, reason="empty_payload", action="ALLOW")

        try:
            # 🚀 透過 threadpool 執行 CPU/GPU 密集型推理，避免阻塞 asyncio 事件循環
            score, reason = await run_in_threadpool(evaluate, app.state.agent, body.content)
        except Exception as exc:
            logger.exception("Inference error occurred")
            raise HTTPException(status_code=500, detail=f"evaluation error: {str(exc)}") from exc

        action = "BLOCK" if score >= 0.5 else "ALLOW"
        return EvalResponse(score=round(score, 4), reason=reason, action=action)

    @app.get("/healthz")
    async def health():
        return {"status": "ok"}

    return app
