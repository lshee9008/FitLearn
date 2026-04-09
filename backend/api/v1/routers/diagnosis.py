import logging
from fastapi import APIRouter, HTTPException, Request
from slowapi import Limiter
from slowapi.util import get_remote_address

from models.diagnosis import DiagnosisRequest, DiagnosisResponse, LearningProfile, DimensionScores
from services.gemini_service import GeminiService
from services.firebase_service import FirebaseService

logger = logging.getLogger(__name__)
router = APIRouter(tags=["diagnosis"])
limiter = Limiter(key_func=get_remote_address)
gemini = GeminiService()
firebase = FirebaseService()


@router.post("/diagnosis", response_model=DiagnosisResponse)
@limiter.limit("10/minute")
async def run_diagnosis(request: Request, body: DiagnosisRequest):
    """15문항 답변 → Gemini 6차원 분석 → Firestore 저장"""
    logger.info(f"[diagnosis] user_id={body.user_id} answers={len(body.answers)}문항")
    try:
        answers = [a.model_dump() for a in body.answers]
        result = await gemini.analyze_psychology(answers)
    except Exception as e:
        logger.error(f"[diagnosis] Gemini 분석 실패: {e}", exc_info=True)
        raise HTTPException(status_code=502, detail=f"AI 분석 실패: {e}")

    try:
        scores = DimensionScores(**result.get("scores", {
            "visual": 50, "analytical": 50, "focus_depth": 50,
            "detail_pref": 50, "speed": 50, "collaboration": 50,
        }))
        profile = LearningProfile(
            learning_style=result.get("learning_style", "읽기형"),
            cognitive_style=result.get("cognitive_style", "분석형"),
            focus_pattern=result.get("focus_pattern", "단기집중형"),
            preferred_format=result.get("preferred_format", "요약형"),
            pace=result.get("pace", "속도형"),
            interaction=result.get("interaction", "독립형"),
            scores=scores,
            analysis=result.get("analysis", ""),
        )
        report = {
            "strengths": result.get("strengths", []),
            "weaknesses": result.get("weaknesses", []),
            "strategies": result.get("strategies", []),
        }
    except Exception as e:
        logger.error(f"[diagnosis] 프로필 파싱 실패: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"결과 처리 실패: {e}")

    await firebase.save_diagnosis(body.user_id, profile.model_dump(), report)
    logger.info(f"[diagnosis] 완료 user_id={body.user_id} style={profile.learning_style}")

    return DiagnosisResponse(user_id=body.user_id, profile=profile, **report)


@router.get("/diagnosis/{user_id}", response_model=DiagnosisResponse)
async def get_diagnosis(user_id: str):
    data = await firebase.get_diagnosis(user_id)
    if not data:
        raise HTTPException(status_code=404, detail="진단 결과가 없습니다.")
    try:
        raw = data["profile"]
        scores = DimensionScores(**raw.get("scores", {
            "visual": 50, "analytical": 50, "focus_depth": 50,
            "detail_pref": 50, "speed": 50, "collaboration": 50,
        }))
        profile = LearningProfile(
            learning_style=raw.get("learning_style", "읽기형"),
            cognitive_style=raw.get("cognitive_style", "분석형"),
            focus_pattern=raw.get("focus_pattern", "단기집중형"),
            preferred_format=raw.get("preferred_format", "요약형"),
            pace=raw.get("pace", "속도형"),
            interaction=raw.get("interaction", "독립형"),
            scores=scores,
            analysis=raw.get("analysis", ""),
        )
        report = data.get("report", {})
        return DiagnosisResponse(user_id=user_id, profile=profile, **report)
    except Exception as e:
        logger.error(f"[get_diagnosis] 파싱 실패 user_id={user_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="진단 데이터 파싱 실패")
