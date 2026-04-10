"""
교안 재가공 오케스트레이터
5차원 성향(VARK × 집중패턴 × 난이도대응 × 이탈위험 × 신뢰도) 완전 반영
asyncio.gather() 6스타일 병렬 생성
"""
import asyncio
import logging
import os
import re

import google.generativeai as genai

from .rag_pipeline.knowledge_base import PAPER_CHUNKS
from .gemini_service import STYLE_GUIDES

logger = logging.getLogger(__name__)

MODEL = "models/gemma-4-31b-it"


# ── 마크다운 후처리 ───────────────────────────────────────────────────────────
def _clean_markdown(text: str) -> str:
    """
    AI 출력의 마크다운 오염 요소 정리:
    - LaTeX 수식 ($...$) → 일반 텍스트 변환
    - ■, □, ▶ 등 특수 문자 → 마크다운 대체
    - 연속 빈줄 3개 이상 → 2개로 압축
    """
    # LaTeX 블록 수식 ($$...$$) → 코드블록으로
    text = re.sub(r'\$\$(.*?)\$\$', lambda m: f'```\n{m.group(1).strip()}\n```', text, flags=re.DOTALL)
    # LaTeX 인라인 수식 ($...$) → 백틱 인라인 코드
    text = re.sub(r'\$([^$\n]+?)\$', lambda m: f'`{m.group(1).strip()}`', text)
    # LaTeX 명령어 잔재 (\blacksquare, \rightarrow 등)
    latex_map = {
        r'\blacksquare': '■',
        r'\square': '□',
        r'\rightarrow': '→',
        r'\leftarrow': '←',
        r'\Rightarrow': '⇒',
        r'\Leftrightarrow': '⟺',
        r'\times': '×',
        r'\cdot': '·',
        r'\leq': '≤',
        r'\geq': '≥',
        r'\neq': '≠',
        r'\approx': '≈',
        r'\alpha': 'α',
        r'\beta': 'β',
        r'\gamma': 'γ',
        r'\delta': 'δ',
        r'\theta': 'θ',
        r'\lambda': 'λ',
        r'\mu': 'μ',
        r'\sigma': 'σ',
        r'\pi': 'π',
    }
    for latex, replacement in latex_map.items():
        text = text.replace(latex, replacement)
    # ■·□·▶ 등 특수 블릿 → 마크다운 리스트
    text = re.sub(r'^[■□▶▷◆◇●○•]\s+', '- ', text, flags=re.MULTILINE)
    # 연속 빈줄 압축
    text = re.sub(r'\n{3,}', '\n\n', text)
    # 잘못된 굵은글씨 (** 안에 공백만 있을 때)
    text = re.sub(r'\*\*\s+\*\*', '', text)
    return text.strip()


def _fallback_content(style: str, core_text: str) -> str:
    """AI 호출 실패 시 템플릿 기반 폴백 콘텐츠"""
    hints = {
        "시각형": "표와 흐름도로 개념 관계를 시각화하며 학습하세요.\n\n```\n핵심개념 A → 핵심개념 B → 결론\n```",
        "청각형": "내용을 소리 내어 읽거나, 스터디 그룹에서 토론하며 습득하세요.\n\n> 자, 이렇게 생각해보세요. 이 개념은 우리 일상에서 이렇게 나타납니다...",
        "읽기형": "체계적으로 노트를 정리하고 핵심 개념을 목록화하여 학습하세요.\n\n**용어 정의** → **원리 이해** → **적용 사례** 순서로 정리하세요.",
        "실습형": "직접 예제를 따라 해보며 단계별로 적용해보세요.\n\n**직접 해보기:** 아래 단계를 순서대로 실습하세요.",
        "요약형": "핵심 키워드 3가지로 압축하세요. 불필요한 세부사항은 제거합니다.",
        "상세형": "각 개념의 배경·원리·예외까지 빠짐없이 이해한 후 넘어가세요.",
    }
    hint = hints.get(style, "핵심 내용을 반복 학습하세요.")
    points = "\n".join(
        f"- {line.split('|')[-1].strip()}"
        for line in core_text.split("\n")
        if line.strip()
    )
    return f"""# {style} 맞춤 교안

> ⚠️ AI 서버 응답 지연으로 기본 형식으로 제공됩니다. 재시도하면 AI 맞춤 교안을 받을 수 있습니다.

## 핵심 포인트

{points}

## {style} 학습 전략

{hint}

---

*더 풍부한 맞춤 교안을 원하시면 잠시 후 재시도하세요.*
"""


