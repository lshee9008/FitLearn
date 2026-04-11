"""
교안 AI 파이프라인 — 8단계 병렬 처리
전처리 → RAG → 핵심추출 → 분류 → 난이도판단 → 질문생성 → 후처리 → 패키징
속도 최우선: asyncio.gather() 병렬 처리
"""
import asyncio
import json
import logging
import os
import re
import time

import google.generativeai as genai

from .rag_pipeline.knowledge_base import PAPER_CHUNKS

logger = logging.getLogger(__name__)
MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
_GEMINI_QUOTA_COOLDOWN_UNTIL = 0.0


def _is_quota_error(error: Exception) -> bool:
    message = str(error).lower()
    return "429" in message or "quota" in message or "rate-limit" in message


def _activate_quota_cooldown(seconds: int = 75) -> None:
    global _GEMINI_QUOTA_COOLDOWN_UNTIL
    _GEMINI_QUOTA_COOLDOWN_UNTIL = max(
        _GEMINI_QUOTA_COOLDOWN_UNTIL,
        time.monotonic() + seconds,
    )


def _quota_cooldown_active() -> bool:
    return time.monotonic() < _GEMINI_QUOTA_COOLDOWN_UNTIL

# ── 교육 이론 기반 난이도 가중치 ────────────────────────────────────────────
DIFFICULTY_CUES = {
    "상": ["심화", "고급", "복잡", "추상", "이론", "증명", "분석", "비판", "종합"],
    "하": ["기초", "입문", "소개", "개요", "기본", "이해", "파악", "정의"],
}

# ── Sweller CLT 기반 인지부하 시사점 ──────────────────────────────────────
CLT_CONTEXT = next(
    (c["content"] for c in PAPER_CHUNKS if c["id"] == "clt_01"),
    "Sweller(1988) 인지부하 이론: 작업 기억 용량 한계 내에서 학습 최적화"
)

VARK_CONTEXT = next(
    (c["content"] for c in PAPER_CHUNKS if c["id"] == "vark_01"),
    "Fleming(1992) VARK 모델: 시각/청각/읽기/실습 학습 채널 이론"
)


def _extract_json(text: str) -> dict:
    text = text.strip()
    match = re.search(r"```(?:json)?\s*([\s\S]+?)```", text)
    if match:
        text = match.group(1).strip()
    start = text.find("{")
    end = text.rfind("}") + 1
    if start != -1 and end > start:
        text = text[start:end]
    return json.loads(text)


def _preprocess_text(raw_text: str) -> str:
    """전처리: 불필요한 공백·반복 제거, 최대 6000자 제한"""
    lines = [ln.strip() for ln in raw_text.split("\n") if ln.strip()]
    cleaned = "\n".join(lines)
    # 반복 공백 정리
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
    return cleaned[:6000]


def _count_words(text: str) -> int:
    return len(text.split())


