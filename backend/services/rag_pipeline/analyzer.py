"""
RAG 기반 Gemini 분석 — 논문 근거 + 25문항 + 글쓰기 + 응답시간 + 학습이력 → 8차원 학습 프로파일
temperature=0.1 (최대 정확도)
"""
import asyncio
import json
import logging
import os
import re
import statistics

import google.generativeai as genai

logger = logging.getLogger(__name__)
MODEL = "gemma-4-31b-it"


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


def _calc_reliability(answers: list[dict]) -> dict:
    """신뢰도 쌍 일치율 계산 (LLM 없이 Python에서 처리)"""
    def get_ans(qid: int) -> str | None:
        return next((a["answer"] for a in answers if a["question_id"] == qid), None)

    def _adjacent(a: str | None, b: str | None) -> bool:
        """인접 선택지 (A-B, B-C 등) 여부"""
        if not a or not b:
            return False
        return abs(ord(a) - ord(b)) == 1

    def match_score(q1: int, q2: int) -> float:
        a1, a2 = get_ans(q1), get_ans(q2)
        if a1 is None or a2 is None:
            return 0.75  # 결측 시 중간값
        if a1 == a2:
            return 1.0
        if _adjacent(a1, a2):
            return 0.5
        return 0.0

    p1 = match_score(8, 16)
    p2 = match_score(9, 17)
    p3 = match_score(11, 18)
    overall = (p1 + p2 + p3) / 3

    return {
        "pair_s8_s16": round(p1, 3),
        "pair_s9_s17": round(p2, 3),
        "pair_s11_s18": round(p3, 3),
        "overall": round(overall, 3),
    }


def _analyze_response_times(response_times: list[int]) -> dict:
    """응답시간 패턴 분석"""
    if not response_times:
        return {"avg_ms": 0, "slow_questions": [], "style": "알 수 없음"}

    avg = statistics.mean(response_times)
    try:
        std = statistics.stdev(response_times)
    except statistics.StatisticsError:
        std = 0

    slow = [
        i + 1 for i, t in enumerate(response_times)
        if t > avg + 1.5 * std and t > 5000
    ]

    if avg < 4000:
        style = "직관형 (빠른 응답)"
    elif avg > 10000:
        style = "분석형 (신중한 응답)"
    else:
        style = "균형형"

    return {
        "avg_ms": int(avg),
        "std_ms": int(std),
        "slow_questions": slow,
        "style": style,
    }