# ── 5차원 성향 → 프롬프트 지침 변환 ──────────────────────────────────────────
def _build_profile_instruction(style: str, profile: dict) -> str:
    """
    VARK + 집중패턴 + 난이도대응 + 이탈위험 + 신뢰도 5차원을
    구체적인 재가공 지침 문장으로 변환
    """
    vark = profile.get("learning_style") or profile.get("vark_type") or style
    focus = profile.get("focus_pattern", "")
    difficulty_response = profile.get("difficulty_response") or profile.get("pace", "")
    dropout_risk = profile.get("dropout_risk") or profile.get("isolation_risk", "")
    confidence = profile.get("confidence_score", 0)

    instructions = []

    # VARK 지침
    vark_map = {
        "시각형": "모든 개념을 표·흐름도·ASCII 다이어그램으로 시각화하세요. 텍스트보다 구조가 먼저 오도록 배치하세요.",
        "청각형": "대화체 어조로 작성하세요. '이렇게 생각해보세요', '예를 들면 이런 상황입니다' 등 스토리텔링 형식을 활용하세요.",
        "읽기형": "정의 → 원리 → 예시 → 정리 순서로 체계적 텍스트를 작성하세요. 용어 목록과 개조식 정리가 효과적입니다.",
        "행동형": "실제 실습 단계를 코드·예제와 함께 제공하세요. '직접 해보기' 섹션을 중심으로 구성하세요.",
        "실습형": "실제 실습 단계를 코드·예제와 함께 제공하세요. '직접 해보기' 섹션을 중심으로 구성하세요.",
    }
    instructions.append(f"[VARK 채널 — {vark}] {vark_map.get(vark, '학습자 채널에 맞게 작성하세요.')}")

    # 집중 패턴 지침
    focus_map = {
        "단기집중형": "각 섹션을 짧게 (300자 이하) 나누고, 섹션 사이에 '✅ 체크포인트' 박스를 삽입하세요. 한 번에 한 개념씩만 다루세요.",
        "장기몰입형": "섹션을 길게 구성하고 개념 간 심층 연결을 설명하세요. 배경 이론과 심화 내용을 풍부하게 포함하세요.",
        "분산형": "각 섹션에 짧은 요약 박스를 포함하고, 다른 파트로 넘어갈 때 이전 내용을 한 줄로 복습하세요.",
    }
    if focus in focus_map:
        instructions.append(f"[집중 패턴 — {focus}] {focus_map[focus]}")

    # 난이도 대응 지침
    diff_map = {
        "직진형": "개념이 어려워도 바로 본론으로 진입하세요. 사전 설명 없이 핵심 내용부터 제시해도 됩니다.",
        "우회형": "어려운 개념 전에 반드시 쉬운 유사 사례나 비유를 먼저 제시한 후 본 개념으로 유도하세요.",
        "지원요청형": "각 단계마다 '이 부분이 어렵다면 → 이렇게 생각해보세요' 힌트를 추가하세요. 실수 가능 포인트를 미리 짚어주세요.",
        "숙고형": "개념 제시 후 '잠깐 생각해보기' 질문을 삽입하여 스스로 이해를 확인하도록 유도하세요.",
        "속도형": "불필요한 전제 설명 없이 핵심만 빠르게 전달하세요.",
    }
    if difficulty_response in diff_map:
        instructions.append(f"[난이도 대응 — {difficulty_response}] {diff_map[difficulty_response]}")

    # 이탈 위험 인자 지침
    dropout_map = {
        "난이도": "개념이 등장할 때마다 '왜 이게 중요한가'를 먼저 설명하여 동기를 유지하세요. 너무 어려운 표현은 쉬운 말로 바꾸세요.",
        "동기": "실생활 적용 사례나 흥미로운 예시를 자주 삽입하여 흥미를 유지하세요.",
        "고립": "혼자 공부하는 상황을 고려해 '확인 질문'을 자주 달아 자기 점검을 돕고, 응원 메시지를 포함하세요.",
        "루틴": "학습 순서를 명확히 번호로 제시하고, 오늘 학습 목표를 첫 부분에 배치하세요.",
    }
    if dropout_risk in dropout_map:
        instructions.append(f"[이탈 위험 대응 — {dropout_risk}] {dropout_map[dropout_risk]}")

    # 신뢰도 반영
    if isinstance(confidence, (int, float)) and confidence > 0:
        if confidence >= 85:
            instructions.append(f"[신뢰도 {confidence}%] 진단 결과의 신뢰도가 높습니다. 위의 성향 지침을 강하게 적용하세요.")
        elif confidence >= 65:
            instructions.append(f"[신뢰도 {confidence}%] 성향이 복합적입니다. 핵심 성향 위주로 적용하되 유연하게 구성하세요.")
        else:
            instructions.append(f"[신뢰도 {confidence}%] 진단 신뢰도가 낮습니다. 읽기형 기본 체계를 유지하며 다양한 형식을 혼합하세요.")

    # 과목별 학생 수준 반영 (4요소 재해석의 핵심)
    subject_level = profile.get("subject_level", "")
    level_map = {
        "beginner": (
            "[과목 수준 — 입문] 이 학생은 해당 과목의 기초 지식이 부족합니다.\n"
            "- 전문 용어가 처음 나올 때마다 반드시 쉬운 말로 정의하세요.\n"
            "- 일상 생활 유추·비유를 적극 활용하여 개념을 쉽게 풀어쓰세요.\n"
            "- 전제 개념부터 차근차근, 결론으로 가는 귀납적 순서로 서술하세요.\n"
            "- 코드 예제는 각 줄에 주석으로 설명을 달아주세요."
        ),
        "intermediate": (
            "[과목 수준 — 중급] 이 학생은 기초 개념을 알고 있습니다.\n"
            "- 기초 용어 정의는 생략하고 응용·사례 중심으로 서술하세요.\n"
            "- 개념 간 연결과 '왜 이렇게 되는지' 원리 설명에 집중하세요.\n"
            "- 코드 예제는 실행 결과와 함께 제공하세요."
        ),
        "advanced": (
            "[과목 수준 — 고급] 이 학생은 해당 과목에 대한 깊은 이해를 가지고 있습니다.\n"
            "- 기초 설명은 최소화하고 심화·예외 케이스·엣지 케이스를 포함하세요.\n"
            "- 성능, 한계, 트레이드오프 등 전문가 관점의 내용을 적극 추가하세요.\n"
            "- 코드 예제는 최적화·리팩터링 관점에서도 언급하세요."
        ),
    }
    if subject_level in level_map:
        instructions.append(level_map[subject_level])

    return "\n".join(instructions)


