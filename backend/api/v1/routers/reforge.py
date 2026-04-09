from fastapi import APIRouter, Request
from fastapi.responses import StreamingResponse
from slowapi.util import get_remote_address
from slowapi import Limiter

from models.lecture import ReforgeRequest
from services.claude_service import ClaudeService

router = APIRouter(tags=["reforge"])
limiter = Limiter(key_func=get_remote_address)
claude = ClaudeService()


@router.post("/reforge")
@limiter.limit("5/minute")
async def reforge_lecture(request: Request, body: ReforgeRequest):
    """교안을 RAG 기반으로 3가지 학습 유형에 맞게 병렬 재가공 (SSE 스트리밍)"""
    return StreamingResponse(
        claude.reforge_parallel_stream(body.lecture_content, body.user_id),
        media_type="text/event-stream",
    )
