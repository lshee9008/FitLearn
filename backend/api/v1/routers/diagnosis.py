import logging
from fastapi import APIRouter, HTTPException, Request
from slowapi import Limiter
from slowapi.util import get_remote_address

from models.diagnosis import (
    DiagnosisRequest, DiagnosisResponse, LearningProfile, DimensionScores
)
from services.diagnosis_service import DiagnosisService
from services.firebase_service import FirebaseService

logger = logging.getLogger(__name__)
router = APIRouter(tags=["diagnosis"])
limiter = Limiter(key_func=get_remote_address)

diagnosis_svc = DiagnosisService()
firebase = FirebaseService()

_STYLE_MAP = {"A": "시각형", "B": "청각형", "C": "읽기형", "D": "실습형"}

def _fallback_result(answers) -> dict:
    """AI 분석 실패 시 답변 패턴 기반 기본 결과 반환"""
    a_map = {a.question_id: a.answer for a in answers}
    style_counts = {"A": 0, "B": 0, "C": 0, "D": 0}
    for i in range(1, 6):
        ans = a_map.get(i, "C")
        if ans in style_counts:
            style_counts[ans] += 1
    dominant = max(style_counts, key=lambda k: style_counts[k])
    learning_style = _STYLE_MAP.get(dominant, "읽기형")

    cognitive_a = sum(1 for i in range(6, 11) if a_map.get(i) == "A")
    cognitive_style = "분석형" if cognitive_a >= 3 else "직관형"
    focus_pattern = "단기집중형" if a_map.get(12) == "A" else "장기몰입형"
    pace = "속도형" if a_map.get(13) == "A" else "숙고형"
    interaction = "독립형" if a_map.get(14) == "A" else "협력형"

    base = 40 + style_counts[dominant] * 10
    return {
        "learning_style": learning_style,
        "cognitive_style": cognitive_style,
        "focus_pattern": focus_pattern,
        "preferred_format": "요약형",
        "pace": pace,
        "interaction": interaction,
        "scores": {
            "visual": base if dominant == "A" else 30,
            "analytical": base if dominant == "C" else 35,
            "focus_depth": 50,
            "detail_pref": 40,
            "speed": base if pace == "속도형" else 35,
            "collaboration": base if interaction == "협력형" else 30,
        },
        "vark": {"visual": 50, "aural": 30, "read_write": 50, "kinesthetic": 40},
        "felder": {"sensing_intuitive": 20, "sequential_global": -10, "active_reflective": 10},
        "cognitive_load": {"intrinsic": 50, "extraneous": 30, "germane": 60},
        "kolb_type": "동화형",
        "confidence_score": 30,
        "analysis": f"답변 패턴 분석 결과 {learning_style} 성향이 나타났습니다. (AI 분석 서비스 일시 불가로 기본 분석이 제공됩니다)",
        "strengths": ["자기 주도적 학습 능력", "체계적 사고"],
        "weaknesses": ["다양한 학습 방식 시도 필요"],
        "strategies": [
            f"{learning_style} 학습자에게 적합한 자료를 활용하세요.",
            "짧은 단위로 나눠 학습하면 효과적입니다.",
            "복습 주기를 일정하게 유지하세요.",
        ],
        "paper_citations": [],
    }


@router.post("/diagnosis", response_model=DiagnosisResponse)
@limiter.limit("10/minute")
async def run_diagnosis(request: Request, body: DiagnosisRequest):
    """
    15문항 → RAG 논문 검색 → Gemini 분석(temperature=0.1) → 후처리 → Firestore 저장
    Redis 동일 답변 패턴 캐싱
    """
    logger.info(f"[diagnosis] user={body.user_id} answers={len(body.answers)}문항")
    try:
        answers = [a.model_dump() for a in body.answers]
        result = await diagnosis_svc.analyze(body.user_id, answers)
    except Exception as e:
        logger.error(f"[diagnosis] 분석 실패: {type(e).__name__}: {e}", exc_info=True)
        # AI 실패 시 답변 패턴 기반 기본값으로 폴백
        result = _fallback_result(body.answers)

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
        # 논문 인용, VARK, Felder, CLT, Kolb 확장 데이터 저장
        extra = {
            "vark": result.get("vark", {}),
            "felder": result.get("felder", {}),
            "cognitive_load": result.get("cognitive_load", {}),
            "kolb_type": result.get("kolb_type", ""),
            "confidence_score": result.get("confidence_score", 70),
            "paper_citations": result.get("paper_citations", []),
        }
    except Exception as e:
        logger.error(f"[diagnosis] 프로필 파싱 실패: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"결과 처리 실패: {e}")

    merged_profile = {**profile.model_dump(), **extra}
    await firebase.save_diagnosis(body.user_id, merged_profile, report)
    logger.info(
        f"[diagnosis] 완료 user={body.user_id} style={profile.learning_style} "
        f"confidence={extra.get('confidence_score')}%"
    )

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
        logger.error(f"[get_diagnosis] 파싱 실패 user={user_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="진단 데이터 파싱 실패")
