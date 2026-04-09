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


@router.post("/lectures/upload", response_model=LectureUploadResponse)
async def upload_lecture(
    room_id: str = Form(...),
    professor_uid: str = Form(...),
    file: UploadFile = File(...),
):
    """
    파일 업로드 → 8단계 AI 파이프라인:
    전처리 → RAG → 핵심추출 → 주제분류 → 난이도판단 → 학습목표 → 검토질문 → 후처리
    지원: PDF, PPT/PPTX, DOCX, HWP/HWPX, MD, TXT
    """
    logger.info(f"[upload] room={room_id} professor={professor_uid} file={file.filename}")
    content = await file.read()

    try:
        text = await file_svc.extract_text(content, file.filename or "upload.txt")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    if not text or text.startswith("[") and "실패" in text:
        raise HTTPException(
            status_code=422,
            detail=f"파일에서 텍스트를 추출할 수 없습니다. ({file.filename})"
        )

    # 8단계 AI 파이프라인 실행
    try:
        result = await pipeline.run(text)
    except Exception as e:
        logger.error(f"[upload] 파이프라인 실패: {e}", exc_info=True)
        raise HTTPException(status_code=502, detail=f"AI 분석 실패: {e}")

    lecture_id = await firebase.save_lecture(
        room_id,
        title=file.filename or "교안",
        original_text=text,
        core_points=result["core_points"],
    )
    logger.info(f"[upload] 완료 lecture_id={lecture_id} points={len(result['core_points'])}")

    return LectureUploadResponse(
        lecture_id=lecture_id,
        title=file.filename or "교안",
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
        return {"lecture_id": lecture_id, "primary_style": test_style, "styles": styles}

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
        profile.get("learning_style", "읽기형")
    )
    logger.info(f"[reforged] 완료 user={user_id}")

    return {
        "lecture_id": lecture_id,
        "primary_style": profile.get("learning_style", "읽기형"),
        "styles": styles,
    }
