import asyncio
import logging
import traceback
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# ── 라우터 임포트 (각각 독립적으로 에러 감지) ─────────────────────────────
_import_errors: list[str] = []

try:
    from api.v1.routers import auth
    logger.info("[import] ✅ auth 라우터")
except Exception as e:
    logger.error(f"[import] ❌ auth 라우터 실패: {e}\n{traceback.format_exc()}")
    _import_errors.append(f"auth: {e}")
    auth = None

try:
    from api.v1.routers import rooms
    logger.info("[import] ✅ rooms 라우터")
except Exception as e:
    logger.error(f"[import] ❌ rooms 라우터 실패: {e}\n{traceback.format_exc()}")
    _import_errors.append(f"rooms: {e}")
    rooms = None

try:
    from api.v1.routers import diagnosis
    logger.info("[import] ✅ diagnosis 라우터")
except Exception as e:
    logger.error(f"[import] ❌ diagnosis 라우터 실패: {e}\n{traceback.format_exc()}")
    _import_errors.append(f"diagnosis: {e}")
    diagnosis = None

try:
    from api.v1.routers import lectures
    logger.info("[import] ✅ lectures 라우터")
except Exception as e:
    logger.error(f"[import] ❌ lectures 라우터 실패: {e}\n{traceback.format_exc()}")
    _import_errors.append(f"lectures: {e}")
    lectures = None

try:
    from api.v1.routers import dashboard
    logger.info("[import] ✅ dashboard 라우터")
except Exception as e:
    logger.error(f"[import] ❌ dashboard 라우터 실패: {e}\n{traceback.format_exc()}")
    _import_errors.append(f"dashboard: {e}")
    dashboard = None

try:
    from services.rag_pipeline.preprocessor import PaperVectorStore
    logger.info("[import] ✅ PaperVectorStore")
    _rag_available = True
except Exception as e:
    logger.error(f"[import] ❌ PaperVectorStore 실패: {e}\n{traceback.format_exc()}")
    _import_errors.append(f"PaperVectorStore: {e}")
    PaperVectorStore = None
    _rag_available = False

# ── CORS 허용 출처 ────────────────────────────────────────────────────────────
ALLOW_ORIGINS = [
    "https://fit-learn-phi.vercel.app",
    "http://localhost:3000",
    "http://localhost:8080",
]

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "*",
}


# ── Lifespan ──────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    if _import_errors:
        logger.warning(f"[startup] ⚠️ 임포트 실패 모듈: {_import_errors}")
    else:
        logger.info("[startup] 모든 모듈 임포트 성공")

    async def _init_rag():
        if _rag_available and PaperVectorStore is not None:
            try:
                await PaperVectorStore.initialize()
                logger.info("[startup] ✅ RAG 벡터 DB 초기화 완료")
            except Exception as e:
                logger.error(f"[startup] ❌ RAG 초기화 실패: {e}")
        else:
            logger.warning("[startup] ⚠️ RAG 비활성화 (PaperVectorStore 임포트 실패)")

    # 서버가 포트를 먼저 열고 RAG는 백그라운드에서 초기화
    asyncio.create_task(_init_rag())

    yield
    logger.info("[shutdown] 서버 종료")


# ── FastAPI 앱 ────────────────────────────────────────────────────────────────
limiter = Limiter(key_func=get_remote_address)
app = FastAPI(title="FitLearn API", version="3.0.0", lifespan=lifespan)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ── 전역 500 에러 핸들러 — CORS 헤더 포함 ────────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(
        f"[500] {request.method} {request.url.path} → {type(exc).__name__}: {exc}\n"
        + traceback.format_exc()
    )
    origin = request.headers.get("origin", "*")
    allow_origin = origin if origin in ALLOW_ORIGINS else ALLOW_ORIGINS[0]
    return JSONResponse(
        status_code=500,
        content={"detail": f"서버 내부 오류: {type(exc).__name__}"},
        headers={
            "Access-Control-Allow-Origin": allow_origin,
            "Access-Control-Allow-Credentials": "true",
            "Access-Control-Allow-Methods": "*",
            "Access-Control-Allow-Headers": "*",
        },
    )

# ── 라우터 등록 (임포트 성공한 것만) ─────────────────────────────────────────
if auth:
    app.include_router(auth.router, prefix="/api/v1")
if rooms:
    app.include_router(rooms.router, prefix="/api/v1")
if diagnosis:
    app.include_router(diagnosis.router, prefix="/api/v1")
if lectures:
    app.include_router(lectures.router, prefix="/api/v1")
if dashboard:
    app.include_router(dashboard.router, prefix="/api/v1")

# ── CORS 미들웨어 — 반드시 마지막에 추가 ─────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOW_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── 헬스체크 ──────────────────────────────────────────────────────────────────
@app.get("/api/v1/health")
async def health():
    return {
        "status": "ok",
        "version": "3.0.0",
        "rag": _rag_available and (PaperVectorStore is not None and PaperVectorStore.get_store() is not None),
        "import_errors": _import_errors,
        "routers": {
            "auth": auth is not None,
            "rooms": rooms is not None,
            "diagnosis": diagnosis is not None,
            "lectures": lectures is not None,
            "dashboard": dashboard is not None,
        },
    }
