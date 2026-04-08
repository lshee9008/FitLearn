from fastapi import APIRouter, Request, HTTPException
from slowapi import Limiter
from slowapi.util import get_remote_address

from models.diagnosis import DiagnosisRequest, DiagnosisResponse
from services.claude_service import ClaudeService
from services.firebase_service import FirebaseService

router = APIRouter(tags=["diagnosis"])
limiter = Limiter(key_func=get_remote_address)
gemini = ClaudeService()
firebase = FirebaseService()

DESCRIPTIONS: dict[str, str] = {
    "요약형": (
        "핵심만 빠르게 파악하는 스타일이에요. "
        "bullet point 중심의 간결한 요약본으로 학습하면 가장 효과적입니다. "
        "불필요한 설명 없이 핵심 개념과 키워드를 빠르게 습득할 수 있어요."
    ),
    "상세형": (
        "단계별 논리적 이해를 선호하는 스타일이에요. "
        "개념 간의 연결 관계와 원리를 깊이 있게 설명하는 방식이 가장 잘 맞습니다. "
        "왜(Why)와 어떻게(How)를 충분히 이해한 후 학습을 진행해요."
    ),
    "예시형": (
        "실제 사례와 예시로 이해하는 스타일이에요. "
        "실생활 예시와 코드 예제를 통해 개념을 체험하면 가장 효과적입니다. "
        "추상적인 이론보다 구체적인 적용 사례로 빠르게 익힐 수 있어요."
    ),
}


@router.post("/diagnosis", response_model=DiagnosisResponse)
@limiter.limit("10/minute")
async def run_diagnosis(request: Request, body: DiagnosisRequest):
    """수강생 응답을 Gemini로 분석해 학습 유형(요약형/상세형/예시형)을 분류하고 Firestore에 저장"""
    try:
        learning_type = await gemini.classify_learning_type(body.answers)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"AI 분류 실패: {e}")

    description = DESCRIPTIONS.get(learning_type, DESCRIPTIONS["요약형"])

    await firebase.save_diagnosis(
        user_id=body.user_id,
        learning_type=learning_type,
        answers=body.answers,
    )

    return DiagnosisResponse(
        user_id=body.user_id,
        learning_type=learning_type,
        description=description,
    )
