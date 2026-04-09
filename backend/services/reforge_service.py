"""
교안 재가공 오케스트레이터
논문 기반 학습법 + asyncio.gather() 6스타일 병렬 생성
"""
import asyncio
import logging
import os

import google.generativeai as genai

from .rag_pipeline.knowledge_base import PAPER_CHUNKS
from .gemini_service import STYLE_GUIDES

logger = logging.getLogger(__name__)

MODEL = "gemma-3-27b-it"

# 재가공 스타일별 논문 기반 지침 보강
PAPER_STRATEGY = {
    "시각형": "Fleming(1992) VARK: 시각적 표현 중심. 도식, 흐름도, 색상 구분 적극 활용.",
    "청각형": "Fleming(1992) VARK: 청각형 학습자. 대화체 스토리텔링, 리듬감 있는 설명.",
    "읽기형": "Fleming(1992) VARK: 읽기/쓰기형. 체계적 텍스트, 정의와 목록 중심.",
    "실습형": "Fleming(1992) VARK: 운동형. 구체적 경험(Kolb 1984 CE), 단계별 실습 가이드.",
    "요약형": "Sweller(1988) CLT: 외재적 부하 최소화. 핵심만 3-5줄 압축.",
    "상세형": "Felder-Silverman(1988): 감각형+순차형 학습자. 단계별 상세 설명, 예외 케이스 포함.",
}


async def _get_paper_context_for_style(style: str) -> str:
    """스타일에 맞는 논문 컨텍스트 추출 (지식베이스에서 직접)"""
    relevant = []
    keywords = {
        "시각형": ["vark_02", "synthesis_01"],
        "청각형": ["vark_03", "synthesis_01"],
        "읽기형": ["vark_04", "synthesis_02"],
        "실습형": ["vark_05", "kolb_03"],
        "요약형": ["clt_03", "clt_04"],
        "상세형": ["fs_02", "fs_03", "clt_02"],
    }.get(style, [])

    for chunk in PAPER_CHUNKS:
        if chunk["id"] in keywords:
            relevant.append(f"[{chunk['paper']}] {chunk['content']}")

    return "\n\n".join(relevant) if relevant else ""


class ReforgeService:
    async def reforge_with_rag(
        self,
        original_content: str,
        core_points: list[dict],
        profile: dict,
    ) -> dict[str, str]:
        """
        6스타일 교안 재가공 — RAG 논문 컨텍스트 + asyncio.gather() 병렬 처리
        """
        styles = ["시각형", "청각형", "읽기형", "실습형", "요약형", "상세형"]

        # 논문 컨텍스트 병렬 조회
        paper_contexts = await asyncio.gather(
            *[_get_paper_context_for_style(s) for s in styles]
        )

        # 6스타일 병렬 재가공
        tasks = [
            self._reforge_one_with_context(
                style=styles[i],
                original_content=original_content,
                core_points=core_points,
                profile=profile,
                paper_context=paper_contexts[i],
            )
            for i in range(len(styles))
        ]
        results = await asyncio.gather(*tasks)
        return dict(zip(styles, results))

    async def _reforge_one_with_context(
        self,
        style: str,
        original_content: str,
        core_points: list[dict],
        profile: dict,
        paper_context: str,
    ) -> str:
        """단일 스타일 재가공 — 논문 근거 포함 프롬프트"""
        import google.generativeai as genai
        import os

        core_text = "\n".join(
            f"{p.get('priority', 1)}점 | {p['content']}"
            for p in sorted(core_points, key=lambda x: x.get("priority", 0), reverse=True)
        )
        paper_strategy = PAPER_STRATEGY.get(style, "")
        style_guide = STYLE_GUIDES.get(style, "")

        prompt = f"""당신은 교육 콘텐츠 전문가입니다. 교육심리학 이론에 기반하여 '{style}' 학습자를 위한 맞춤 교안을 재가공하세요.

[논문 근거]
{paper_context}

[교육심리학 전략 — {style}]
{paper_strategy}

[학생 학습 프로파일]
- 학습유형: {profile.get('learning_style')} / 인지스타일: {profile.get('cognitive_style')}
- 집중패턴: {profile.get('focus_pattern')} / 페이스: {profile.get('pace')}
- 선호형식: {profile.get('preferred_format')} / Kolb유형: {profile.get('kolb_type', '동화형')}
- 신뢰도: {profile.get('confidence_score', 70)}%

[교수 확정 핵심 포인트 (중요도 순)]
{core_text}

[원본 교안]
{original_content[:2500]}

[재가공 규칙]
1. 위 논문 이론을 실제로 적용해 재가공하세요
2. '{style}' 학습자에게 최적화된 형식과 구조를 사용하세요
3. 마크다운 형식으로 완성된 교안을 작성하세요
4. 학생이 즉시 학습에 활용할 수 있도록 완성도 있게 작성하세요"""

        genai.configure(api_key=os.environ["GEMINI_API_KEY"])
        model = genai.GenerativeModel(
            model_name=MODEL,
            generation_config=genai.GenerationConfig(
                temperature=0.7,
                max_output_tokens=2048,
            ),
        )
        response = await asyncio.to_thread(model.generate_content, prompt)
        return response.text
