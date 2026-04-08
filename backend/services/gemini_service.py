"""
Gemini AI 서비스 — 심리 진단, 핵심 포인트 추출, 교안 재가공
"""
import asyncio
import json
import os
import re

import google.generativeai as genai

MODEL = "gemma-3-27b-it"
LEARNING_TYPES = ["시각형", "청각형", "읽기형", "운동형"]

STYLE_GUIDES: dict[str, str] = {
    "시각형": (
        "도식화 구조로 정리하세요. 개념 간 관계를 → 화살표와 계층 구조로 표현하세요. "
        "표, 목록, 강조 키워드를 풍부하게 사용하세요. 시각적 흐름이 명확해야 합니다."
    ),
    "청각형": (
        "자연스러운 스토리텔링 방식의 대화체로 작성하세요. "
        "리듬감 있는 문장 구조를 사용하고 비유와 은유를 풍부하게 활용하세요. "
        "마치 강의를 듣는 것처럼 서술하세요."
    ),
    "읽기형": (
        "체계적이고 논리적인 글쓰기로 작성하세요. "
        "상세한 설명과 정의를 포함하고, 단계별로 꼼꼼하게 설명하세요. "
        "참고 포인트와 심화 개념을 함께 제시하세요."
    ),
    "운동형": (
        "실습 중심의 단계별 가이드로 작성하세요. "
        "직접 따라할 수 있는 예제와 코드를 포함하세요. "
        "체크리스트 형식과 '직접 해보기' 섹션을 포함하세요."
    ),
}

SOCIAL_MODIFIER: dict[str, str] = {
    "내향형": "개인 학습에 최적화된 자기 성찰적 구조로 구성하세요.",
    "외향형": "토론 포인트와 그룹 활동 아이디어를 끝에 추가하세요.",
}

COGNITIVE_MODIFIER: dict[str, str] = {
    "분석형": "논리적 근거와 단계별 검증 포인트를 포함하세요.",
    "직관형": "핵심 패턴과 큰 그림을 먼저 제시하고 창의적 적용 아이디어를 추가하세요.",
}


def _extract_json(text: str) -> dict:
    """응답 텍스트에서 JSON 블록 추출"""
    text = text.strip()
    match = re.search(r"```(?:json)?\s*([\s\S]+?)```", text)
    if match:
        text = match.group(1).strip()
    start = text.find("{")
    end = text.rfind("}") + 1
    if start != -1 and end > start:
        text = text[start:end]
    return json.loads(text)


