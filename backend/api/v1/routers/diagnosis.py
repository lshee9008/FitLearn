from fastapi import APIRouter, HTTPException, Request
from slowapi import Limiter
from slowapi.util import get_remote_address

from models.diagnosis import DiagnosisRequest, DiagnosisResponse, LearningProfile
from services.gemini_service import GeminiService
from services.firebase_service import FirebaseService

router = APIRouter(tags=["diagnosis"])
limiter = Limiter(key_func=get_remote_address)
gemini = GeminiService()
firebase = FirebaseService()


@router.post("/diagnosis", response_model=DiagnosisResponse)
@limiter.limit("10/minute")
async def run_diagnosis(request: Request, body: DiagnosisRequest):
    """15문항 답변 → Gemini 심리 분석 → Firestore 저장"""
    try:
        answers = [a.model_dump() for a in body.answers]
        result = await gemini.analyze_psychology(answers)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"AI 분석 실패: {e}")

    profile = LearningProfile(
        primary_style=result.get("primary_style", "시각형"),
        secondary_style=result.get("secondary_style", "읽기형"),
        social_type=result.get("social_type", "내향형"),
        cognitive_type=result.get("cognitive_type", "분석형"),
        personality_summary=result.get("personality_summary", ""),
    )
    report = {
        "strengths": result.get("strengths", []),
        "weaknesses": result.get("weaknesses", []),
        "recommendations": result.get("recommendations", []),
        "ai_analysis": result.get("ai_analysis", ""),
    }

    await firebase.save_diagnosis(body.user_id, profile.model_dump(), report)

    return DiagnosisResponse(
        user_id=body.user_id,
        profile=profile,
        **report,
    )


@router.get("/diagnosis/{user_id}", response_model=DiagnosisResponse)
async def get_diagnosis(user_id: str):
    data = await firebase.get_diagnosis(user_id)
    if not data:
        raise HTTPException(status_code=404, detail="진단 결과가 없습니다.")
    profile = LearningProfile(**data["profile"])
    report = data.get("report", {})
    return DiagnosisResponse(user_id=user_id, profile=profile, **report)
