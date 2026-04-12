"""
재가공 데모 엔드포인트 — 로그인/Firebase 없이 핵심 AI 재가공 시스템 테스트
SSE 스트리밍 응답
"""
import asyncio
import json
import logging
import os
import threading
from google import genai
from google.genai import types
from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import StreamingResponse

from services.file_service import FileService


logger = logging.getLogger(__name__)
router = APIRouter(tags=["demo"])
file_svc = FileService()

MODEL = "gemma-4-31b-it"

# ── 성향별 재가공 가이드 ──────────────────────────────────────────────────────

_GUIDES = {
    # VARK
    "시각형":  "표·흐름도·다이어그램으로 시각화. 기호(▶ ■ →)와 구조적 배치 활용. 눈으로 한눈에 파악 가능하게.",
    "청각형":  "대화체·스토리텔링 문장. '자, 생각해보세요', '이렇게 기억하세요' 같은 구어 표현. 소리 내 읽기 좋은 리듬.",
    "읽기형":  "명확한 정의 + 체계적 목록 + 단계별 절차. 전문 용어 정확히 사용. 논문처럼 구조화.",
    "운동형":  "직접 해볼 수 있는 실습 단계. '따라해보세요', '직접 적용해보세요'. 구체 행동 중심.",
    # 인지
    "분석형":  "논리적 순서로 전개. 왜(Why)를 먼저 설명. 근거·원리·예외를 모두 다룸.",
    "직관형":  "전체 그림·핵심 개념 먼저. 패턴 강조. 세부 사항은 마지막에.",
    # 밀도
    "요약형":  "핵심 포인트만 3-5줄로 압축. 부연 설명 제거. 빠르게 스캔 가능하게.",
    "상세형":  "모든 단계를 빠짐없이 설명. 예외 케이스·주의사항 포함. 처음 배우는 사람도 이해 가능하게.",
    "예시형":  "모든 개념에 구체 예시·비유·실생활 사례 첨부. 스토리 중심. 예시 → 개념 순서.",
}

_TAGS = {
    "시각형": "👁️ 시각형 — 도식·표·흐름도",
    "청각형": "👂 청각형 — 대화체·스토리",
    "읽기형": "📖 읽기형 — 체계적 텍스트",
    "운동형": "🔧 운동형 — 실습·행동 중심",
    "분석형": "🔬 분석형 — 논리·근거 순서",
    "직관형": "💡 직관형 — 전체 그림 먼저",
    "요약형": "⚡ 요약형 — 핵심만 압축",
    "상세형": "🔍 상세형 — 빠짐없이 상세",
    "예시형": "📌 예시형 — 구체 사례 중심",
}


def _build_prompt(content: str, types: list[str]) -> str:
    guide_lines = "\n".join(f"  - [{t}] {_GUIDES.get(t, t)}" for t in types)
    label = " + ".join(types)
    return f"""당신은 교육 콘텐츠 재설계 전문가입니다.
다음 학습자 프로파일에 맞게 교안을 완전히 재가공하세요.

[학습자 프로파일: {label}]
{guide_lines}

[원본 교안]
{content[:3500]}

[재가공 규칙]
1. 위 프로파일 전략을 실제로 적용하세요
2. 마크다운 형식(# 헤더, - 목록, > 인용구, **강조**) 적극 활용
3. 내용의 핵심은 유지하되 형식·구조·표현을 프로파일에 맞게 완전히 바꾸세요
4. 학습자가 즉시 활용할 수 있는 완성도로 작성하세요
5. 분량: 원본과 비슷하거나 더 풍부하게
6. 반드시 한국어로만 작성하세요. 영어 인사말·설명 없이 마크다운 교안 내용만 바로 출력하세요"""


async def _stream_sse(content: str, learning_types: list[str]):
    """Gemini 스트리밍 → SSE 이벤트"""
    loop = asyncio.get_event_loop()
    q: asyncio.Queue = asyncio.Queue()

    def _sync():
        try:
            api_key = os.getenv("GEMINI_API_KEY")
            if not api_key:
                asyncio.run_coroutine_threadsafe(q.put(("error", "GEMINI_API_KEY 미설정")), loop)
                return

            _client = genai.Client(api_key=api_key)
            prompt = _build_prompt(content, learning_types)
            for chunk in _client.models.generate_content_stream(
                model=MODEL,
                contents=prompt,
                config=types.GenerateContentConfig(
                    temperature=0.7,
                    max_output_tokens=2048,
                    thinking_config={"thinking_budget": 0},
                ),
            ):
                if chunk.text:
                    asyncio.run_coroutine_threadsafe(q.put(("data", chunk.text)), loop)
            asyncio.run_coroutine_threadsafe(q.put(("done", None)), loop)
        except Exception as e:
            asyncio.run_coroutine_threadsafe(q.put(("error", str(e))), loop)

    threading.Thread(target=_sync, daemon=True).start()

    # 먼저 태그 전송
    tags = [_TAGS.get(t, t) for t in learning_types]
    yield f"data: {json.dumps({'tags': tags}, ensure_ascii=False)}\n\n"

    while True:
        try:
            kind, value = await asyncio.wait_for(q.get(), timeout=90)
        except asyncio.TimeoutError:
            yield f"data: {json.dumps({'error': '응답 시간 초과'}, ensure_ascii=False)}\n\n"
            break
        if kind == "data":
            yield f"data: {json.dumps({'text': value}, ensure_ascii=False)}\n\n"
        elif kind == "done":
            yield "data: [DONE]\n\n"
            break
        elif kind == "error":
            yield f"data: {json.dumps({'error': value}, ensure_ascii=False)}\n\n"
            break