class RAGAnalyzer:
    def __init__(self):
        genai.configure(api_key=os.environ["GEMINI_API_KEY"], transport="rest")

    def _model(self) -> genai.GenerativeModel:
        return genai.GenerativeModel(
            model_name=MODEL,
            generation_config=genai.GenerationConfig(
                temperature=0.1,
                max_output_tokens=3000,
            ),
        )

    def _build_context(self, retrieved: list[dict]) -> str:
        if not retrieved:
            return "논문 컨텍스트 없음"
        return "\n\n".join(
            f"[{r['paper']} — {r['title']}]\n{r['content']}"
            for r in retrieved
        )

    def _build_answers_summary(self, answers: list[dict]) -> str:
        q_map = {a["question_id"]: a["answer"] for a in answers}
        lines = []
        sections = [
            ("파트A VARK (Q1-7)", range(1, 8)),
            ("파트B Felder (Q8-13)", range(8, 14)),
            ("파트C 인지부하 (Q14-19)", range(14, 20)),
            ("파트D Kolb (Q20-25)", range(20, 26)),
        ]
        for label, qrange in sections:
            lines.append(label + ":")
            for qid in qrange:
                lines.append(f"  Q{qid}: {q_map.get(qid, '?')}")
        return "\n".join(lines)

    async def analyze(
        self,
        answers: list[dict],
        retrieved: list[dict],
        writing_response: str = "",
        response_times: list[int] = None,
        learning_history: dict = None,
    ) -> dict:
        """논문 근거 + 25문항 + 글쓰기 + 응답시간 → JSON 분석 결과"""
        if response_times is None:
            response_times = []
        if learning_history is None:
            learning_history = {}

        context = self._build_context(retrieved)
        answers_text = self._build_answers_summary(answers)
        reliability = _calc_reliability(answers)
        time_analysis = _analyze_response_times(response_times)
        citations = list({r["paper"] for r in retrieved if r.get("paper")})

        # 학습이력 포맷
        lh_text = (
            f"잘한 과목: {learning_history.get('subject', '미응답')}\n"
            f"잘한 이유: {learning_history.get('reason', '미응답')}\n"
            f"힘든 방식: {learning_history.get('difficulty', '미응답')}"
        )

        # 신뢰도 텍스트
        reliability_pct = int(reliability["overall"] * 100)
        reliability_text = (
            f"S8↔S16(분석·집중): {int(reliability['pair_s8_s16']*100)}% 일치\n"
            f"S9↔S17(직관·진행): {int(reliability['pair_s9_s17']*100)}% 일치\n"
            f"S11↔S18(순차·시각보조): {int(reliability['pair_s11_s18']*100)}% 일치\n"
            f"전체 신뢰도: {reliability_pct}%"
        )

        prompt = f"""당신은 교육심리학 전문가입니다. 아래 다차원 데이터를 통합 분석해 학습 프로파일을 도출하세요.

[논문 근거]
{context}

[글쓰기 패턴 분석]
자유서술: "{writing_response[:500] if writing_response else '(미응답)'}"
→ 어휘 구체성, 메타인지 표현, 시각/청각/행동 단어 비율을 분석하세요.

[응답시간 패턴]
평균 응답시간: {time_analysis['avg_ms']}ms | 성향: {time_analysis['style']}
느린 문항(불확실): {time_analysis['slow_questions'] if time_analysis['slow_questions'] else '없음'}
→ 빠를수록 직관형, 느릴수록 분석형 가중치를 적용하세요.

[25문항 응답]
{answers_text}

[학습이력]
{lh_text}

[신뢰도 검증 결과]
{reliability_text}
→ 불일치 차원은 "상황에 따라 유연하게 변하는 성향"으로 해석하세요.

위 데이터를 종합하여 아래 JSON 형식으로만 응답하세요. JSON 외 텍스트 없이:

{{
  "learning_style": "시각형",
  "cognitive_style": "분석형",
  "focus_pattern": "단기집중형",
  "preferred_format": "요약형",
  "pace": "속도형",
  "interaction": "독립형",
  "scores": {{
    "visual": 75,
    "analytical": 80,
    "focus_depth": 40,
    "detail_pref": 35,
    "speed": 70,
    "collaboration": 25,
    "metacognition": 65,
    "consistency": {reliability_pct}
  }},
  "vark": {{
    "visual": 75,
    "aural": 20,
    "read_write": 55,
    "kinesthetic": 30
  }},
  "felder": {{
    "sensing_intuitive": 60,
    "sequential_global": -40,
    "active_reflective": 30
  }},
  "cognitive_load": {{
    "intrinsic": 60,
    "extraneous": 20,
    "germane": 70
  }},
  "kolb_type": "동화형",
  "confidence_score": 85,
  "writing_insight": "구체적 사례 중심, 시각적 어휘 다수, 메타인지 표현 적음",
  "analysis": "Fleming(1992) VARK 모델 + 응답시간 패턴 분석 결과... (200자 이내, 논문 인용 포함)",
  "strengths": ["강점1", "강점2", "강점3"],
  "weaknesses": ["개선점1", "개선점2"],
  "strategies": [
    "Fleming(1992) 시각형 전략: ...",
    "Sweller(1988) 인지부하 감소: ...",
    "Kolb(1984) 경험학습 사이클: ..."
  ],
  "paper_citations": {json.dumps(citations, ensure_ascii=False)},
  "reliability": {{
    "pair_s8_s16": {reliability['pair_s8_s16']},
    "pair_s9_s17": {reliability['pair_s9_s17']},
    "pair_s11_s18": {reliability['pair_s11_s18']},
    "overall": {reliability['overall']}
  }}
}}

허용값:
- learning_style: 시각형 | 청각형 | 읽기형 | 실습형
- cognitive_style: 분석형 | 직관형
- focus_pattern: 단기집중형 | 장기몰입형
- preferred_format: 요약형 | 상세형 | 예시형
- pace: 속도형 | 숙고형
- interaction: 독립형 | 협력형
- kolb_type: 확산형 | 동화형 | 수렴형 | 적응형
- scores 각 값: 0-100 정수
- felder 값: -100~100 (양수=sensing/sequential/active)
- confidence_score: 0-100"""

        response = await asyncio.to_thread(
            self._model().generate_content, prompt
        )
        try:
            result = _extract_json(response.text)
            # 신뢰도는 Python 계산값으로 덮어씀 (LLM 오류 방지)
            result["reliability"] = reliability
            result.setdefault("consistency", reliability_pct)
            if "scores" in result:
                result["scores"]["consistency"] = reliability_pct
            return result
        except Exception as e:
            logger.error(f"[RAGAnalyzer] JSON 파싱 실패: {e}\n응답: {response.text[:500]}")
            raise
