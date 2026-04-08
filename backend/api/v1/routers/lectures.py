from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from models.lecture import LectureUploadResponse, CorePoint, CorePointConfirmRequest, ReforgeResponse
from services.gemini_service import GeminiService
from services.file_service import FileService
from services.firebase_service import FirebaseService

router = APIRouter(tags=["lectures"])
gemini = GeminiService()
file_svc = FileService()
firebase = FirebaseService()


@router.post("/lectures/upload", response_model=LectureUploadResponse)
async def upload_lecture(
    room_id: str = Form(...),
    professor_uid: str = Form(...),
    file: UploadFile = File(...),
):
    """파일 업로드 → 텍스트 추출 → Gemini 핵심 포인트 3~5개 추출"""
    content = await file.read()
    try:
        text = await file_svc.extract_text(content, file.filename or "upload.txt")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    try:
        core_points_raw = await gemini.extract_core_points(text)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"AI 분석 실패: {e}")

    lecture_id = await firebase.save_lecture(
        room_id,
        title=file.filename or "교안",
        original_text=text,
        core_points=core_points_raw,
    )

    core_points = [CorePoint(**cp) for cp in core_points_raw]
    return LectureUploadResponse(
        lecture_id=lecture_id,
        title=file.filename or "교안",
        core_points=core_points,
    )


@router.get("/lectures/{room_id}/{lecture_id}")
async def get_lecture(room_id: str, lecture_id: str):
    data = await firebase.get_lecture(room_id, lecture_id)
    if not data:
        raise HTTPException(status_code=404, detail="교안을 찾을 수 없습니다.")
    return data


@router.post("/lectures/{room_id}/{lecture_id}/confirm")
async def confirm_core_points(room_id: str, lecture_id: str, body: CorePointConfirmRequest):
    """교수가 핵심 포인트 검토 후 확정"""
    points = [cp.model_dump() for cp in body.confirmed_points]
    await firebase.confirm_core_points(room_id, lecture_id, points)
    return {"status": "confirmed", "count": len(points)}


@router.get("/lectures/{room_id}/{lecture_id}/reforged", response_model=ReforgeResponse)
async def get_reforged(room_id: str, lecture_id: str, user_id: str):
    """학생 성향에 맞는 재가공 교안 반환 (캐시 → Gemini 생성)"""
    cached = await firebase.get_reforged(room_id, lecture_id, user_id)
    if cached:
        return ReforgeResponse(lecture_id=lecture_id, style=cached["style"], content=cached["content"])

    lecture = await firebase.get_lecture(room_id, lecture_id)
    if not lecture:
        raise HTTPException(status_code=404, detail="교안을 찾을 수 없습니다.")
    if not lecture.get("confirmed"):
        raise HTTPException(status_code=400, detail="교수가 아직 핵심 포인트를 확정하지 않았습니다.")

    diagnosis = await firebase.get_diagnosis(user_id)
    if not diagnosis:
        raise HTTPException(status_code=400, detail="학습 성향 진단을 먼저 완료해주세요.")

    profile = diagnosis["profile"]
    content = await gemini.reforge_content(
        original_content=lecture.get("original_text", ""),
        core_points=lecture.get("core_points", []),
        primary_style=profile.get("primary_style", "읽기형"),
        secondary_style=profile.get("secondary_style", ""),
        social_type=profile.get("social_type", "내향형"),
        cognitive_type=profile.get("cognitive_type", "분석형"),
    )

    style = profile.get("primary_style", "읽기형")
    await firebase.save_reforged(room_id, lecture_id, user_id, content, style)
    return ReforgeResponse(lecture_id=lecture_id, style=style, content=content)