@router.post("/reforge/demo")
async def demo_reforge(
    learning_type: str = Form(...),
    content: str = Form(""),
    file: UploadFile = File(None),
    room_id: str = Form(""),      # lecture_id와 함께 쓰면 Firebase 교안 자동 로드
    lecture_id: str = Form(""),   # 지정 시 Firebase에서 original_text 직접 사용
):
    """
    교안 재가공 데모 — SSE 스트리밍 응답 (로그인 불필요)

    Form fields:
    - learning_type : "시각형+분석형+요약형" 형태 조합 (필수)
    - content       : 텍스트 직접 입력 (선택)
    - file          : PDF/DOCX/PPTX 파일 (선택)
    - room_id       : Firebase 강의실 ID (lecture_id와 함께 사용)
    - lecture_id    : Firebase 교안 ID (지정 시 original_text 자동 사용)

    우선순위: lecture_id > file > content
    """
    # ── 수신 파라미터 상세 로그 ────────────────────────────────────────────
    logger.info(
        f"[demo] 요청 수신 │ "
        f"learning_type={learning_type!r} │ "
        f"content_len={len(content)} │ "
        f"file={getattr(file, 'filename', None)!r} │ "
        f"room_id={room_id!r} │ lecture_id={lecture_id!r}"
    )

    text = content.strip()
    source = "content"

    # ── ① lecture_id 있으면 Firebase에서 교안 가져오기 ─────────────────────
    if room_id and lecture_id:
        try:
            from services.firebase_service import FirebaseService
            _fb = FirebaseService()
            lecture = await _fb.get_lecture(room_id, lecture_id)
            if lecture and lecture.get("original_text"):
                text = lecture["original_text"]
                source = f"firebase(room={room_id}, lec={lecture_id})"
                logger.info(f"[demo] Firebase 교안 로드 ✓ len={len(text)}")
            else:
                logger.warning(
                    f"[demo] Firebase 교안 없음 — room={room_id} lec={lecture_id} "
                    f"(doc={lecture is not None})"
                )
        except Exception as e:
            logger.warning(f"[demo] Firebase 교안 로드 실패: {type(e).__name__}: {e}")

    # ── ② 파일 업로드 처리 (lecture_id 없거나 Firebase 실패 시) ────────────
    if not text and file and file.filename:
        try:
            raw = await file.read()
            extracted = await file_svc.extract_text(raw, file.filename)
            # 성공적 추출: 내용이 있으며, 단순 실패 메시지("[PDF 파싱 실패", "[PPTX 파싱 실패" 등)가 아님
            if extracted and not any(fail_word in extracted for fail_word in ["파싱 실패", "추출 실패"]):
                text = extracted
                source = f"file({file.filename})"
                logger.info(f"[demo] 파일 추출 ✓ file={file.filename} len={len(text)}")
            else:
                logger.warning(
                    f"[demo] 파일 추출 결과 이상(실패 또는 빈 내용) — file={file.filename} "
                    f"result_head={repr(extracted[:80]) if extracted else 'EMPTY'}"
                )
        except Exception as e:
            logger.warning(f"[demo] 파일 추출 실패: {type(e).__name__}: {e}")

    # ── ③ 텍스트 없으면 400 (상세 원인 포함) ──────────────────────────────
    if not text:
        if room_id and lecture_id:
            detail = (
                f"교안을 찾을 수 없습니다. "
                f"(room_id={room_id!r}, lecture_id={lecture_id!r})"
            )
        elif file and file.filename:
            detail = (
                f"파일에서 텍스트를 추출할 수 없습니다. "
                f"({file.filename}) — GEMINI_API_KEY 미설정이거나 지원하지 않는 형식일 수 있습니다."
            )
        else:
            detail = "교안 내용을 입력하거나 파일을 업로드하거나 lecture_id를 지정하세요."
        logger.error(f"[demo] 400 반환: {detail}")
        raise HTTPException(status_code=400, detail=detail)

    # ── ④ 학습 성향 파싱 ──────────────────────────────────────────────────
    types = [t.strip() for t in learning_type.replace("/", "+").split("+") if t.strip()]
    if not types:
        detail = f"학습 성향을 하나 이상 선택하세요. (수신값: {learning_type!r})"
        logger.error(f"[demo] 400 반환: {detail}")
        raise HTTPException(status_code=400, detail=detail)

    logger.info(f"[demo] 재가공 시작 │ types={types} │ source={source} │ text_len={len(text)}")

    return StreamingResponse(
        _stream_sse(text, types),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