# ── 논문 기반 전략 ────────────────────────────────────────────────────────────
PAPER_STRATEGY = {
    "시각형": "Fleming(1992) VARK: 시각적 표현 중심. 도식, 흐름도, 색상 구분 적극 활용.",
    "청각형": "Fleming(1992) VARK: 청각형 학습자. 대화체 스토리텔링, 리듬감 있는 설명.",
    "읽기형": "Fleming(1992) VARK: 읽기/쓰기형. 체계적 텍스트, 정의와 목록 중심.",
    "실습형": "Fleming(1992) VARK: 운동형. 구체적 경험(Kolb 1984 CE), 단계별 실습 가이드.",
    "요약형": "Sweller(1988) CLT: 외재적 부하 최소화. 핵심만 3-5줄 압축.",
    "상세형": "Felder-Silverman(1988): 감각형+순차형 학습자. 단계별 상세 설명, 예외 케이스 포함.",
}


async def _get_paper_context_for_style(style: str) -> str:
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
        paper_contexts = await asyncio.gather(
            *[_get_paper_context_for_style(s) for s in styles]
        )
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
        """단일 학생 프로파일 맞춤형 교안 재가공"""
        style = profile.get("learning_style", "읽기형")
        if style not in PAPER_STRATEGY:
            style = "읽기형"
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
        """단일 스타일 재가공 — 5차원 성향 완전 반영 프롬프트"""

        core_text = "\n".join(
            f"[중요도 {p.get('priority', 1)}/5] {p['content']}"
            for p in sorted(core_points, key=lambda x: x.get("priority", 0), reverse=True)
        )
        paper_strategy = PAPER_STRATEGY.get(style, "")
        profile_instruction = _build_profile_instruction(style, profile)

        prompt = f"""당신은 최고 수준의 교육공학 전문가입니다.
아래의 원본 교안을 '{style}' 학습자 프로파일에 맞게 완전히 재해석하여, 학생이 바로 읽고 이해할 수 있는 한국어 교안 본문을 작성하세요.

절대 규칙:
- 출력은 순수 마크다운 본문만. 인사말·역할설명·프롬프트 복창 절대 금지.
- 단순 요약 금지. 원본 내용을 '{style}' 방식으로 완전히 재해석하는 것이 목적입니다.
- 코드 예제, 실습 단계, 수식은 반드시 원형 그대로 보존하고 코드블록(```)으로 감싸세요.
- LaTeX 수식($...$)은 반드시 백틱 인라인 코드로 변환하세요. ■·□ 등 특수문자는 마크다운 리스트(-)로 변환하세요.
- 교수가 확정한 핵심 포인트는 모두 빠짐없이 포함해야 합니다.
- 마크다운 형식: # 제목, ## 소제목, **굵게**, `인라인코드`, ```코드블록```, > 인용

[논문 기반 학습 이론 — {style}]
{paper_strategy}
{paper_context}

[5차원 성향 기반 재가공 지침]
{profile_instruction}

[교수 확정 핵심 포인트 (중요도 순, 모두 포함 필수)]
{core_text}

[원본 교안]
{original_content[:4000]}

위 원본 교안과 핵심 포인트를 바탕으로, '{style}' 학습자가 강의 중 바로 활용할 수 있는 맞춤형 교안을 지금 작성하세요.
"""

        genai.configure(api_key=os.environ["GEMINI_API_KEY"], transport="rest")
        model = genai.GenerativeModel(
            model_name=MODEL,
            generation_config=genai.GenerationConfig(
                temperature=0.45,
                max_output_tokens=2500,  # 코드/실습 보존을 위해 충분히 확보
            ),
        )
        try:
            response = await asyncio.wait_for(
                asyncio.to_thread(model.generate_content, prompt),
                timeout=35.0,
            )
            raw = response.text
            return _clean_markdown(raw)
        except asyncio.TimeoutError:
            logger.error(f"[reforge] {style} 타임아웃 (35s 초과)")
            return _fallback_content(style, core_text)
        except Exception as e:
            err = str(e)
            if "429" in err or "quota" in err.lower():
                logger.warning(f"[reforge] {style} 429 할당량 초과 — fallback 사용")
            else:
                logger.error(f"[reforge] {style} 모델 호출 실패: {err}")
            return _fallback_content(style, core_text)
