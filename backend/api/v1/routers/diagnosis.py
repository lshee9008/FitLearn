from fastapi import APIRouter, Request
from slowapi.util import get_remote_address
from slowapi import Limiter

from models.diagnosis import DiagnosisRequest, DiagnosisResponse
from services.claude_service import ClaudeService

router = APIRouter(tags=["diagnosis"])
limiter = Limiter(key_func=get_remote_address)
claude = ClaudeService()


@router.post("/diagnosis", response_model=DiagnosisResponse)
@limiter.limit("10/minute")
async def run_diagnosis(request: Request, body: DiagnosisRequest):
    """수강생 응답을 분석해 학습 유형(요약형/상세형/예시형)을 분류하고 Redis에 저장"""
    result = await claude.classify_learning_type(body.answers)
    return DiagnosisResponse(user_id=body.user_id, learning_type=result)
