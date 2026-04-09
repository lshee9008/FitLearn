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

MODEL = "models/gemma-4-31b-it"

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

    async def reforge_for_student(
        self,
        original_content: str,
        core_points: list[dict],
        profile: dict,
    ) -> str:
        """
        단일 학생 프로파일 맞춤형 교안 재가공
        """
        style = profile.get("learning_style", "시각형")
        if style not in PAPER_STRATEGY:
            style = "상세형" # 기본값 폴백

        paper_context = await _get_paper_context_for_style(style)

        return await self._reforge_one_with_context(
            style=style,
            original_content=original_content,
            core_points=core_points,
            profile=profile,
            paper_context=paper_context,
        )

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

        prompt = f"""당신은 최고 수준의 교육공학 전문가입니다. 제공된 교육심리학 이론과 논문 근거를 바탕으로 '{style}' 학습자 맞춤형 교안을 "즉시 학습 가능한 본문 형태"로 재가공하세요.
절대로 당신의 역할, 목표, 프로파일, 프롬프트 내용을 다시 설명하거나 복창(Echo)하지 마세요. 오직 재가공된 '한국어' 본문만 출력해야 합니다.

[필수 논문 근거 (이 이론을 내용 전개 방식에 반드시 반영)]
{paper_context}

[교육심리학 전략 — {style}]
{paper_strategy}

[학생 학습 프로파일]
- 학습유형: {profile.get('learning_style')} / 인지스타일: {profile.get('cognitive_style')}
- 집중패턴: {profile.get('focus_pattern')} / 페이스: {profile.get('pace')}
- 선호형식: {profile.get('preferred_format')} / Kolb유형: {profile.get('kolb_type', '동화형')}

[교수 확정 핵심 포인트 (중요도 순)]
{core_text}

[원본 교안]
{original_content[:3000]}

[재가공 절대 규칙]
1. 단순 요약이 아닙니다. '{style}' 학습자의 주의를 끌고 인지 부하를 최적화할 수 있도록 문체, 구조, 예시를 완전히 한국어로 재구성하세요.
2. 위에서 정의된 [교육심리학 전략]에 명시된 표현 방식(예: 도식 활용, 대화체, 핵심 압축 등)을 극단적으로 강조하여 반영하세요.
3. 교수가 확정한 핵심 포인트는 무조건 빠짐없이 포함되어야 합니다.
4. 마크다운(Markdown) 포맷으로 가독성 있게 작성하되, 인사말 없이 바로 교안 내용부터 출력하세요.
5. 절대로 프롬프트에 주어진 조건들(Role, Goal, Profile, Input Material 등)을 출력 결과에 포함하거나 번역해서 나열하지 마세요. 곧바로 '학생이 읽게 될 실제 본문'만 출력하세요.
6. 원본 교안 텍스트가 비어 있거나 파일명만 있더라도, [교수 확정 핵심 포인트]를 기반으로 살을 붙여서 완벽한 교안을 생성하세요.
"""

        genai.configure(api_key=os.environ["GEMINI_API_KEY"], transport="rest")
        model = genai.GenerativeModel(
            model_name=MODEL,
            generation_config=genai.GenerationConfig(
                temperature=0.4,
                max_output_tokens=1200,  # 토큰 줄여 응답 속도 개선
            ),
        )
        try:
            response = await asyncio.wait_for(
                asyncio.to_thread(model.generate_content, prompt),
                timeout=25.0,  # Render 30초 제한 대비 여유
            )
            return response.text
        except asyncio.TimeoutError:
            logger.error(f"[reforge] {style} 타임아웃 (25s 초과)")
            return _fallback_content(style, core_text)
        except Exception as e:
            err = str(e)
            if "429" in err or "quota" in err.lower():
                logger.warning(f"[reforge] {style} 429 할당량 초과 — fallback 사용")
            else:
                logger.error(f"[reforge] {style} 모델 호출 실패: {err}")
            return _fallback_content(style, core_text)
