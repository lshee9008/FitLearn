import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from api.v1.routers import auth, rooms, diagnosis, lectures, dashboard
from services.rag_pipeline.preprocessor import PaperVectorStore

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """서버 시작 시 논문 벡터 DB 1회 초기화 (메모리 캐싱)"""
    try:
        await PaperVectorStore.initialize()
        logger.info("[startup] RAG 벡터 DB 초기화 완료")
    except Exception as e:
        logger.error(f"[startup] RAG 초기화 실패 (진단 기능 제한): {e}")
    yield
    logger.info("[shutdown] 서버 종료")


limiter = Limiter(key_func=get_remote_address)

app = FastAPI(title="FitLearn API", version="3.0.0", lifespan=lifespan)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.include_router(auth.router, prefix="/api/v1")
app.include_router(rooms.router, prefix="/api/v1")
app.include_router(diagnosis.router, prefix="/api/v1")
app.include_router(lectures.router, prefix="/api/v1")
app.include_router(dashboard.router, prefix="/api/v1")

# CORS는 반드시 마지막에 추가 — 실행 순서상 가장 바깥에서 동작
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://fit-learn-phi.vercel.app",
        "http://localhost:3000",
        "http://localhost:8080",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/v1/health")
async def health():
    return {
        "status": "ok",
        "version": "3.0.0",
        "rag": PaperVectorStore.get_store() is not None,
    }
