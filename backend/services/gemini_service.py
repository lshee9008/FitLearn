"""
Gemini AI 서비스 — 6차원 심리 진단, 핵심 포인트 추출, 6스타일 교안 재가공
"""
import asyncio
import json
import os
import re

import google.generativeai as genai

MODEL = "gemma-4-31b-it"

# 6가지 재가공 스타일
REFORGE_STYLES = ["시각형", "청각형", "읽기형", "실습형", "요약형", "상세형"]

STYLE_GUIDES: dict[str, str] = {
    "시각형": (
        "도식화와 계층 구조 중심으로 작성하세요. "
        "개념 간 관계를 → 화살표, 표, 마인드맵 형식으로 표현하세요. "
        "굵은 키워드와 색상 구분(마크다운 강조)을 풍부하게 사용하고 "
        "시각적 흐름이 한눈에 파악되어야 합니다."
    ),
    "청각형": (
        "자연스러운 대화체 스토리텔링으로 작성하세요. "
        "마치 친절한 교수가 직접 설명하듯 '~해볼까요?', '~생각해보세요' 등의 표현을 사용하고 "
        "리듬감 있는 문장과 비유/은유를 풍부하게 활용하세요. "
        "소리 내어 읽으면 이해가 쉬운 구조로 구성하세요."
    ),
    "읽기형": (
        "체계적이고 논리적인 학술 문서 스타일로 작성하세요. "
        "정확한 정의, 단계별 상세 설명, 참고 포인트를 포함하고 "
        "소제목과 번호 목록으로 구조화하세요. "
        "심화 개념과 배경 지식도 함께 제공하세요."
    ),
    "실습형": (
        "직접 따라할 수 있는 단계별 실습 가이드로 작성하세요. "
        "코드/수식/예제를 풍부하게 포함하고 '직접 해보기' 섹션을 반드시 추가하세요. "
        "체크리스트 형식과 실습 후 확인 질문을 포함하세요."
    ),
    "요약형": (
        "핵심만 간결하게 3-5줄로 압축하세요. "
        "불필요한 설명을 모두 제거하고 '핵심 3가지', '1줄 요약' 형식을 사용하세요. "
        "한 눈에 전체 내용이 파악되어야 합니다."
    ),
    "상세형": (
        "모든 개념을 빠짐없이 단계별로 상세히 설명하세요. "
        "각 개념의 배경, 원리, 적용 방법, 주의사항까지 포함하고 "
        "예외 케이스와 심화 내용도 다루세요. "
        "완전한 이해를 위한 충분한 양을 작성하세요."
    ),
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
        genai.configure(api_key=os.environ["GEMINI_API_KEY"], transport="rest")

    def _model(self, temperature: float = 0.3, max_tokens: int = 2048) -> genai.GenerativeModel:
        return genai.GenerativeModel(
            model_name=MODEL,
            generation_config=genai.GenerationConfig(
                temperature=temperature,
                max_output_tokens=max_tokens,
            ),
        )

    # ── 6차원 심리 진단 ──────────────────────────────────────────

    async def analyze_psychology(self, answers: list[dict]) -> dict:
        """15문항 답변 → 6차원 학습 성향 프로필 JSON 반환 (temperature=0.2)"""
        q_map = {a["question_id"]: a["answer"] for a in answers}

        answers_text = "\n".join(
            f"Q{i}: {q_map.get(i, '?')}" for i in range(1, 16)
        )

        prompt = f"""당신은 교육 심리학 박사입니다. 학생의 15문항 학습 성향 검사 결과를 6차원으로 분석하세요.

[문항 구성]
- 파트A (Q1-5): 학습 스타일 (A=시각형 B=청각형 C=읽기형 D=실습형)
- 파트B (Q6-10): 인지 유형 (A=분석형 B=직관형 C=중간)
- 파트C (Q11-15): 학습 환경 (집중패턴, 선호형식, 페이스, 상호작용)
  - Q11: A=조용한환경/독립형 B=배경음/장기몰입 C=공공장소/협력형 D=상관없음
  - Q12: A=단기집중형 B=장기몰입형 C=불규칙
  - Q13: A=속도형/요약형 B=숙고형/상세형 C=예시형
  - Q14: A=속도형 B=숙고형 C=협력형
  - Q15: A=독립형 B=협력형 C=상황따라

[학생 답변]
{answers_text}

위 답변을 분석해 정확히 다음 JSON 형식으로만 반환하세요. JSON 외 다른 텍스트 없이:

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
  "analysis": "이 학생은 시각적 정보처리를 선호하며...(150자 이내 분석)",
  "strengths": ["강점1", "강점2", "강점3"],
  "weaknesses": ["개선점1", "개선점2"],
  "strategies": ["맞춤 학습 전략1", "맞춤 학습 전략2", "맞춤 학습 전략3"]
}}

허용값:
- learning_style: 시각형 | 청각형 | 읽기형 | 실습형
- cognitive_style: 분석형 | 직관형
- focus_pattern: 단기집중형 | 장기몰입형
- preferred_format: 요약형 | 상세형 | 예시형
- pace: 속도형 | 숙고형
- interaction: 독립형 | 협력형
- scores 각 값: 0-100 정수"""

        response = await asyncio.to_thread(
            self._model(temperature=0.2, max_tokens=1024).generate_content, prompt
        )
        return _extract_json(response.text)

    # ── 핵심 포인트 추출 ─────────────────────────────────────────

    async def extract_core_points(self, content: str) -> list[dict]:
        """교안 텍스트 → 핵심 포인트 5개 추출 + 중요도 점수"""
        prompt = f"""당신은 교육 전문가입니다. 다음 교안에서 가장 중요한 핵심 포인트 5개를 추출하세요.

교안 내용:
{content[:4000]}

다음 JSON 형식으로만 반환하세요:
{{
  "core_points": [
    {{"id": 1, "content": "핵심 포인트 설명 (1-2문장)", "priority": 5}},
    {{"id": 2, "content": "핵심 포인트 설명", "priority": 4}},
    {{"id": 3, "content": "핵심 포인트 설명", "priority": 3}},
    {{"id": 4, "content": "핵심 포인트 설명", "priority": 2}},
    {{"id": 5, "content": "핵심 포인트 설명", "priority": 1}}
  ]
}}

priority는 중요도 점수입니다 (5=매우중요, 1=보통). JSON만 출력하세요."""

        response = await asyncio.to_thread(
            self._model(temperature=0.2, max_tokens=1024).generate_content, prompt
        )
        data = _extract_json(response.text)
        return data.get("core_points", [])

    # ── 단일 스타일 교안 재가공 ──────────────────────────────────

    async def _reforge_one(
        self,
        style: str,
        original_content: str,
        core_points: list[dict],
        profile: dict,
    ) -> str:
        core_text = "\n".join(
            f"{p['priority']}점 | {p['content']}"
            for p in sorted(core_points, key=lambda x: x.get("priority", 0), reverse=True)
        )
        guide = STYLE_GUIDES.get(style, STYLE_GUIDES["읽기형"])

        prompt = f"""당신은 교육 콘텐츠 전문가입니다. '{style}' 학습자를 위한 맞춤 교안을 재가공하세요.

[학생 학습 프로필]
- 학습유형: {profile.get('learning_style')} / 인지스타일: {profile.get('cognitive_style')}
- 집중패턴: {profile.get('focus_pattern')} / 페이스: {profile.get('pace')}
- 선호형식: {profile.get('preferred_format')} / 상호작용: {profile.get('interaction')}

[교수 확정 핵심 포인트 (중요도 순)]
{core_text}

[원본 교안]
{original_content[:2500]}

[재가공 지침 — {style}]
{guide}

위 지침을 엄격히 따라 마크다운 형식으로 완성된 교안을 작성하세요."""

        response = await asyncio.to_thread(
            self._model(temperature=0.7, max_tokens=2048).generate_content, prompt
        )
        return response.text

    # ── 6스타일 병렬 재가공 (asyncio.gather) ────────────────────

    async def reforge_all_styles(
        self,
        original_content: str,
        core_points: list[dict],
        profile: dict,
    ) -> dict[str, str]:
        """6가지 학습 스타일 동시 생성 — asyncio.gather()"""
        tasks = [
            self._reforge_one(style, original_content, core_points, profile)
            for style in REFORGE_STYLES
        ]
        results = await asyncio.gather(*tasks)
        return dict(zip(REFORGE_STYLES, results))

    # ── 대시보드 분석 ────────────────────────────────────────────

    async def analyze_student_patterns(self, students_data: list[dict]) -> str:
        if not students_data:
            return "아직 진단을 완료한 학생이 없습니다."

        summary = json.dumps(students_data, ensure_ascii=False, indent=2)
        prompt = f"""다음 학생들의 6차원 학습 성향 데이터를 분석해 교수에게 유용한 인사이트를 제공하세요.

학생 데이터:
{summary[:3000]}

200자 이내로 다음 내용을 포함해 작성하세요:
- 가장 많은 학습 스타일과 비율
- 수업 방식 추천 (시각 자료 활용 등)
- 주의할 점 (다양성 대응 방법)"""

        response = await asyncio.to_thread(
            self._model(temperature=0.3, max_tokens=400).generate_content, prompt
        )
        return response.text
