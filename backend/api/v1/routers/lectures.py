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


@router.get("/lectures/{room_id}/{lecture_id}/reforged")
async def get_reforged(room_id: str, lecture_id: str, user_id: str):
    """
    학생 성향에 맞는 6스타일 재가공 교안 반환.
    캐시 있으면 즉시 반환, 없으면 asyncio.gather()로 6스타일 동시 생성.
    """
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
    logger.info(
        f"[reforged] 6스타일 병렬 생성 시작 user={user_id} "
        f"style={profile.get('learning_style')}"
    )

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
