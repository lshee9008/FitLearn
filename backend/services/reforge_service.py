"""
교안 재가공 오케스트레이터
5차원 성향(VARK × 집중패턴 × 난이도대응 × 이탈위험 × 신뢰도) 완전 반영
asyncio.gather() 6스타일 병렬 생성
"""
import asyncio
import logging
import os
import re
import time

import httpx

from .rag_pipeline.knowledge_base import PAPER_CHUNKS
from .gemini_service import STYLE_GUIDES

logger = logging.getLogger(__name__)
DEFAULT_MODEL = "gemini-2.0-flash"
MODEL = os.getenv("GEMINI_MODEL", DEFAULT_MODEL)
MODEL_FALLBACKS = [
    model.strip()
    for model in os.getenv(
        "GEMINI_MODEL_FALLBACKS",
        "gemini-2.0-flash,gemini-2.0-flash-lite,gemini-1.5-flash",
    ).split(",")
    if model.strip()
]
_working_model = MODEL
_quota_cooldown_until = 0.0


def _is_quota_error(error: Exception) -> bool:
    message = str(error).lower()
    return "429" in message or "quota" in message or "rate-limit" in message


def _activate_quota_cooldown(seconds: int = 75) -> None:
    global _quota_cooldown_until
    _quota_cooldown_until = max(_quota_cooldown_until, time.monotonic() + seconds)


async def _call_gemini_rest(
    contents,
    *,
    model: str,
    temperature: float,
    max_output_tokens: int,
    timeout: float,
) -> str:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY가 설정되지 않았습니다.")

    url = (
        f"https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model}:generateContent?key={api_key}"
    )

    # contents가 문자열이면 단순 텍스트 메시지로 변환
    if isinstance(contents, str):
        parts = [{"text": contents}]
    elif isinstance(contents, list):
        # 파일 객체 + 텍스트 혼합 리스트 처리
        parts = []
        for item in contents:
            if isinstance(item, str):
                parts.append({"text": item})
            elif hasattr(item, "uri") and hasattr(item, "mime_type"):
                parts.append({"file_data": {"mime_type": item.mime_type, "file_uri": item.uri}})
            else:
                parts.append({"text": str(item)})
    else:
        parts = [{"text": str(contents)}]

    body = {
        "contents": [{"role": "user", "parts": parts}],
        "generationConfig": {
            "temperature": temperature,
            "maxOutputTokens": max_output_tokens,
            # thinkingConfig는 thinking-exp 모델에서만 지원되므로 일반 flash 모델에서는 삭제하거나 0으로 설정
            # "thinkingConfig": {"thinkingBudget": 0}, 
        },
    }

    async with httpx.AsyncClient(timeout=timeout) as client:
        response = await client.post(url, json=body)
        data = response.json()

    if not response.is_success:
        raise Exception(f"Gemini API 오류 ({response.status_code}): {data}")

    try:
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError) as e:
        raise RuntimeError(f"Gemini 응답 파싱 실패: {data}") from e


async def generate_gemini_text(
    contents,
    *,
    temperature: float = 0.7,
    max_output_tokens: int = 2048,
    timeout: float = 60.0,
    feature: str = "gemini",
) -> str:
    global _working_model

    if time.monotonic() < _quota_cooldown_until:
        raise RuntimeError("Gemini quota cooldown active")

    candidates = []
    for model_name in [_working_model, MODEL, *MODEL_FALLBACKS]:
        if model_name and model_name not in candidates:
            candidates.append(model_name)

    loop = asyncio.get_running_loop()
    deadline = loop.time() + timeout
    last_error: Exception | None = None
    for model_name in candidates:
        remaining = deadline - loop.time()
        if remaining <= 0:
            raise asyncio.TimeoutError(f"{feature} 전체 생성 시간 초과 ({timeout}s)")
        try:
            text = await asyncio.wait_for(
                _call_gemini_rest(
                    contents,
                    model=model_name,
                    temperature=temperature,
                    max_output_tokens=max_output_tokens,
                    timeout=remaining,
                ),
                timeout=remaining,
            )
            if not text:
                raise RuntimeError("Gemini 응답이 비어 있습니다.")
            _working_model = model_name
            return text
        except asyncio.TimeoutError:
            logger.warning(f"[{feature}] model={model_name} 시간 초과 ({timeout}s)")
            raise
        except Exception as e:
            if _is_quota_error(e):
                _activate_quota_cooldown()
                logger.warning(f"[{feature}] Gemini quota 감지 — fallback 중단: {e}")
                raise RuntimeError("Gemini quota exceeded") from e
            last_error = e
            logger.warning(f"[{feature}] model={model_name} 실패 — 다음 모델 시도: {e}")

    raise RuntimeError(f"Gemini 생성 실패: {last_error}")


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


