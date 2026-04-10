import logging
from fastapi import APIRouter, BackgroundTasks, HTTPException
from pydantic import BaseModel

logger = logging.getLogger(__name__)

from models.room import RoomCreate, Room, JoinRoomRequest, RoomStudent, RoomMetaUpdate
from models.lecture import LectureMetaUpdate, LectureReorderRequest, LectureShellBatchRequest
from models.subject_quiz import QuizSubmitRequest, SubjectQuizResult
from services.firebase_service import FirebaseService
from services.quiz_service import QuizService

router = APIRouter(tags=["rooms"])
firebase = FirebaseService()
quiz_svc = QuizService()


async def _generate_and_save_quiz(room_id: str, synopsis: str, core_concepts: list[str], subject: str):
    try:
        questions = await quiz_svc.generate_quiz(
            synopsis=synopsis,
            core_concepts=core_concepts,
            subject=subject,
        )
        await firebase.save_room_quiz(room_id, questions)
        logger.info(f"[room_quiz] 생성 완료 room={room_id} count={len(questions)}")
    except Exception as e:
        logger.warning(f"[room_quiz] 생성 실패 room={room_id}: {e}")


@router.post("/rooms", response_model=Room)
async def create_room(body: RoomCreate, background_tasks: BackgroundTasks):
    try:
        user = await firebase.get_user(body.professor_uid)
        name = user.get("name", "") if user else ""
        data = await firebase.create_room(
            body.professor_uid, name, body.subject, body.description,
            room_type=body.room_type, synopsis=body.synopsis,
            core_concepts=body.core_concepts, youtube_url=body.youtube_url,
        )
        room = Room(**{k: data[k] for k in Room.model_fields if k in data})
        # synopsis + core_concepts 있으면 응답 후 백그라운드에서 퀴즈 생성
        if body.synopsis or body.core_concepts:
            background_tasks.add_task(
                _generate_and_save_quiz,
                data["room_id"],
                body.synopsis,
                body.core_concepts,
                body.subject,
            )
        return room
    except Exception as e:
        logger.error(f"[create_room] 실패: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"방 생성 실패: {e}")


@router.get("/rooms/student/{user_id}", response_model=list[Room])
async def list_student_rooms(user_id: str):
    try:
        rooms = await firebase.get_rooms_by_student(user_id)
        return [Room(**{k: r[k] for k in Room.model_fields if k in r}) for r in rooms]
    except Exception as e:
        logger.error(f"[list_student_rooms] user={user_id} error={e}", exc_info=True)
        return []


@router.get("/rooms/student/{user_id}/summary")
async def get_student_room_summary(user_id: str):
    rooms = await firebase.get_rooms_by_student(user_id)
    if not rooms:
        return {
            "room": None,
            "lectures": [],
            "subject_level": None,
            "score": None,
        }

    room = rooms[0]
    room_id = room["room_id"]
    lectures = await firebase.get_lectures_in_room(room_id)
    level_data = await firebase.get_subject_level(user_id, room_id)

    return {
        "room": {k: room[k] for k in Room.model_fields if k in room},
        "lectures": lectures,
        "subject_level": level_data.get("subject_level") if level_data else None,
        "score": level_data.get("score") if level_data else None,
    }


@router.get("/rooms/professor/{professor_uid}", response_model=list[Room])
async def list_rooms(professor_uid: str):
    rooms = await firebase.get_rooms_by_professor(professor_uid)
    return [Room(**{k: r[k] for k in Room.model_fields if k in r}) for r in rooms]


@router.post("/rooms/join", response_model=Room)
async def join_room(body: JoinRoomRequest):
    try:
        data = await firebase.get_room_by_code(body.room_code)
        if not data:
            raise HTTPException(status_code=404, detail="존재하지 않는 방 코드입니다.")
        await firebase.add_student_to_room(data["room_id"], body.user_id)
        return Room(**{k: data[k] for k in Room.model_fields if k in data})
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[join_room] 실패: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"방 참여 실패: {e}")


@router.get("/rooms/{room_id}", response_model=Room)
async def get_room(room_id: str):
    data = await firebase.get_room(room_id)
    if not data:
        raise HTTPException(status_code=404, detail="방을 찾을 수 없습니다.")
    return Room(**{k: data[k] for k in Room.model_fields if k in data})


@router.patch("/rooms/{room_id}/meta")
async def update_room_meta(room_id: str, body: RoomMetaUpdate, background_tasks: BackgroundTasks):
    """강의실 줄거리, 핵심개념, YouTube URL, room_type 업데이트 + 퀴즈 재생성"""
    update_data = body.model_dump(exclude_none=True, exclude_unset=True)
    if not update_data:
        raise HTTPException(status_code=400, detail="업데이트할 항목이 없습니다.")
    await firebase.update_room_meta(room_id, update_data)

    # synopsis 또는 core_concepts 변경 시 퀴즈 재생성
    if "synopsis" in update_data or "core_concepts" in update_data:
        room_data = await firebase.get_room(room_id)
        synopsis = update_data.get("synopsis", room_data.get("synopsis", ""))
        core_concepts = update_data.get("core_concepts", room_data.get("core_concepts", []))
        subject = room_data.get("subject", "") if room_data else ""
        background_tasks.add_task(
            _generate_and_save_quiz,
            room_id,
            synopsis,
            core_concepts,
            subject,
        )

    return {"status": "updated"}


