import logging
import os
import re
import uuid
from pathlib import Path
from fastapi import APIRouter, BackgroundTasks, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel

from models.lecture import LectureUploadResponse, CorePoint, CorePointConfirmRequest
from services.lecture_pipeline import LecturePipeline
from services.reforge_service import ReforgeService, generate_gemini_text
from services.file_service import FileService
from services.firebase_service import FirebaseService
from services.video_pipeline import VideoPipeline

logger = logging.getLogger(__name__)
router = APIRouter(tags=["lectures"])
pipeline = LecturePipeline()
reforge_svc = ReforgeService()
file_svc = FileService()
firebase = FirebaseService()
video_pipeline = VideoPipeline()
LOCAL_ASSET_DIR = Path(os.getenv("FITLEARN_ASSET_DIR", "/tmp/fitlearn_assets"))
REFORGED_CACHE_VERSION = 2
FALLBACK_CACHE_MARKERS = (
    "AI 서버 응답 지연",
    "AI 응답이 지연",
    "기본 형식으로 제공",
    "기본 재해석 문서",
)


def _is_stale_reforged_cache(cached: dict | None) -> bool:
    if not cached:
        return True
    if cached.get("cache_version") != REFORGED_CACHE_VERSION:
        return True
    styles = cached.get("styles") or {}
    return _has_fallback_content(styles)


def _has_fallback_content(styles: dict) -> bool:
    return any(
        marker in content
        for content in styles.values()
        if isinstance(content, str)
        for marker in FALLBACK_CACHE_MARKERS
    )


