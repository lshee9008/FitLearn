import logging
from fastapi import APIRouter, HTTPException, Request
from slowapi import Limiter
from slowapi.util import get_remote_address



from models.diagnosis import (
    DiagnosisRequest, DiagnosisResponse, LearningProfile,
    DimensionScores, ReliabilityCheck,
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
    for i in range(1, 8):
        ans = a_map.get(i, "C")
        if ans in style_counts:
            style_counts[ans] += 1
    dominant = max(style_counts, key=lambda k: style_counts[k])
    learning_style = _STYLE_MAP.get(dominant, "읽기형")

    cognitive_a = sum(1 for i in range(8, 14) if a_map.get(i) == "A")
    cognitive_style = "분석형" if cognitive_a >= 3 else "직관형"
    focus_pattern = "단기집중형" if a_map.get(16) == "A" else "장기몰입형"
    pace = "속도형" if a_map.get(21) == "A" else "숙고형"
    interaction = "독립형" if a_map.get(23) == "A" else "협력형"
    base = 40 + style_counts[dominant] * 8

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
            "metacognition": 50,
            "consistency": 50,
        },
        "vark": {"visual": 50, "aural": 30, "read_write": 50, "kinesthetic": 40},
        "felder": {"sensing_intuitive": 20, "sequential_global": -10, "active_reflective": 10},
        "cognitive_load": {"intrinsic": 50, "extraneous": 30, "germane": 60},
        "kolb_type": "동화형",
        "confidence_score": 30,
        "writing_insight": "AI 분석 서비스 일시 불가",
        "analysis": f"답변 패턴 분석 결과 {learning_style} 성향이 나타났습니다. (AI 분석 일시 불가로 기본 분석 제공)",
        "strengths": ["자기 주도적 학습 능력", "체계적 사고"],
        "weaknesses": ["다양한 학습 방식 시도 필요"],
        "strategies": [
            f"{learning_style} 학습자에게 적합한 자료를 활용하세요.",
            "짧은 단위로 나눠 학습하면 효과적입니다.",
            "복습 주기를 일정하게 유지하세요.",
        ],
        "paper_citations": [],
        "reliability": {"pair_s8_s16": 0.75, "pair_s9_s17": 0.75, "pair_s11_s18": 0.75, "overall": 0.75},
    }


def _parse_profile(result: dict) -> LearningProfile:
    scores_raw = result.get("scores", {})
    scores = DimensionScores(
        visual=scores_raw.get("visual", 50),
        analytical=scores_raw.get("analytical", 50),
        focus_depth=scores_raw.get("focus_depth", 50),
        detail_pref=scores_raw.get("detail_pref", 50),
        speed=scores_raw.get("speed", 50),
        collaboration=scores_raw.get("collaboration", 50),
        metacognition=scores_raw.get("metacognition", 50),
        consistency=scores_raw.get("consistency", 50),
    )
    rel_raw = result.get("reliability", {})
    reliability = ReliabilityCheck(
        pair_s8_s16=rel_raw.get("pair_s8_s16", rel_raw.get("pair_q3_q18", 0.75)),
        pair_s9_s17=rel_raw.get("pair_s9_s17", rel_raw.get("pair_q7_q22", 0.75)),
        pair_s11_s18=rel_raw.get("pair_s11_s18", rel_raw.get("pair_q11_q24", 0.75)),
        overall=rel_raw.get("overall", 0.75),
    )
    return LearningProfile(
        learning_style=result.get("learning_style", "읽기형"),
        cognitive_style=result.get("cognitive_style", "분석형"),
        focus_pattern=result.get("focus_pattern", "단기집중형"),
        preferred_format=result.get("preferred_format", "요약형"),
        pace=result.get("pace", "속도형"),
        interaction=result.get("interaction", "독립형"),
        scores=scores,
        analysis=result.get("analysis", ""),
        reliability=reliability,
        writing_insight=result.get("writing_insight", ""),
        vark=result.get("vark", {}),
        felder=result.get("felder", {}),
        cognitive_load=result.get("cognitive_load", {}),
        kolb_type=result.get("kolb_type", ""),
        confidence_score=result.get("confidence_score", 70),
        paper_citations=result.get("paper_citations", []),
    )