def _fallback_content(
    style: str,
    core_text: str,
    original_content: str = "",
    profile_summary: str = "",
) -> str:
    """AI 호출 실패 시에도 원본 근거를 살린 노션형 재해석 콘텐츠."""
    style_hints = {
        "시각형": "개념 관계를 먼저 보고, 아래 핵심 흐름을 그림처럼 연결해 읽으세요.",
        "청각형": "각 문장을 소리 내어 설명하듯 읽고, 핵심 용어를 자기 말로 다시 말해보세요.",
        "읽기형": "정의 → 원리 → 예시 순서로 읽고, 굵게 표시된 키워드를 노트에 옮기세요.",
        "실습형": "실습/코드 블록을 먼저 따라 한 뒤, 바로 위아래 설명으로 의미를 확인하세요.",
        "요약형": "먼저 핵심 포인트만 훑고, 막히는 항목만 원본 근거에서 확장하세요.",
        "상세형": "각 핵심 포인트 아래의 원본 근거를 함께 읽으며 개념 간 연결을 확인하세요.",
    }
    points = [
        line.split("]", 1)[-1].strip()
        for line in core_text.split("\n")
        if line.strip()
    ]

    lines = [
        re.sub(r"\s+", " ", line.strip(" -•\t"))
        for line in original_content.splitlines()
        if len(line.strip()) >= 8
    ]
    evidence: list[str] = []
    code_or_visual: list[str] = []
    for line in lines:
        target = code_or_visual if re.search(
            r"(\[.*(시각자료|코드 캡처|슬라이드|페이지).*\]|```|import |def |class |for |while |npm |pip |python |loss|optimizer|Generator|Discriminator)",
            line,
            re.IGNORECASE,
        ) else evidence
        if line not in target:
            target.append(line[:220])
        if len(evidence) >= 10 and len(code_or_visual) >= 6:
            break

    if not points:
        points = evidence[:5] or ["원본 교안의 핵심 개념을 교수 검토 기준으로 확인해야 합니다."]

    point_md = "\n".join(f"- **{point}**" for point in points[:7])
    evidence_md = "\n".join(f"- {line}" for line in evidence[:10])
    visual_md = "\n".join(f"- {line}" for line in code_or_visual[:8])

    return f"""# {style} 맞춤 교안

> 학습 프로파일: {profile_summary or style}
> AI 응답 제한으로 원본 교안과 교수 핵심 포인트를 기반으로 즉시 구성한 근거형 재해석입니다.

---

## 핵심 포인트

{point_md}

---

## 원본 근거로 다시 이해하기

{evidence_md or "- 원본에서 추출된 텍스트가 부족합니다. 원본 파일을 함께 열어 교수 핵심 포인트를 기준으로 보완하세요."}

---

## 실습/코드 따라하기

{visual_md or "- 원본에서 명확한 코드·실습 블록을 찾지 못했습니다. 강의 중 교수님이 실행하는 코드가 있으면 이 섹션에 맞춰 추가 확인하세요."}

---

## {style} 학습 전략

- {style_hints.get(style, "핵심 개념을 원본 근거와 함께 반복 확인하세요.")}
- 수업 중 따라 해야 하는 코드, 명령어, 화면 캡처는 요약하지 말고 원본 자료와 나란히 확인하세요.
- 이해가 안 되는 구간은 오른쪽 AI 질문에서 분 단위로 질문하면 교안 근거 기준으로 다시 설명합니다.
"""


def _needs_grounded_boost(content: str, original_content: str) -> bool:
    if len(content.strip()) < 1800 and len(original_content.strip()) > 2500:
        return True
    if content.count("## ") < 4 and len(original_content.strip()) > 2500:
        return True
    return bool(re.search(r"(\*$|-\s*$|##\s*$|문장이|다음과|아래와)$", content.strip()))


def _append_grounded_boost(content: str, style: str, original_content: str, core_text: str) -> str:
    boost = _fallback_content(style, core_text, original_content)
    boost = re.sub(r"^# .+?\n+", "", boost, count=1)
    return _clean_markdown(f"""{content.strip()}

---

## 원본 근거 보강

{boost}
""")


