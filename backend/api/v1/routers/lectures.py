import logging
from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from models.lecture import LectureUploadResponse, CorePoint, CorePointConfirmRequest
from services.lecture_pipeline import LecturePipeline
from services.reforge_service import ReforgeService
from services.file_service import FileService
from services.firebase_service import FirebaseService

logger = logging.getLogger(__name__)
router = APIRouter(tags=["lectures"])
pipeline = LecturePipeline()
reforge_svc = ReforgeService()
file_svc = FileService()
firebase = FirebaseService()

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


@router.post("/lectures/upload", response_model=LectureUploadResponse)
async def upload_lecture(
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
        video_url=video_url,
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
                await firebase.upload_lecture_asset(
                    room_id,
                    lecture_id,
                    video_content,
                    video_file.filename or "video.bin",
                    video_file.content_type or "application/octet-stream",
                    "video",
                )
        except Exception as e:
            logger.warning(f"[upload] 영상 파일 Storage 업로드 실패: {e}")

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
async def get_reforged(room_id: str, lecture_id: str, user_id: str, test_style: str = ""):
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
            "styles": styles,
        }

    # ── 정상 모드 ─────────────────────────────────────────────────
    cached = await firebase.get_reforged_all(room_id, lecture_id, user_id)
    if cached:
        logger.info(f"[reforged] 캐시 히트 user={user_id} lecture={lecture_id}")
        return cached

    lecture = await firebase.get_lecture(room_id, lecture_id)
    if not lecture:
        raise HTTPException(status_code=404, detail="교안을 찾을 수 없습니다.")
    if not lecture.get("confirmed"):
        raise HTTPException(status_code=400, detail="교수가 아직 핵심 포인트를 확정하지 않았습니다.")

    diagnosis = await firebase.get_diagnosis(user_id)
    if not diagnosis:
        raise HTTPException(status_code=400, detail="학습 성향 진단을 먼저 완료해주세요.")

    profile = diagnosis["profile"]

    # 과목별 수준 주입 (4요소 재해석 핵심)
    level_data = await firebase.get_subject_level(user_id, room_id)
    if level_data:
        profile["subject_level"] = level_data.get("subject_level", "")
        logger.info(f"[reforged] 과목 수준 주입: {profile.get('subject_level')}")

    logger.info(f"[reforged] 6스타일 병렬 생성 시작 user={user_id} style={profile.get('learning_style')}")

    try:
        styles = await reforge_svc.reforge_with_rag(
            original_content=lecture.get("original_text", ""),
            core_points=lecture.get("core_points", []),
            profile=profile,
        )
    except Exception as e:
        logger.error(f"[reforged] 재가공 실패: {e}", exc_info=True)
        raise HTTPException(status_code=502, detail=f"교안 재가공 실패: {e}")

    await firebase.save_reforged_all(
        room_id, lecture_id, user_id, styles,
        profile.get("learning_style", "읽기형"),
        profile.get("subject_level", ""),
    )
    logger.info(f"[reforged] 완료 user={user_id}")

    return {
        "lecture_id": lecture_id,
        "primary_style": profile.get("learning_style", "읽기형"),
        "subject_level": profile.get("subject_level", ""),
        "styles": styles,
    }