@router.post("/diagnosis", response_model=DiagnosisResponse)
@limiter.limit("10/minute")
async def run_diagnosis(request: Request, body: DiagnosisRequest):
    """
    25문항 + 글쓰기 + 응답시간 + 학습이력 → RAG → Gemini → 8D 프로파일
    """
    logger.info(f"[diagnosis] user={body.user_id} answers={len(body.answers)}문항")
    try:
        answers = [a.model_dump() for a in body.answers]
        response_times = [a.response_time_ms for a in body.answers]
        result = await diagnosis_svc.analyze(
            body.user_id,
            answers,
            writing_response=body.writing_response,
            response_times=response_times,
            learning_history=body.learning_history,
        )
    except Exception as e:
        logger.error(f"[diagnosis] 분석 실패: {type(e).__name__}: {e}", exc_info=True)
        result = _fallback_result(body.answers)

    try:
        profile = _parse_profile(result)
        report = {
            "strengths": result.get("strengths", []),
            "weaknesses": result.get("weaknesses", []),
            "strategies": result.get("strategies", []),
        }
    except Exception as e:
        logger.error(f"[diagnosis] 프로필 파싱 실패: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"결과 처리 실패: {e}")

    try:
        await firebase.save_diagnosis(body.user_id, profile.model_dump(), report)
    except Exception as e:
        logger.warning(f"[diagnosis] Firebase 저장 실패 (결과는 반환): {e}")

    logger.info(f"[diagnosis] 완료 user={body.user_id} style={profile.learning_style}")
    return DiagnosisResponse(user_id=body.user_id, profile=profile, **report)


@router.get("/diagnosis/{user_id}", response_model=DiagnosisResponse)
async def get_diagnosis(user_id: str):
    data = await firebase.get_diagnosis(user_id)
    if not data:
        raise HTTPException(status_code=404, detail="진단 결과가 없습니다.")
    try:
        raw = data["profile"]
        profile = _parse_profile(raw)
        report = data.get("report", {})
        return DiagnosisResponse(user_id=user_id, profile=profile, **report)
    except Exception as e:
        logger.error(f"[get_diagnosis] 파싱 실패 user={user_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="진단 데이터 파싱 실패")


# ── 빠른 진단 (데모·첫 방문용 6문항, AI 호출 없이 즉시 결과) ─────────────────

from pydantic import BaseModel as _BaseModel

_QUICK_VARK = {"A": "시각형", "B": "청각형", "C": "읽기형", "D": "실습형"}

_QUICK_COPY = {
    "시각형": ("구조와 그림으로 먼저 전체를 파악할 때 가장 빠르게 이해하는 타입이에요.",
              ["개념 간 관계를 한눈에 파악", "복잡한 정보를 도식으로 정리"],
              ["표·흐름도 중심의 교안으로 먼저 큰 그림을 잡으세요", "새 개념은 기존 개념과 연결선을 그려 정리하세요"]),
    "청각형": ("누군가 말로 풀어 설명해줄 때 개념이 오래 남는 타입이에요.",
              ["설명을 이야기처럼 기억", "토론과 질문으로 깊이 이해"],
              ["대화체 교안을 소리 내어 읽어보세요", "배운 내용을 다른 사람에게 설명하듯 말해보세요"]),
    "읽기형": ("잘 정리된 글과 정의를 차근차근 읽으며 이해하는 타입이에요.",
              ["정확한 정의와 체계 정리", "꼼꼼한 노트 필기"],
              ["정의 → 원리 → 예시 순서의 교안을 활용하세요", "용어 사전을 직접 만들어 복습하세요"]),
    "실습형": ("직접 해보면서 손으로 익힐 때 가장 잘 배우는 타입이에요.",
              ["실전 적용과 문제 해결", "시행착오에서 빠르게 학습"],
              ["코드를 먼저 실행해보고 설명을 읽으세요", "각 단원마다 작은 미니 과제를 해보세요"]),
}


class QuickDiagnosisRequest(_BaseModel):
    user_id: str
    answers: dict[str, str]  # {"q1": "A", ...}


@router.post("/diagnosis/quick", response_model=DiagnosisResponse)
async def run_quick_diagnosis(body: QuickDiagnosisRequest):
    a = {k: (v or "").upper()[:1] for k, v in body.answers.items()}
    votes = [a.get(k) for k in ("q1", "q2", "q3") if a.get(k) in _QUICK_VARK]
    counts = {k: votes.count(k) for k in _QUICK_VARK}
    top = max(counts.values()) if votes else 0
    dominant = next((v for v in votes if counts[v] == top), "C") if votes else "C"
    style = _QUICK_VARK[dominant]

    focus = "장기몰입형" if a.get("q4") == "B" else "단기집중형"
    fmt, pace = {"A": ("요약형", "속도형"), "B": ("상세형", "숙고형"), "C": ("예시형", "숙고형")}.get(a.get("q5"), ("상세형", "숙고형"))
    diff = {"A": "직진형", "B": "우회형", "C": "지원요청형"}.get(a.get("q6"), "우회형")
    consistency = round(top / 3, 2) if votes else 0.5

    vark = {k: 25 for k in ("visual", "aural", "read_write", "kinesthetic")}
    for v in votes:
        key = {"A": "visual", "B": "aural", "C": "read_write", "D": "kinesthetic"}[v]
        vark[key] += 25
    summary, strengths, strategies = _QUICK_COPY[style]

    result = {
        "learning_style": style,
        "cognitive_style": "직관형" if style in ("시각형", "실습형") else "분석형",
        "focus_pattern": focus,
        "preferred_format": fmt,
        "pace": pace,
        "interaction": "독립형",
        "difficulty_response": diff,
        "scores": {
            "visual": vark["visual"], "analytical": 70 if style == "읽기형" else 50,
            "focus_depth": 75 if focus == "장기몰입형" else 40,
            "detail_pref": 75 if fmt == "상세형" else 40,
            "speed": 75 if pace == "속도형" else 40, "collaboration": 40,
            "metacognition": 55, "consistency": int(consistency * 100),
        },
        "vark": vark,
        "kolb_type": {"시각형": "발산형", "청각형": "발산형", "읽기형": "동화형", "실습형": "조절형"}[style],
        "confidence_score": int(55 + consistency * 35),
        "analysis": f"{summary} {focus}이며, {fmt} 설명을 선호합니다.",
        "writing_insight": "",
        "reliability": {"pair_s8_s16": consistency, "pair_s9_s17": consistency,
                        "pair_s11_s18": consistency, "overall": consistency},
        "strengths": strengths,
        "weaknesses": ["다른 방식의 설명도 함께 접해보면 이해가 더 단단해져요"],
        "strategies": strategies,
    }
    profile = _parse_profile(result)
    profile_dict = {**profile.model_dump(), "difficulty_response": diff, "quick": True}
    report = {k: result[k] for k in ("strengths", "weaknesses", "strategies")}
    await firebase.save_diagnosis(body.user_id, profile_dict, report)
    logger.info(f"[diagnosis/quick] user={body.user_id} style={style} focus={focus}")
    return DiagnosisResponse(user_id=body.user_id, profile=profile, **report)