class GeminiService:
    def __init__(self):
        genai.configure(api_key=os.environ["GEMINI_API_KEY"])

    def _model(self, temperature: float = 0.3, max_tokens: int = 2048) -> genai.GenerativeModel:
        return genai.GenerativeModel(
            model_name=MODEL,
            generation_config=genai.GenerationConfig(
                temperature=temperature,
                max_output_tokens=max_tokens,
            ),
        )

    # ── 심리 진단 ────────────────────────────────────────────────

    async def analyze_psychology(self, answers: list[dict]) -> dict:
        """15문항 답변 → 학습 성향 프로필 JSON 반환 (temperature=0.2)"""
        q_map = {a["question_id"]: a["answer"] for a in answers}

        style_block = "\n".join(
            f"Q{i}: {q_map.get(i, '?')}" for i in range(1, 6)
        )
        social_block = "\n".join(
            f"Q{i}: {q_map.get(i, '?')}" for i in range(6, 11)
        )
        cognitive_block = "\n".join(
            f"Q{i}: {q_map.get(i, '?')}" for i in range(11, 16)
        )

        prompt = f"""당신은 교육 심리학 전문가입니다. 학생의 15문항 학습 성향 검사 결과를 분석해주세요.

[학습 스타일 Q1-5] (A=시각형 B=청각형 C=읽기형 D=운동형)
{style_block}

[사회적 성향 Q6-10] (Q6:A=외향B=내향 / Q7-10:A=내향B=외향)
{social_block}

[사고 유형 Q11-15] (A=분석형 B=직관형)
{cognitive_block}

위 응답을 분석해 다음 JSON 형식으로만 반환하세요. 다른 텍스트 없이 JSON만 출력하세요:
{{
  "primary_style": "시각형",
  "secondary_style": "읽기형",
  "social_type": "내향형",
  "cognitive_type": "분석형",
  "personality_summary": "이 학생은 ...",
  "strengths": ["강점1", "강점2", "강점3"],
  "weaknesses": ["개선점1", "개선점2"],
  "recommendations": ["추천학습법1", "추천학습법2", "추천학습법3"],
  "ai_analysis": "이 학생의 학습 심리 상세 분석..."
}}

primary_style/secondary_style 허용값: 시각형, 청각형, 읽기형, 운동형
social_type 허용값: 내향형, 외향형
cognitive_type 허용값: 분석형, 직관형"""

        response = await asyncio.to_thread(
            self._model(temperature=0.2, max_tokens=1024).generate_content, prompt
        )
        return _extract_json(response.text)

    # ── 핵심 포인트 추출 ─────────────────────────────────────────

    async def extract_core_points(self, content: str) -> list[dict]:
        """교안 텍스트 → 핵심 포인트 3~5개 JSON 반환"""
        prompt = f"""당신은 교육 전문가입니다. 다음 교안에서 가장 중요한 핵심 포인트 3~5개를 추출하세요.

교안 내용:
{content[:4000]}

다음 JSON 형식으로만 반환하세요:
{{
  "core_points": [
    {{"id": 1, "content": "핵심 포인트 설명 (1-2문장)", "priority": 1}},
    {{"id": 2, "content": "핵심 포인트 설명", "priority": 2}}
  ]
}}

priority는 1(가장 중요)에서 5(덜 중요) 순입니다. JSON만 출력하세요."""

        response = await asyncio.to_thread(
            self._model(temperature=0.2, max_tokens=512).generate_content, prompt
        )
        data = _extract_json(response.text)
        return data.get("core_points", [])

    # ── 교안 재가공 ──────────────────────────────────────────────

    async def reforge_content(
        self,
        original_content: str,
        core_points: list[dict],
        primary_style: str,
        secondary_style: str,
        social_type: str,
        cognitive_type: str,
    ) -> str:
        """학습 성향 맞춤 교안 재가공 (temperature=0.7)"""
        core_text = "\n".join(
            f"{p['priority']}. {p['content']}" for p in sorted(core_points, key=lambda x: x["priority"])
        )
        style_guide = STYLE_GUIDES.get(primary_style, STYLE_GUIDES["읽기형"])
        social_mod = SOCIAL_MODIFIER.get(social_type, "")
        cognitive_mod = COGNITIVE_MODIFIER.get(cognitive_type, "")

        prompt = f"""당신은 교육 콘텐츠 전문가입니다. 학생의 학습 성향에 맞게 교안을 재가공하세요.

[학생 학습 성향]
- 주요 스타일: {primary_style} / 부 스타일: {secondary_style}
- 사회적 성향: {social_type} / 사고 유형: {cognitive_type}

[교수가 확정한 핵심 포인트]
{core_text}

[원본 교안 요약]
{original_content[:2000]}

[재가공 지침]
{style_guide}
{social_mod}
{cognitive_mod}

마크다운 형식으로 재가공된 교안을 작성하세요. 학생이 즉시 학습에 활용할 수 있도록 완성도 있게 작성하세요."""

        response = await asyncio.to_thread(
            self._model(temperature=0.7, max_tokens=2048).generate_content, prompt
        )
        return response.text

    async def reforge_all_styles(
        self,
        original_content: str,
        core_points: list[dict],
        social_type: str = "내향형",
        cognitive_type: str = "분석형",
    ) -> dict[str, str]:
        """4가지 학습 스타일 병렬 재가공"""
        tasks = [
            self.reforge_content(original_content, core_points, style, "", social_type, cognitive_type)
            for style in LEARNING_TYPES
        ]
        results = await asyncio.gather(*tasks)
        return dict(zip(LEARNING_TYPES, results))

    # ── 대시보드 분석 ────────────────────────────────────────────

    async def analyze_student_patterns(self, students_data: list[dict]) -> str:
        """학생 성향 데이터 → 교수용 인사이트 생성"""
        if not students_data:
            return "아직 진단을 완료한 학생이 없습니다."

        summary = json.dumps(students_data, ensure_ascii=False, indent=2)
        prompt = f"""다음 학생들의 학습 성향 데이터를 분석해 교수에게 유용한 인사이트를 제공하세요.

학생 데이터:
{summary[:3000]}

다음 내용을 포함해 200자 이내로 요약하세요:
- 가장 많은 학습 스타일
- 수업 방식 추천
- 주의할 점"""

        response = await asyncio.to_thread(
            self._model(temperature=0.3, max_tokens=400).generate_content, prompt
        )
        return response.text