@router.delete("/rooms/{room_id}")
async def delete_room(room_id: str):
    await firebase.delete_room(room_id)
    return {"status": "deleted"}


@router.get("/rooms/{room_id}/students", response_model=list[RoomStudent])
async def get_students(room_id: str):
    students = await firebase.get_room_students(room_id)
    return [RoomStudent(**s) for s in students]


@router.get("/rooms/{room_id}/lectures")
async def get_lectures(room_id: str):
    lectures = await firebase.get_lectures_in_room(room_id)
    return lectures


@router.post("/rooms/{room_id}/lectures/shells")
async def create_lecture_shells(room_id: str, body: LectureShellBatchRequest):
    created = await firebase.create_lecture_shells(
        room_id,
        [lecture.model_dump() for lecture in body.lectures],
    )
    return {"status": "created", "count": len(created), "lectures": created}


@router.patch("/rooms/{room_id}/lectures/{lecture_id}")
async def update_lecture(room_id: str, lecture_id: str, body: LectureMetaUpdate):
    update_data = body.model_dump(exclude_none=True, exclude_unset=True)
    if not update_data:
        raise HTTPException(status_code=400, detail="업데이트할 항목이 없습니다.")
    await firebase.update_lecture_meta(room_id, lecture_id, update_data)
    return {"status": "updated"}


@router.post("/rooms/{room_id}/lectures/reorder")
async def reorder_lectures(room_id: str, body: LectureReorderRequest):
    await firebase.reorder_lectures(
        room_id,
        [item.model_dump() for item in body.items],
    )
    return {"status": "reordered", "count": len(body.items)}


@router.delete("/rooms/{room_id}/lectures/{lecture_id}")
async def delete_lecture(room_id: str, lecture_id: str):
    await firebase.delete_lecture(room_id, lecture_id)
    return {"status": "deleted"}


# ── 수준판단 퀴즈 ──────────────────────────────────────────────────────────────

@router.get("/rooms/{room_id}/quiz")
async def get_quiz(room_id: str):
    """학생용 퀴즈 조회 (정답 필드 제거 후 반환)"""
    questions = await firebase.get_room_quiz(room_id)
    if not questions:
        raise HTTPException(status_code=404, detail="퀴즈가 아직 생성되지 않았습니다.")
    # 정답 노출 방지
    safe = [{k: v for k, v in q.items() if k != "correct_index"} for q in questions]
    return {"questions": safe, "count": len(safe)}


@router.post("/rooms/{room_id}/quiz/generate")
async def generate_quiz(room_id: str):
    """교수용: 수동으로 퀴즈 재생성"""
    room_data = await firebase.get_room(room_id)
    if not room_data:
        raise HTTPException(status_code=404, detail="방을 찾을 수 없습니다.")
    synopsis = room_data.get("synopsis", "")
    core_concepts = room_data.get("core_concepts", [])
    subject = room_data.get("subject", "")
    if not synopsis and not core_concepts:
        raise HTTPException(status_code=400, detail="먼저 강의 줄거리 또는 핵심 개념을 설정해주세요.")
    questions = await quiz_svc.generate_quiz(synopsis, core_concepts, subject)
    await firebase.save_room_quiz(room_id, questions)
    return {"status": "generated", "count": len(questions)}


@router.post("/rooms/{room_id}/quiz/submit", response_model=SubjectQuizResult)
async def submit_quiz(room_id: str, body: QuizSubmitRequest):
    """학생 퀴즈 답안 제출 → 채점 → subject_level 저장"""
    questions = await firebase.get_room_quiz(room_id)
    if not questions:
        raise HTTPException(status_code=404, detail="퀴즈가 없습니다.")
    result = quiz_svc.grade_quiz(questions, body.answers)
    await firebase.save_subject_level(
        user_id=body.user_id, room_id=room_id,
        score=result["score"], level=result["subject_level"],
        correct=result["correct_count"], total=result["total_count"],
    )
    return SubjectQuizResult(
        user_id=body.user_id, room_id=room_id,
        score=result["score"], subject_level=result["subject_level"],
        correct_count=result["correct_count"], total_count=result["total_count"],
    )


@router.get("/rooms/{room_id}/quiz/result/{user_id}")
async def get_quiz_result(room_id: str, user_id: str):
    """학생의 해당 강의실 수준판단 결과 조회"""
    data = await firebase.get_subject_level(user_id, room_id)
    if not data:
        return {"subject_level": None, "score": None}
    return data


# ── 공지사항 ─────────────────────────────────────────────────────────────────

class _NoticeCreate(BaseModel):
    professor_uid: str
    title: str = ""
    content: str


@router.get("/rooms/{room_id}/notices")
async def get_notices(room_id: str):
    notices = await firebase.get_notices(room_id)
    return notices


@router.post("/rooms/{room_id}/notices")
async def post_notice(room_id: str, body: _NoticeCreate):
    notice_id = await firebase.save_notice(
        room_id, body.content, body.professor_uid, body.title
    )
    return {"status": "created", "notice_id": notice_id}


@router.delete("/rooms/{room_id}/notices/{notice_id}")
async def delete_notice(room_id: str, notice_id: str):
    await firebase.delete_notice(room_id, notice_id)
    return {"status": "deleted"}