def _as_int(value, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _public_backend_url() -> str:
    return (
        os.getenv("PUBLIC_BACKEND_URL")
        or os.getenv("RENDER_EXTERNAL_URL")
        or "https://fitlearn-backend.onrender.com"
    ).rstrip("/")


async def _save_local_video_asset(file_bytes: bytes, filename: str, content_type: str) -> str:
    suffix = Path(filename or "video.mp4").suffix or ".mp4"
    asset_id = f"{uuid.uuid4().hex}{suffix}"
    LOCAL_ASSET_DIR.mkdir(parents=True, exist_ok=True)
    path = LOCAL_ASSET_DIR / asset_id
    path.write_bytes(file_bytes)
    return f"{_public_backend_url()}/api/v1/lectures/assets/{asset_id}"


class VideoAssistRequest(BaseModel):
    user_id: str
    start_minute: int = 0
    end_minute: int = 0
    question: str = ""


async def _process_uploaded_video_transcript(
    room_id: str,
    lecture_id: str,
    video_bytes: bytes,
    filename: str,
    mime_type: str,
    title: str,
    original_text: str,
    core_points: list[dict],
) -> None:
    try:
        await firebase.update_lecture_meta(room_id, lecture_id, {
            "transcription_status": "processing",
            "transcription_error": "",
        })
        result = await video_pipeline.transcribe_uploaded_video(
            video_bytes=video_bytes,
            filename=filename,
            mime_type=mime_type,
            title=title,
            original_text=original_text,
            core_points=core_points,
        )
        await firebase.update_lecture_meta(room_id, lecture_id, {
            "video_transcript": result.get("transcript", ""),
            "video_segments": result.get("segments", []),
            "chapters": result.get("chapters", []),
            "video_summary": result.get("summary_markdown", ""),
            "video_key_moments": result.get("key_moments", []),
            "video_study_tips": result.get("study_tips", []),
            "video_stuck_points": result.get("stuck_points", []),
            "summary_cache": {"default": result.get("summary_markdown", "")},
            "summary_status": "ready",
            "transcription_status": "ready",
            "transcription_error": "",
        })
        logger.info(f"[video_transcript] 완료 room={room_id} lecture={lecture_id}")
    except Exception as e:
        logger.warning(f"[video_transcript] 실패 room={room_id} lecture={lecture_id}: {e}")
        await firebase.update_lecture_meta(room_id, lecture_id, {
            "transcription_status": "failed",
            "transcription_error": str(e)[:500],
            "summary_status": "failed",
        })


async def _process_youtube_transcript(
    room_id: str,
    lecture_id: str,
    video_url: str,
    title: str,
    original_text: str,
    core_points: list[dict],
) -> None:
    try:
        await firebase.update_lecture_meta(room_id, lecture_id, {
            "transcription_status": "processing",
            "transcription_error": "",
            "summary_status": "processing",
        })
        result = await video_pipeline.transcribe_youtube_url(
            video_url=video_url,
            title=title,
            original_text=original_text,
            core_points=core_points,
        )
        await firebase.update_lecture_meta(room_id, lecture_id, {
            "video_transcript": result.get("transcript", ""),
            "video_segments": result.get("segments", []),
            "chapters": result.get("chapters", []),
            "video_summary": result.get("summary_markdown", ""),
            "video_key_moments": result.get("key_moments", []),
            "video_study_tips": result.get("study_tips", []),
            "video_stuck_points": result.get("stuck_points", []),
            "summary_cache": {"default": result.get("summary_markdown", "")},
            "summary_status": "ready",
            "transcription_status": "ready",
            "transcription_error": "",
        })
        logger.info(f"[youtube_transcript] 완료 room={room_id} lecture={lecture_id}")
    except Exception as e:
        logger.warning(f"[youtube_transcript] 실패 room={room_id} lecture={lecture_id}: {e}")
        await firebase.update_lecture_meta(room_id, lecture_id, {
            "transcription_status": "failed",
            "transcription_error": str(e)[:500],
            "summary_status": "failed",
        })

_DEMO_LECTURE = """
# 학습심리학 기초 — 인지부하이론과 학습 전략

## 1. 인지부하이론 (Cognitive Load Theory)
Sweller(1988)가 제안한 이론으로, 인간의 작업기억(Working Memory)은 한정된 용량을 가지며
한 번에 처리할 수 있는 정보의 양에 제한이 있다.

### 핵심 개념
- **내재적 부하(Intrinsic Load)**: 학습 내용 자체의 복잡성에서 비롯된 부하
- **외재적 부하(Extraneous Load)**: 잘못된 교수 설계로 인한 불필요한 부하
- **생성적 부하(Germane Load)**: 스키마 형성을 위한 유용한 인지 활동

### 교육적 시사점
1. 한 번에 너무 많은 정보 제시 금지
2. 불필요한 장식 요소 제거
3. 사전 지식과 연결하여 스키마 활성화

## 2. VARK 학습 모델 (Fleming, 1992)
학습자를 네 가지 감각 선호에 따라 분류:

- **V(Visual)**: 도표, 그래프, 흐름도 선호
- **A(Aural)**: 강의, 토론, 설명 선호
- **R(Read/Write)**: 읽기와 필기 선호
- **K(Kinesthetic)**: 실습, 체험, 사례 선호

## 3. Kolb의 경험학습 사이클 (1984)
구체적 경험 → 반성적 관찰 → 추상적 개념화 → 능동적 실험

학습자 유형:
- 수렴형: 실용적, 문제 해결 중심
- 발산형: 창의적, 다양한 관점
- 동화형: 논리적, 이론 중심
- 조절형: 행동 지향, 실험적

## 4. Felder-Silverman 학습 스타일 모델
감각/직관, 시각/언어, 능동/반성, 순차/전체 4개 차원으로 학습 스타일 분류.
각 차원은 연속적 스펙트럼으로 구성되며 절대적 분류가 아님.
"""

_DEMO_CORE_POINTS = [
    {"id": 1, "content": "작업기억의 한정 용량 — 인지부하 3종류(내재적/외재적/생성적)", "priority": 5, "topic": "인지부하이론", "difficulty": "중"},
    {"id": 2, "content": "VARK 4가지 학습 감각 유형 분류와 교수 전략", "priority": 5, "topic": "VARK 모델", "difficulty": "하"},
    {"id": 3, "content": "Kolb 경험학습 사이클 4단계와 학습자 유형", "priority": 4, "topic": "경험학습", "difficulty": "중"},
    {"id": 4, "content": "Felder-Silverman 4차원 연속 스펙트럼 모델", "priority": 3, "topic": "학습 스타일", "difficulty": "중"},
]


def _resolve_video_meta(video_url: str, has_video_file: bool, title: str) -> dict:
    clean_url = (video_url or "").strip()
    if has_video_file:
        return {
            "video_type": "upload",
            "video_url": clean_url,
            "video_title": title,
            "video_status": "processing",
            "video_source": "uploaded_file",
        }
    if clean_url:
        is_youtube = bool(re.search(r"(youtube\.com|youtu\.be)", clean_url, re.IGNORECASE))
        return {
            "video_type": "youtube" if is_youtube else "external",
            "video_url": clean_url,
            "video_title": title,
            "video_status": "ready",
            "video_source": "youtube" if is_youtube else "external_url",
        }
    return {
        "video_type": "none",
        "video_url": "",
        "video_title": "",
        "video_status": "none",
        "video_source": "none",
    }


@router.post("/lectures/upload", response_model=LectureUploadResponse)
async def upload_lecture(
    background_tasks: BackgroundTasks,
    room_id: str = Form(...),
    professor_uid: str = Form(...),
    file: UploadFile = File(...),
    week_number: int = Form(0),
    lecture_title: str = Form(""),
    lecture_id: str = Form(""),
    order_index: int = Form(0),
    video_url: str = Form(""),
    material_url: str = Form(""),
    video_file: UploadFile | None = File(None),
):
    """
    파일 업로드 → 8단계 AI 파이프라인
    지원: PDF, PPT/PPTX, DOCX, HWP/HWPX, MD, TXT, 이미지, 코드파일
    week_number: 주차 (0=미지정), lecture_title: 교수 입력 제목
    """
    resolved_title = lecture_title.strip() or file.filename or "교안"
    logger.info(f"[upload] room={room_id} professor={professor_uid} "
                f"file={file.filename} week={week_number} title={resolved_title}")
    content = await file.read()

    try:
        text = await file_svc.extract_text(content, file.filename or "upload.txt")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    if not text or (text.startswith("[") and "실패" in text):
        raise HTTPException(
            status_code=422,
            detail=f"파일에서 텍스트를 추출할 수 없습니다. ({file.filename})"
        )

    video_meta = _resolve_video_meta(video_url, video_file is not None, resolved_title)

    try:
        result = await pipeline.run(text)
    except Exception as e:
        logger.error(f"[upload] 파이프라인 실패: {e}", exc_info=True)
        raise HTTPException(status_code=502, detail=f"AI 분석 실패: {e}")

    lecture_id = await firebase.save_lecture(
        room_id,
        title=resolved_title,
        original_text=text,
        core_points=result["core_points"],
        week_number=week_number,
        lecture_id=lecture_id,
        order_index=order_index,
        video_url=video_meta["video_url"],
        video_type=video_meta["video_type"],
        video_title=video_meta["video_title"],
        video_status=video_meta["video_status"],
        video_source=video_meta["video_source"],
        material_url=material_url,
    )
    
    # Storage 원본 파일 업로드 (백그라운드 또는 비동기 대기. MVP이므로 대기)
    try:
        content_type = file.content_type or "application/octet-stream"
        await firebase.upload_original_file(
            room_id, lecture_id, content, file.filename or "upload.bin", content_type
        )
    except Exception as e:
        logger.warning(f"[upload] 원본 파일 Storage 업로드 실패: {e}")

    if video_file is not None:
        try:
            video_content = await video_file.read()
            if video_content:
                video_filename = video_file.filename or "video.bin"
                video_content_type = video_file.content_type or "application/octet-stream"
                video_public_url = await firebase.upload_lecture_asset(
                    room_id,
                    lecture_id,
                    video_content,
                    video_filename,
                    video_content_type,
                    "video",
                )
                if not video_public_url:
                    video_public_url = await _save_local_video_asset(
                        video_content,
                        video_filename,
                        video_content_type,
                    )
                    logger.warning(f"[upload] Firebase Storage 미사용 — 로컬 영상 URL 폴백 lecture={lecture_id}")
                await firebase.update_lecture_meta(room_id, lecture_id, {
                    "video_url": video_public_url,
                    "video_asset_url": video_public_url,
                    "video_status": "ready",
                    "video_type": "upload",
                    "video_source": "uploaded_file",
                    "transcription_status": "queued",
                    "summary_status": "processing",
                })
                background_tasks.add_task(
                    _process_uploaded_video_transcript,
                    room_id,
                    lecture_id,
                    video_content,
                    video_filename,
                    video_content_type,
                    resolved_title,
                    text,
                    result["core_points"],
                )
        except Exception as e:
            logger.warning(f"[upload] 영상 파일 Storage 업로드 실패: {e}")
    elif video_meta["video_type"] == "youtube" and video_meta["video_url"]:
        await firebase.update_lecture_meta(room_id, lecture_id, {
            "transcription_status": "queued",
            "summary_status": "processing",
        })
        background_tasks.add_task(
            _process_youtube_transcript,
            room_id,
            lecture_id,
            video_meta["video_url"],
            resolved_title,
            text,
            result["core_points"],
        )

    logger.info(f"[upload] 완료 lecture_id={lecture_id} points={len(result['core_points'])}")

    return LectureUploadResponse(
        lecture_id=lecture_id,
        title=resolved_title,
        core_points=[CorePoint(**cp) for cp in result["core_points"]],
        lecture_summary=result.get("lecture_summary", ""),
        topics=result.get("topics", []),
        learning_objectives=result.get("learning_objectives", []),
        estimated_difficulty=result.get("estimated_difficulty", "중"),
        word_count=result.get("word_count", 0),
    )


@router.get("/lectures/{room_id}/{lecture_id}")
async def get_lecture(room_id: str, lecture_id: str):
    data = await firebase.get_lecture(room_id, lecture_id)
    if not data:
        raise HTTPException(status_code=404, detail="교안을 찾을 수 없습니다.")
    return data


@router.post("/lectures/{room_id}/{lecture_id}/confirm")
async def confirm_core_points(room_id: str, lecture_id: str, body: CorePointConfirmRequest):
    """교수가 핵심 포인트 검토 확정"""
    points = [cp.model_dump() for cp in body.confirmed_points]
    await firebase.confirm_core_points(room_id, lecture_id, points)
    logger.info(f"[confirm] room={room_id} lecture={lecture_id} points={len(points)}")
    return {"status": "confirmed", "count": len(points)}


@router.get("/lectures/{room_id}/{lecture_id}/original")
async def get_original_file(room_id: str, lecture_id: str):
    """원본 교안 파일 다운로드 URL 반환"""
    url = await firebase.get_lecture_original_url(room_id, lecture_id)
    if not url:
        raise HTTPException(status_code=404, detail="원본 파일이 없습니다.")
    return {"url": url}


@router.get("/lectures/assets/{asset_id}")
async def get_local_lecture_asset(asset_id: str):
    path = (LOCAL_ASSET_DIR / asset_id).resolve()
    if not str(path).startswith(str(LOCAL_ASSET_DIR.resolve())) or not path.exists():
        raise HTTPException(status_code=404, detail="영상 파일을 찾을 수 없습니다.")
    return FileResponse(path)


@router.post("/lectures/{room_id}/{lecture_id}/video/assist")
async def assist_video_segment(room_id: str, lecture_id: str, body: VideoAssistRequest):
    lecture = await firebase.get_lecture(room_id, lecture_id)
    if not lecture:
        raise HTTPException(status_code=404, detail="교안을 찾을 수 없습니다.")

    profile = await _resolve_student_profile(body.user_id, room_id)
    start = max(body.start_minute, 0)
    end = max(body.end_minute, start)
    question = body.question.strip()
    segment_label = f"{start}분~{end}분" if end > start else f"{start}분 전후"
    core_points = lecture.get("core_points", [])
    core_text = "\n".join(
        f"- {point.get('content', '')}"
        for point in core_points[:8]
        if point.get("content")
    )
    original_text = lecture.get("original_text", "")[:4500]
    transcript = (
        lecture.get("video_transcript")
        or lecture.get("transcript")
        or lecture.get("captions")
        or ""
    )
    transcript_text = str(transcript)[:4500] if transcript else ""
    video_segments = lecture.get("video_segments") or []
    video_url = lecture.get("video_url") or ""
    video_type = lecture.get("video_type") or ""
    if not transcript_text and (video_type == "youtube" or "youtu" in video_url):
        try:
            logger.info(f"[video_assist] 전사 없음 — YouTube 전사 온디맨드 시도 lecture={lecture_id}")
            await _process_youtube_transcript(
                room_id,
                lecture_id,
                video_url,
                lecture.get("title") or lecture_id,
                lecture.get("original_text", ""),
                core_points,
            )
            lecture = await firebase.get_lecture(room_id, lecture_id) or lecture
            transcript_text = str(lecture.get("video_transcript") or "")[:4500]
            video_segments = lecture.get("video_segments") or []
        except Exception as e:
            logger.warning(f"[video_assist] YouTube 전사 온디맨드 실패: {e}")
    segment_context = "\n".join(
        f"- {item.get('start_minute', 0)}~{item.get('end_minute', 0)}분: {item.get('text', '')}"
        for item in video_segments
        if isinstance(item, dict)
        and _as_int(item.get("end_minute")) >= start
        and _as_int(item.get("start_minute")) <= end
        and item.get("text")
    )[:3500]

    prompt = f"""당신은 온라인 강의 학습 도우미입니다.
학생이 영상의 특정 구간을 보다가 궁금한 점을 물었습니다.
반드시 아래 영상 전사, 원본 교안, 교수 핵심 포인트만 근거로 답하세요.
영상 전사가 비어 있으면 영상 화면·음성 내용을 본 것처럼 말하지 마세요.
질문이 제공된 근거와 직접 연결되지 않으면 "현재 자료만으로는 확인 어렵습니다"라고 먼저 밝히세요.
원본에 없는 사실을 꾸며내지 말고, 불확실하면 "교안 근거상 확인 가능한 범위"라고 표시하세요.

[학생 프로필]
{_public_profile_summary(profile)}

[요청 구간]
{segment_label}

[학생 질문]
{question or "이 구간이 잘 이해되지 않습니다. 핵심을 다시 설명해주세요."}

[교수 핵심 포인트]
{core_text}

[영상 전사]
{transcript_text or "영상 전사가 아직 없습니다. 교안과 교수 핵심 포인트만 근거로 답해야 합니다."}

[요청 구간과 겹치는 전사 세그먼트]
{segment_context or "요청 구간과 직접 매칭되는 전사 세그먼트가 없습니다."}

[원본 교안]
{original_text}

[출력 형식]
## {segment_label} 이해 가이드
- 핵심 요지 3개
- 학생 프로필에 맞춘 쉬운 설명
- 지금 바로 확인할 질문 2개
- 교안 근거상 주의할 점
"""

    try:
        answer = await generate_gemini_text(
            prompt,
            temperature=0.25,
            max_output_tokens=900,
            timeout=28.0,
            feature="video_assist",
        )
    except Exception as e:
        logger.warning(f"[video_assist] AI 생성 실패 fallback: {e}")
        answer = f"""## {segment_label} 이해 가이드

- 현재 영상 전사가 없어 영상 화면·음성 내용을 직접 확인한 답변은 제공할 수 없습니다.
- 아래 내용은 교수 핵심 포인트와 원본 교안 기준의 기본 안내입니다.
- 질문: {question or "핵심 내용이 이해되지 않습니다."}
- 핵심 포인트:
{core_text or "- 교수 핵심 포인트가 아직 비어 있습니다."}

> 영상 구간별 정확한 답변을 위해서는 업로드 영상 전사 또는 자막 추출 파이프라인이 필요합니다.
"""

    return {
        "segment": {"start_minute": start, "end_minute": end},
        "question": question,
        "answer": answer,
        "profile": _public_profile_summary(profile),
    }


_TEST_PROFILES = {
    "시각형": {"learning_style": "시각형", "cognitive_style": "직관형", "focus_pattern": "단기집중형",
               "pace": "속도형", "preferred_format": "시각적 다이어그램", "kolb_type": "수렴형", "confidence_score": 90},
    "청각형": {"learning_style": "청각형", "cognitive_style": "직관형", "focus_pattern": "장기몰입형",
               "pace": "숙고형", "preferred_format": "대화체 설명", "kolb_type": "발산형", "confidence_score": 90},
    "읽기형": {"learning_style": "읽기형", "cognitive_style": "분석형", "focus_pattern": "장기몰입형",
               "pace": "숙고형", "preferred_format": "체계적 텍스트", "kolb_type": "동화형", "confidence_score": 90},
    "실습형": {"learning_style": "실습형", "cognitive_style": "직관형", "focus_pattern": "단기집중형",
               "pace": "속도형", "preferred_format": "단계별 실습", "kolb_type": "조절형", "confidence_score": 90},
    "요약형": {"learning_style": "요약형", "cognitive_style": "분석형", "focus_pattern": "단기집중형",
               "pace": "속도형", "preferred_format": "핵심 압축", "kolb_type": "수렴형", "confidence_score": 90},
    "상세형": {"learning_style": "상세형", "cognitive_style": "분석형", "focus_pattern": "장기몰입형",
               "pace": "숙고형", "preferred_format": "상세 단계 설명", "kolb_type": "동화형", "confidence_score": 90},
}


def _fallback_profile_from_user(user: dict | None) -> dict:
    learning_profile = (user or {}).get("learning_profile", {}) or {}
    if learning_profile:
        return {
            "learning_style": learning_profile.get("learning_style")
            or learning_profile.get("vark")
            or "읽기형",
            "cognitive_style": learning_profile.get("cognitive_style", "분석형"),
            "focus_pattern": learning_profile.get("focus_pattern", "단기집중형"),
            "preferred_format": learning_profile.get("preferred_format", "상세형"),
            "pace": learning_profile.get("pace", "숙고형"),
            "interaction": learning_profile.get("interaction", "독립형"),
            "confidence_score": learning_profile.get("confidence_score", 60),
        }

    return {
        "learning_style": "읽기형",
        "cognitive_style": "분석형",
        "focus_pattern": "단기집중형",
        "preferred_format": "상세형",
        "pace": "숙고형",
        "interaction": "독립형",
        "confidence_score": 40,
    }


async def _resolve_student_profile(user_id: str, room_id: str) -> dict:
    diagnosis = await firebase.get_diagnosis(user_id)
    if diagnosis and diagnosis.get("profile"):
        profile = diagnosis["profile"]
    else:
        user = await firebase.get_user(user_id)
        profile = _fallback_profile_from_user(user)
        logger.info(f"[reforged] 진단 문서 없음 — users.learning_profile/default 폴백 user={user_id}")

    level_data = await firebase.get_subject_level(user_id, room_id)
    if level_data:
        profile["subject_level"] = level_data.get("subject_level", "")
        profile["subject_score"] = level_data.get("score")
        logger.info(f"[reforged] 과목 수준 주입: {profile.get('subject_level')}")

    return profile


def _public_profile_summary(profile: dict) -> dict:
    reliability = profile.get("reliability", {}) or {}
    return {
        "vark_type": profile.get("learning_style", "읽기형"),
        "focus_pattern": profile.get("focus_pattern", "단기집중형"),
        "difficulty_response": profile.get("difficulty_response") or profile.get("pace", "숙고형"),
        "dropout_risk": profile.get("dropout_risk") or profile.get("isolation_risk", ""),
        "confidence_score": profile.get("confidence_score", 0),
        "subject_level": profile.get("subject_level", ""),
        "subject_score": profile.get("subject_score"),
        "reliability": {
            "pair_s8_s16": reliability.get("pair_s8_s16", 0.75),
            "pair_s9_s17": reliability.get("pair_s9_s17", 0.75),
            "pair_s11_s18": reliability.get("pair_s11_s18", 0.75),
            "overall": reliability.get("overall", 0.75),
        },
    }


@router.get("/lectures/demo/reforged")
async def get_demo_reforged(test_style: str = "읽기형"):
    """Firebase 없이 내장 샘플 교안으로 재가공 테스트."""
    profile = _TEST_PROFILES.get(test_style, _TEST_PROFILES["읽기형"])
    logger.info(f"[demo-reforged] style={test_style}")
    try:
        styles = await reforge_svc.reforge_with_rag(
            original_content=_DEMO_LECTURE,
            core_points=_DEMO_CORE_POINTS,
            profile=profile,
        )
    except Exception as e:
        logger.error(f"[demo-reforged] 실패: {e}", exc_info=True)
        raise HTTPException(status_code=502, detail=f"재가공 실패: {e}")
    return {"lecture_id": "demo", "primary_style": test_style, "styles": styles}


from pydantic import BaseModel as _BM

class _CustomReforgeRequest(_BM):
    test_style: str = "읽기형"
    content: str = ""  # 비어 있으면 내장 샘플 사용


@router.post("/lectures/demo/reforged")
async def post_custom_reforged(body: _CustomReforgeRequest):
    """커스텀 텍스트로 재가공 테스트 (POST)."""
    profile = _TEST_PROFILES.get(body.test_style, _TEST_PROFILES["읽기형"])
    content = body.content.strip() if body.content.strip() else _DEMO_LECTURE
    logger.info(f"[custom-reforged] style={body.test_style} len={len(content)}")
    try:
        styles = await reforge_svc.reforge_with_rag(
            original_content=content,
            core_points=_DEMO_CORE_POINTS,
            profile=profile,
        )
    except Exception as e:
        logger.error(f"[custom-reforged] 실패: {e}", exc_info=True)
        raise HTTPException(status_code=502, detail=f"재가공 실패: {e}")
    return {"lecture_id": "custom", "primary_style": body.test_style, "styles": styles}


@router.get("/lectures/{room_id}/{lecture_id}/reforged")
async def get_reforged(
    room_id: str,
    lecture_id: str,
    user_id: str,
    test_style: str = "",
    refresh: bool = False,
):
    """
    학생 성향에 맞는 6스타일 재가공 교안 반환.
    - test_style 지정 시: Firebase 진단 없이 해당 스타일 프로필로 즉시 재가공 (테스트용)
    - 캐시 있으면 즉시 반환, 없으면 asyncio.gather()로 6스타일 동시 생성.
    """
    # ── 테스트 모드 ───────────────────────────────────────────────
    if test_style:
        profile = _TEST_PROFILES.get(test_style, _TEST_PROFILES["읽기형"])
        logger.info(f"[reforged] 테스트 모드 style={test_style} lecture={lecture_id}")
        lecture = await firebase.get_lecture(room_id, lecture_id)
        if not lecture:
            raise HTTPException(status_code=404, detail="교안을 찾을 수 없습니다.")
        try:
            styles = await reforge_svc.reforge_with_rag(
                original_content=lecture.get("original_text", ""),
                core_points=lecture.get("core_points", []),
                profile=profile,
            )
        except Exception as e:
            logger.error(f"[reforged] 재가공 실패: {e}", exc_info=True)
            raise HTTPException(status_code=502, detail=f"교안 재가공 실패: {e}")
        return {
            "lecture_id": lecture_id,
            "primary_style": test_style,
            "subject_level": profile.get("subject_level", ""),
            "cache_version": REFORGED_CACHE_VERSION,
            "profile": _public_profile_summary(profile),
            "styles": styles,
        }

    # ── 정상 모드 ─────────────────────────────────────────────────
    profile = await _resolve_student_profile(user_id, room_id)
    cached = await firebase.get_reforged_all(room_id, lecture_id, user_id)
    if cached and not refresh and not _is_stale_reforged_cache(cached):
        logger.info(f"[reforged] 캐시 히트 user={user_id} lecture={lecture_id}")
        cached["profile"] = _public_profile_summary(profile)
        return cached
    if cached:
        logger.info(f"[reforged] 캐시 무효화 후 재생성 user={user_id} lecture={lecture_id} refresh={refresh}")

    lecture = await firebase.get_lecture(room_id, lecture_id)
    if not lecture:
        raise HTTPException(status_code=404, detail="교안을 찾을 수 없습니다.")
    if not lecture.get("confirmed"):
        raise HTTPException(status_code=400, detail="교수가 아직 핵심 포인트를 확정하지 않았습니다.")

    primary_style = profile.get("learning_style", "읽기형")
    logger.info(f"[reforged] 주 스타일 우선 생성 시작 user={user_id} style={primary_style}")

    try:
        primary_content = await reforge_svc.reforge_for_student(
            original_content=lecture.get("original_text", ""),
            core_points=lecture.get("core_points", []),
            profile=profile,
        )
        styles = {primary_style: primary_content}
    except Exception as e:
        logger.error(f"[reforged] 재가공 실패: {e}", exc_info=True)
        raise HTTPException(status_code=502, detail=f"교안 재가공 실패: {e}")

    if _has_fallback_content(styles):
        logger.warning(f"[reforged] fallback 결과 감지 — 캐시 저장 생략 user={user_id} lecture={lecture_id}")
    else:
        await firebase.save_reforged_all(
            room_id, lecture_id, user_id, styles,
            primary_style,
            profile.get("subject_level", ""),
            cache_version=REFORGED_CACHE_VERSION,
        )
    logger.info(f"[reforged] 완료 user={user_id}")

    return {
        "lecture_id": lecture_id,
        "primary_style": primary_style,
        "subject_level": profile.get("subject_level", ""),
        "cache_version": REFORGED_CACHE_VERSION,
        "profile": _public_profile_summary(profile),
        "styles": styles,
    }
