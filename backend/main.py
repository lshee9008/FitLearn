import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from api.v1.routers import auth, rooms, diagnosis, lectures, dashboard

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

limiter = Limiter(key_func=get_remote_address)

app = FastAPI(title="FitLearn API", version="2.0.0")

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.include_router(auth.router, prefix="/api/v1")
app.include_router(rooms.router, prefix="/api/v1")
app.include_router(diagnosis.router, prefix="/api/v1")
app.include_router(lectures.router, prefix="/api/v1")
app.include_router(dashboard.router, prefix="/api/v1")

# CORS는 반드시 마지막에 추가 — FastAPI 미들웨어는 역순 적용되므로
# 가장 마지막에 등록해야 실행 순서상 가장 바깥(첫 번째)에서 동작해
# 500 에러 응답에도 CORS 헤더가 포함됨
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
    return {"status": "ok", "version": "2.0.0"}
