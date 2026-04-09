"""
후처리 — 점수 정규화, 신뢰도 보정, 최종 유형 분류, 재가공 스타일 매핑
"""
import logging

logger = logging.getLogger(__name__)

# VARK 유형 → 재가공 스타일 매핑
VARK_TO_REFORGE = {
    "시각형": "시각형",
    "청각형": "청각형",
    "읽기형": "읽기형",
    "실습형": "실습형",
}

# Kolb 유형 → 선호 포맷 매핑
KOLB_TO_FORMAT = {
    "확산형": "예시형",    # 다양한 관점, 사례 중심
    "동화형": "상세형",    # 이론적, 체계적
    "수렴형": "예시형",    # 실용적 적용
    "적응형": "요약형",    # 빠른 핵심 파악 후 실습
}


def normalize_scores(raw: dict) -> dict:
    """0-100 범위 클램핑 + 정수 변환"""
    return {k: int(max(0, min(100, v))) for k, v in raw.items()}


def normalize_felder(raw: dict) -> dict:
    """-100~100 범위 클램핑"""
    return {k: int(max(-100, min(100, v))) for k, v in raw.items()}


def compute_confidence(result: dict, retrieved_count: int) -> int:
    """신뢰도 보정: 모델 점수 + RAG 컨텍스트 수 반영"""
    base = result.get("confidence_score", 70)
    rag_bonus = min(15, retrieved_count * 3)  # 최대 +15점
    return int(min(100, base + rag_bonus))


def classify_types(result: dict) -> dict:
    """VARK + Kolb 기반 최종 유형 분류 및 재가공 스타일 결정"""
    vark = result.get("vark", {})
    kolb = result.get("kolb_type", "동화형")
    learning_style = result.get("learning_style", "읽기형")
    preferred_format = result.get("preferred_format")

    # VARK 점수로 dominant 스타일 재검증
    vark_map = {
        "시각형": vark.get("visual", 0),
        "청각형": vark.get("aural", 0),
        "읽기형": vark.get("read_write", 0),
        "실습형": vark.get("kinesthetic", 0),
    }
    if vark_map:
        dominant_vark = max(vark_map, key=lambda k: vark_map[k])
        # 모델 분류와 VARK 불일치 시 VARK 우선
        if dominant_vark != learning_style:
            logger.debug(
                f"[Postprocessor] 유형 보정: {learning_style} → {dominant_vark}"
            )
            learning_style = dominant_vark

    # Kolb으로 선호 포맷 결정 (모델이 제공하지 않은 경우)
    if not preferred_format:
        preferred_format = KOLB_TO_FORMAT.get(kolb, "상세형")

    # 재가공 스타일 결정
    reforge_style = VARK_TO_REFORGE.get(learning_style, "읽기형")

    return {
        "learning_style": learning_style,
        "reforge_style": reforge_style,
        "preferred_format": preferred_format,
        "kolb_type": kolb,
    }


def postprocess(result: dict, retrieved: list[dict]) -> dict:
    """분석 결과 전체 후처리"""
    # 점수 정규화
    raw_scores = result.get("scores", {})
    result["scores"] = normalize_scores(raw_scores)

    raw_vark = result.get("vark", {})
    result["vark"] = normalize_scores(raw_vark)

    raw_felder = result.get("felder", {})
    result["felder"] = normalize_felder(raw_felder)

    raw_clt = result.get("cognitive_load", {})
    result["cognitive_load"] = normalize_scores(raw_clt)

    # 신뢰도 보정
    result["confidence_score"] = compute_confidence(result, len(retrieved))

    # 유형 재분류
    classified = classify_types(result)
    result["learning_style"] = classified["learning_style"]
    result["preferred_format"] = classified["preferred_format"]
    result["reforge_style"] = classified["reforge_style"]
    result["kolb_type"] = classified["kolb_type"]

    # 논문 인용 보장
    if not result.get("paper_citations"):
        result["paper_citations"] = [r["paper"] for r in retrieved]

    logger.debug(
        f"[Postprocessor] 최종 유형: {result['learning_style']} / "
        f"신뢰도: {result['confidence_score']}%"
    )
    return result