def _fallback_extract_from_text(text: str) -> dict:
    """Gemini quota/timeouts 시에도 교수 검토 화면으로 빠르게 넘기는 로컬 분석."""
    lines = [ln.strip(" -•\t") for ln in text.splitlines() if len(ln.strip()) >= 8]
    preferred = [
        ln for ln in lines
        if re.search(r"(GAN|Generator|Discriminator|Loss|학습|모델|코드|실습|함수|데이터|네트워크|프레임워크|정의|개념)", ln, re.IGNORECASE)
    ]
    candidates = []
    for line in [*preferred, *lines]:
        normalized = re.sub(r"\s+", " ", line)
        if normalized not in candidates:
            candidates.append(normalized[:180])
        if len(candidates) >= 7:
            break
    if not candidates:
        candidates = ["원본 교안의 주요 개념과 실습 흐름을 교수 검토 기준으로 확인해야 합니다."]

    core_points = [
        {
            "id": idx + 1,
            "content": item,
            "priority": max(5 - idx // 2, 3),
            "topic": "원본 교안 기반",
            "difficulty": "중",
        }
        for idx, item in enumerate(candidates)
    ]
    topics = [p["content"][:24] for p in core_points[:4]]
    return {
        "core_points": core_points,
        "lecture_summary": "Gemini quota 또는 응답 제한으로 원본 텍스트 기반 빠른 분석을 사용했습니다. 교수 검토에서 핵심 포인트를 보정하면 학생 맞춤 교안 생성에 반영됩니다.",
        "topics": topics or ["원본 교안"],
        "learning_objectives": [
            "학습자는 원본 교안의 핵심 개념을 설명할 수 있다",
            "학습자는 교안의 실습 흐름을 따라 적용할 수 있다",
        ],
        "estimated_difficulty": "중",
        "ai_fallback": True,
    }


class LecturePipeline:
    """
    교안 업로드 시 실행되는 8단계 AI 파이프라인

    Stage 1 — 전처리 (Python): 텍스트 정제
    Stage 2 — RAG 컨텍스트 조회 (지식베이스): 교육 이론 참조
    Stage 3 — 핵심 추출 (Gemini): 7개 이하 핵심 포인트
    Stage 4 — 주제 분류 (Gemini): 개념 그룹핑
    Stage 5 — 난이도 판단 (Python+Gemini): CLT 기반 인지부하 추정
    Stage 6 — 학습 목표 생성 (Gemini): Bloom 분류 기반
    Stage 7 — 검토 질문 생성 (Gemini): 교수 피드백 유도
    Stage 8 — 후처리 (Python): 우선순위 재정렬, 패키징
    """

    def __init__(self):
        api_key = os.getenv("GEMINI_API_KEY")
        if api_key:
            genai.configure(api_key=api_key, transport="rest")
        else:
            logger.warning("[LecturePipeline] GEMINI_API_KEY 미설정 — 분석 기능 동작 보장 불가")

    def _model(self, temp: float = 0.2) -> genai.GenerativeModel:
        return genai.GenerativeModel(
            model_name=MODEL,
            generation_config=genai.GenerationConfig(
                temperature=temp,
                max_output_tokens=2048,
            ),
        )

    # ── Stage 3+4+5+6: 핵심 추출 + 분류 + 난이도 + 학습목표 (단일 프롬프트 병렬화) ──

    async def _stage_extract_all(self, text: str) -> dict:
        """
        핵심 포인트 추출 + 주제 분류 + 전체 요약 + 학습 목표 — 단일 Gemini 호출
        """
        if _quota_cooldown_active():
            raise RuntimeError("Gemini quota cooldown active")

        prompt = f"""당신은 교육 전문가입니다. 교육심리학 이론에 기반하여 다음 교안을 분석하세요.
이 분석은 이후 학생 맞춤형 '재해석 교안'의 근거가 됩니다. 절대 단순 요약으로 축소하지 마세요.

[참조 이론]
• {CLT_CONTEXT}
• {VARK_CONTEXT}

[교안 내용]
{text}

다음 JSON 형식으로만 응답하세요 (JSON 외 텍스트 없이):
{{
  "core_points": [
    {{
      "id": 1,
      "content": "핵심 포인트 내용 (1-2문장, 명확하고 구체적으로)",
      "priority": 5,
      "topic": "소속 주제명",
      "difficulty": "상"
    }}
  ],
  "lecture_summary": "교안 전체 2-3문장 요약",
  "topics": ["주제1", "주제2", "주제3"],
  "learning_objectives": [
    "학습자는 ~을 설명할 수 있다",
    "학습자는 ~을 적용할 수 있다"
  ],
  "estimated_difficulty": "중"
}}

규칙:
- core_points: 5-7개, priority는 5(최중요)~1(보통), difficulty는 상|중|하
- 코드·명령어·실습 예제·터미널 출력이 있으면 core_points에 반드시 반영
- [시각자료], [다이어그램], [슬라이드 이미지], [코드 캡처] 블록은 중요 자료로 취급
- 이미지 속 코드나 실습 흐름은 학생이 그대로 따라해야 하므로 누락 금지
- topics: 3-5개의 핵심 주제 분류
- learning_objectives: Bloom 분류 기반 3-5개 (이해/적용/분석/종합/평가)
- estimated_difficulty: 전체 난이도 상|중|하
- JSON만 출력하세요"""

        response = await asyncio.wait_for(
            asyncio.to_thread(self._model(temp=0.2).generate_content, prompt),
            timeout=55.0,
        )
        return _extract_json(response.text)

    async def _stage_review_questions(
        self, core_points: list[dict], text: str
    ) -> list[str]:
        """
        Stage 7 — 각 핵심 포인트별 교수 검토 질문 생성
        교수가 학생 관점에서 중요성·난이도·설명 방식을 재고하도록 유도
        """
        if not core_points or _quota_cooldown_active():
            return []

        points_text = "\n".join(
            f"{i+1}. [{p.get('topic','')}] {p['content']}"
            for i, p in enumerate(core_points)
        )

        prompt = f"""당신은 뛰어난 교수설계자(Instructional Designer)입니다. 교수가 추출된 각 핵심 포인트의 학습 전략적 가치와 난이도를 되돌아보게 만드는 '날카로운 검토 질문'을 생성하세요.

[핵심 포인트 목록]
{points_text}

각 포인트에 대하여, 교수가 단순 내용 확인을 넘어 '학생들의 흔한 오개념(Misconception)'이나 '실제 적용 방향'을 고민하게 만드는 수준 높은 질문 딱 1개씩을 JSON 배열로 반환하세요.

응답 예시 포맷:
{{
  "questions": [
    "학생들이 이 개념을 접할 때 가장 흔히 범하는 오개념은 무엇이며, 어떻게 바로잡을 계획이신가요?",
    "이 이론적 분석을 실무 사례나 최근 트렌드에 어떻게 접목하여 설명하실 건가요?"
  ]
}}

규칙:
1. 질문은 교사의 교수법 개선을 직접적으로 자극해야 합니다.
2. 예/아니오로 대답할 수 없는 개방형 질문이어야 합니다.
3. JSON 형식 외 어떠한 텍스트도 출력하지 마세요."""

        try:
            response = await asyncio.wait_for(
                asyncio.to_thread(self._model(temp=0.4).generate_content, prompt),
                timeout=25.0,
            )
            data = _extract_json(response.text)
            return data.get("questions", [])
        except Exception as e:
            if _is_quota_error(e):
                _activate_quota_cooldown()
                logger.warning("[Pipeline] 검토 질문 생성 quota 감지 — 건너뜀")
                return []
            logger.warning(f"[Pipeline] 검토 질문 생성 실패 (건너뜀): {e}")
            return []

    async def run(self, raw_text: str) -> dict:
        """
        전체 파이프라인 실행 — Stage 1-2는 동기, Stage 3-7은 병렬, Stage 8은 후처리
        """
        # Stage 1: 전처리
        text = _preprocess_text(raw_text)
        word_count = _count_words(text)
        logger.info(f"[Pipeline] Stage1 전처리 완료: {len(text)}자 {word_count}단어")

        # Stage 2: RAG 컨텍스트 이미 상수로 로드됨 (CLT_CONTEXT, VARK_CONTEXT)
        logger.info("[Pipeline] Stage2 RAG 컨텍스트 로드 완료")

        # Stage 3-6: 핵심 추출 + 분류 + 요약 + 학습목표 (단일 Gemini 호출)
        logger.info("[Pipeline] Stage3-6 Gemini 병렬 분석 시작")
        try:
            extract_result = await self._stage_extract_all(text)
        except Exception as e:
            if _is_quota_error(e) or "quota cooldown" in str(e).lower():
                _activate_quota_cooldown()
                logger.warning(f"[Pipeline] Gemini quota/cooldown — 로컬 분석 fallback 사용: {e}")
            elif isinstance(e, json.JSONDecodeError):
                logger.warning("[Pipeline] Gemini JSON 파싱 실패 — 로컬 분석 fallback 사용")
            else:
                logger.error(f"[Pipeline] 핵심 추출 실패 — 로컬 분석 fallback 사용: {e}", exc_info=True)
            extract_result = _fallback_extract_from_text(text)

        core_points_raw = extract_result.get("core_points", [])
        logger.info(f"[Pipeline] Stage3-6 완료: {len(core_points_raw)}개 핵심 포인트")

        # Stage 7: 검토 질문 생성 (비동기 병렬 — extract_all 완료 후)
        logger.info("[Pipeline] Stage7 검토 질문 생성 시작")
        review_questions = [] if extract_result.get("ai_fallback") else await self._stage_review_questions(core_points_raw, text)

        # Stage 8: 후처리 — 검토 질문 매핑 + 우선순위 정렬
        for i, point in enumerate(core_points_raw):
            point["review_question"] = (
                review_questions[i] if i < len(review_questions) else ""
            )
            point.setdefault("confirmed", True)

        # 우선순위 내림차순 정렬 (5→1)
        core_points_raw.sort(key=lambda x: x.get("priority", 3), reverse=True)

        # ID 재번호
        for idx, point in enumerate(core_points_raw):
            point["id"] = idx + 1

        logger.info(f"[Pipeline] Stage8 후처리 완료")

        return {
            "core_points": core_points_raw,
            "lecture_summary": extract_result.get("lecture_summary", ""),
            "topics": extract_result.get("topics", []),
            "learning_objectives": extract_result.get("learning_objectives", []),
            "estimated_difficulty": extract_result.get("estimated_difficulty", "중"),
            "word_count": word_count,
        }
