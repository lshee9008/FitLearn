"""
RAG 기반 Gemini 분석 — 논문 근거 + 학생 응답 → 6차원 학습 프로파일
temperature=0.1 (최대 정확도)
"""
import asyncio
import json
import logging
import os
import re

import google.generativeai as genai

logger = logging.getLogger(__name__)
MODEL = "gemini-2.0-flash"


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


class RAGAnalyzer:
    def __init__(self):
        genai.configure(api_key=os.environ["GEMINI_API_KEY"])

    def _model(self) -> genai.GenerativeModel:
        return genai.GenerativeModel(
            model_name=MODEL,
            generation_config=genai.GenerationConfig(
                temperature=0.1,  # 정확도 최대화
                max_output_tokens=2048,
            ),
        )

    def _build_context(self, retrieved: list[dict]) -> str:
        if not retrieved:
            return "논문 컨텍스트 없음"
        lines = []
        for r in retrieved:
            lines.append(
                f"[{r['paper']} — {r['title']}]\n{r['content']}"
            )
        return "\n\n".join(lines)

    def _build_answers_summary(self, answers: list[dict]) -> str:
        q_map = {a["question_id"]: a["answer"] for a in answers}
        parts = []
        for qid in range(1, 16):
            parts.append(f"Q{qid}: {q_map.get(qid, '?')}")
        return "\n".join(parts)

    async def analyze(self, answers: list[dict], retrieved: list[dict]) -> dict:
        """논문 근거 + 학생 응답 → JSON 분석 결과"""
        context = self._build_context(retrieved)
        answers_text = self._build_answers_summary(answers)

        citations = list({r["paper"] for r in retrieved if r.get("paper")})

        prompt = f"""당신은 교육심리학 전문가입니다. 아래 논문 근거와 학생 응답을 바탕으로 학습 프로파일을 분석하세요.

[논문 근거]
{context}

[학생 응답 — 15문항]
파트A (Q1-5): 학습 스타일 (A=시각형 B=청각형 C=읽기형 D=실습형)
파트B (Q6-10): 인지 유형 (A=분석형 B=직관형 C=중간)
파트C (Q11-15): 학습 환경
{answers_text}

위 논문 근거를 인용하며 다음 JSON 형식으로만 응답하세요. JSON 외 다른 텍스트 없이:

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
    "collaboration": 25
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
  "analysis": "Fleming(1992)의 VARK 모델에 따르면 이 학생은... (논문 인용 포함, 150자 이내)",
  "strengths": ["강점1", "강점2", "강점3"],
  "weaknesses": ["개선점1", "개선점2"],
  "strategies": [
    "Fleming(1992)의 시각형 학습자 전략에 따르면...",
    "Sweller(1988)의 인지부하 이론을 적용하면...",
    "Kolb(1984)의 경험학습 사이클에 기반하면..."
  ],
  "paper_citations": {json.dumps(citations, ensure_ascii=False)}
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
- felder 값: -100~100 (양수=sensing/sequential/active, 음수=intuitive/global/reflective)
- confidence_score: 0-100"""

        response = await asyncio.to_thread(
            self._model().generate_content, prompt
        )
        try:
            return _extract_json(response.text)
        except Exception as e:
            logger.error(f"[RAGAnalyzer] JSON 파싱 실패: {e}\n응답: {response.text[:500]}")
            raise