def _build_source_excerpt(original_content: str, max_chars: int = 16000) -> str:
    """Long lecture source sampler that keeps beginning/middle/end plus code and visual blocks."""
    content = (original_content or "").strip()
    if len(content) <= max_chars:
        return content

    code_visual_lines = [
        line
        for line in content.splitlines()
        if re.search(
            r"(\[.*(시각자료|코드 캡처|슬라이드|페이지|다이어그램).*\]|```|import |from |def |class |for |while |return |npm |pip |python |loss|optimizer|Generator|Discriminator|torch|tensorflow|keras)",
            line,
            re.IGNORECASE,
        )
    ]
    code_visual = "\n".join(code_visual_lines[:80])
    budget_for_chunks = max_chars - min(len(code_visual), max_chars // 3) - 300
    budget_for_chunks = max(budget_for_chunks, max_chars // 2)
    each = budget_for_chunks // 3
    middle_start = max((len(content) // 2) - (each // 2), 0)
    parts = [
        "[원본 앞부분]",
        content[:each],
        "\n[원본 중간부분]",
        content[middle_start:middle_start + each],
        "\n[원본 뒷부분]",
        content[-each:],
    ]
    if code_visual:
        parts.extend(["\n[코드/시각자료/실습 우선 발췌]", code_visual[: max_chars // 3]])
    return "\n".join(parts)[:max_chars]


# ── 5차원 성향 → 프롬프트 지침 변환 ──────────────────────────────────────────
def _build_profile_instruction(style: str, profile: dict) -> str:
    """
    VARK + 집중패턴 + 난이도대응 + 이탈위험 + 신뢰도 5차원을
    구체적인 재가공 지침 문장으로 변환
    """
    vark = _normalize_learning_style(profile.get("learning_style") or profile.get("vark_type") or style)
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


def _normalize_learning_style(style: str) -> str:
    aliases = {
        "시각": "시각형",
        "visual": "시각형",
        "청각": "청각형",
        "aural": "청각형",
        "듣기": "청각형",
        "읽기": "읽기형",
        "read/write": "읽기형",
        "reading": "읽기형",
        "행동": "실습형",
        "운동": "실습형",
        "kinesthetic": "실습형",
        "실습": "실습형",
    }
    cleaned = (style or "").strip()
    return aliases.get(cleaned.lower(), aliases.get(cleaned, cleaned if cleaned in PAPER_STRATEGY else "읽기형"))


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
        style = _normalize_learning_style(profile.get("learning_style", "읽기형"))
        paper_context = await _get_paper_context_for_style(style)
        return await self._reforge_one_with_context(
            style=style,
            original_content=original_content,
            core_points=core_points,
            profile=profile,
            paper_context=paper_context,
        )

    # ── 스트리밍 재가공 (SSE) ──────────────────────────────────────────────────
    
    async def reforge_stream(
        self,
        learning_type: str = "읽기형",
        content: str = "",
        room_id: str = "",
        lecture_id: str = "",
        user_id: str = "",
        file_content: bytes = None,
        file_name: str = "",
    ):
        """
        교안 재가공 스트리밍 (SSE)
        - user_id가 있으면 Firestore에서 실제 5차원 프로필을 로드
        - 없으면 매개변수로 전달된 learning_type 기반 임시 프로필 생성
        """
        from .firebase_service import FirebaseService
        _fb = FirebaseService()

        # 1. 프로필 로드 또는 생성
        profile = None
        if user_id:
            profile_data = await _fb.get_diagnosis(user_id)
            if profile_data:
                profile = profile_data.get("profile")
        
        if not profile:
            # 임시 프로필 생성 (learning_type 기반)
            types = [t.strip() for t in learning_type.replace("/", "+").split("+") if t.strip()]
            vark, cog, density = "읽기형", "분석형", "상세형"
            for t in types:
                if t in ["시각형", "청각형", "읽기형", "운동형"]: vark = t
                if t in ["분석형", "직관형"]: cog = t
                if t in ["요약형", "상세형", "예시형"]: density = t
            profile = {
                "learning_style": vark,
                "cognitive_style": cog,
                "preferred_format": density,
                "subject_level": "beginner",
                "focus_pattern": "단기집중형",
            }

        # 2. 텍스트 소스 확보
        text = content.strip()
        if room_id and lecture_id:
            lec = await _fb.get_lecture(room_id, lecture_id)
            if lec and lec.get("original_text"):
                text = lec["original_text"]
        elif not text and lecture_id:
            # room_id가 없어도 lecture_id가 있으면 전체 검색 (필요 시)
            pass
        
        if not text and file_content:
            from .file_service import FileService
            _file_svc = FileService()
            text = await _file_svc.extract_text(file_content, file_name)
            
        if not text:
            yield {"error": "재가공할 텍스트를 찾을 수 없습니다."}
            return

        # 3. 태그 전송
        yield {"tags": [profile.get("learning_style", "읽기형")]}

        # 4. 스트리밍 시작
        prompt = self._build_reforge_prompt(text, profile)
        
        try:
            text_result = await _call_gemini_rest(
                prompt,
                model=MODEL,
                temperature=0.7,
                max_output_tokens=2048,
                timeout=120.0,
            )
            yield {"text": text_result}
            yield "DONE"
        except Exception as e:
            logger.error(f"[ReforgeService] 재가공 실패: {e}")
            yield {"error": str(e)}

    def _build_reforge_prompt(self, original_content: str, profile: dict) -> str:
        """기존 _reforge_one_with_context의 프롬프트 로직 재사용"""
        style = _normalize_learning_style(profile.get("learning_style", "읽기형"))
        paper_strategy = PAPER_STRATEGY.get(style, "")
        profile_instruction = _build_profile_instruction(style, profile)
        
        # profile_summary 생성
        vark = _normalize_learning_style(profile.get("learning_style", style))
        focus = profile.get("focus_pattern", "")
        diff_resp = profile.get("difficulty_response") or profile.get("pace", "")
        subject_level = profile.get("subject_level", "")
        level_label = {"beginner": "초급", "intermediate": "중급", "advanced": "고급"}.get(subject_level, "")
        profile_summary = f"VARK:{vark} / 집중:{focus} / 대응:{diff_resp} / 수준:{level_label}"
        source_excerpt = _build_source_excerpt(original_content, max_chars=22000)

        return f"""당신은 교육 콘텐츠 재해석 전문가입니다.
원본 교안을 학생 프로파일에 맞게 재해석하세요. 한국어로만 출력하세요.

━━━ 절대 원칙 ━━━
1. 원본 내용을 요약하지 마세요 — 재해석(reinterpretation)이 목표입니다
2. 코드 블록·수식·실습 예제·터미널 명령어·터미널 출력은 원본 그대로 보존, ``` 코드블록으로 감싸세요
3. 원본에 없는 내용을 추가하지 마세요 (환각 금지)
4. [시각자료], [다이어그램], [슬라이드 이미지], [코드 캡처] 블록은 삭제하지 말고 해당 위치에 남기세요
5. 실습 절차는 학생이 강의 중 그대로 따라할 수 있도록 단계별로 재배치하세요
6. 인사말·역할 설명 등 메타 문장 절대 금지
7. 순수 마크다운 본문만 출력

━━━ 학습 이론 근거 [{style}] ━━━
{paper_strategy}

━━━ 학생 프로파일 ━━━
{profile_summary}

━━━ 5차원 재해석 지침 ━━━
{profile_instruction}

━━━ 원본 교안 ━━━
{source_excerpt}

━━━ 출력 형식 ━━━
# [강의 제목] — {style} 맞춤 교안
> 학습 프로파일: {profile_summary}

---

[재해석된 본문 — 노션 스타일 마크다운]"""

    async def _reforge_one_with_context(
        self,
        style: str,
        original_content: str,
        core_points: list[dict],
        profile: dict,
        paper_context: str,
    ) -> str:
        """단일 스타일 재가공 — CoT + Few-shot + 환각방지 고급 프롬프트"""

        core_text = "\n".join(
            f"[중요도 {p.get('priority', 1)}/5] {p['content']}"
            for p in sorted(core_points, key=lambda x: x.get("priority", 0), reverse=True)
        )
        paper_strategy = PAPER_STRATEGY.get(style, "")
        profile_instruction = _build_profile_instruction(style, profile)

        # 학생 프로파일 요약 (헤더용)
        vark = _normalize_learning_style(profile.get("learning_style", style))
        focus = profile.get("focus_pattern", "")
        diff_resp = profile.get("difficulty_response") or profile.get("pace", "")
        dropout = profile.get("dropout_risk", "")
        conf = profile.get("confidence_score", 0)
        subject_level = profile.get("subject_level", "")
        level_label = {"beginner": "초급", "intermediate": "중급", "advanced": "고급"}.get(subject_level, "")
        profile_summary = f"VARK:{vark} / 집중:{focus} / 대응:{diff_resp}" + \
                         (f" / 이탈위험:{dropout}" if dropout else "") + \
                         (f" / 신뢰도:{conf}%" if conf else "") + \
                         (f" / 과목수준:{level_label}" if level_label else "")
        source_excerpt = _build_source_excerpt(original_content, max_chars=24000)

        prompt = f"""당신은 교육 콘텐츠 재해석 전문가입니다.
원본 교안을 학생 프로파일에 맞게 재해석하세요. 한국어로만 출력하세요.

━━━ 절대 원칙 ━━━
1. 원본 내용을 요약하지 마세요 — 재해석(reinterpretation)이 목표입니다
2. 코드 블록·수식·실습 예제·터미널 명령어·터미널 출력은 원본 그대로 보존, ``` 코드블록으로 감싸세요
3. 원본에 없는 내용을 추가하지 마세요 (환각 금지)
4. [시각자료], [다이어그램], [슬라이드 이미지], [코드 캡처] 블록은 삭제하지 말고 해당 위치에 남기세요
5. 이미지·시각자료가 있으면 원본에서 확인 가능한 구성요소와 관계를 보존해 [시각자료: ...]로 표시
6. 실습 절차는 학생이 강의 중 그대로 따라할 수 있도록 단계별로 재배치하세요
7. 교수 핵심 포인트는 모두 빠짐없이 포함
8. 인사말·역할 설명·"재해석하겠습니다" 같은 메타 문장 절대 금지
9. 순수 마크다운 본문만 출력 (노션 스타일)
10. 너무 짧게 쓰지 마세요. 원본 근거를 최소 10개 이상 살리고, 섹션을 6개 이상 구성하세요
11. 이미지/슬라이드에서 추출된 [시각자료/코드 캡처]는 반드시 별도 섹션으로 재배치하고, 수업 중 따라 해야 할 코드·명령어는 절대 압축하지 마세요
12. 출력이 길어도 완성된 마크다운 문서로 끝내세요. 마지막 섹션을 중간에 끊지 마세요

━━━ 학습 이론 근거 [{style}] ━━━
{paper_strategy}
{paper_context}

━━━ 학생 프로파일 ━━━
{profile_summary}

━━━ 5차원 재해석 지침 ━━━
{profile_instruction}

━━━ 교수 확정 핵심 포인트 (모두 포함 필수) ━━━
{core_text}

━━━ 원본 교안 ━━━
{source_excerpt}

━━━ 재해석 절차 ━━━
1. 원본에서 핵심 개념·사실·코드·시각자료를 식별한다
2. '{style}' 학습자에게 최적인 구조·어조·형식을 결정한다
3. 교수 핵심 포인트를 가장 잘 전달하는 섹션 배치를 계획한다
4. 코드·실습·시각자료를 보존한 채 완성된 교안을 노션 스타일 마크다운으로 작성한다

━━━ 출력 형식 ━━━
# [강의 제목] — {style} 맞춤 교안
> 학습 프로파일: {profile_summary}

---

## 핵심 포인트
[교수가 강조한 핵심 포인트를 {style} 방식으로 전달]

---

## 실습/코드 따라하기
[원본에 코드·명령어·실습 절차가 있으면 절대 요약하지 말고 그대로 보존한 뒤 단계별 안내를 붙임]

---

## 시각자료
[원본에 이미지·도식·표·코드 캡처가 있으면 삭제하지 말고 보존 설명]

---

[재해석된 본문 — 노션 스타일 마크다운]

━━━ 지금 바로 완성본만 작성하세요 ━━━"""

        try:
            raw = await generate_gemini_text(
                prompt,
                temperature=0.35,
                max_output_tokens=8192,
                timeout=90.0,
                feature=f"reforge:{style}",
            )
            cleaned = _clean_markdown(raw)
            if _needs_grounded_boost(cleaned, original_content):
                logger.warning(f"[reforge] {style} 출력이 짧거나 끊긴 것으로 판단 — 원본 근거 보강")
                cleaned = _append_grounded_boost(cleaned, style, original_content, core_text)
            return cleaned
        except asyncio.TimeoutError:
            logger.error(f"[reforge] {style} 타임아웃 (35s 초과)")
            return _fallback_content(style, core_text, original_content, profile_summary)
        except Exception as e:
            err = str(e)
            if "429" in err or "quota" in err.lower():
                logger.warning(f"[reforge] {style} 429 할당량 초과 — fallback 사용")
            else:
                logger.error(f"[reforge] {style} 모델 호출 실패: {err}")
            return _fallback_content(style, core_text, original_content, profile_summary)
