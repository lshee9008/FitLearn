from fastapi import APIRouter, HTTPException

from models.room import RoomCreate, Room, JoinRoomRequest, RoomStudent
from services.firebase_service import FirebaseService

router = APIRouter(tags=["rooms"])
firebase = FirebaseService()


@router.post("/rooms", response_model=Room)
async def create_room(body: RoomCreate):
    user = await firebase.get_user(body.professor_uid)
    name = user.get("name", "") if user else ""
    data = await firebase.create_room(body.professor_uid, name, body.subject, body.description)
    return Room(**{k: data[k] for k in Room.model_fields if k in data})


@router.get("/rooms/professor/{professor_uid}", response_model=list[Room])
async def list_rooms(professor_uid: str):
    rooms = await firebase.get_rooms_by_professor(professor_uid)
    return [Room(**{k: r[k] for k in Room.model_fields if k in r}) for r in rooms]


@router.post("/rooms/join", response_model=Room)
async def join_room(body: JoinRoomRequest):
    data = await firebase.get_room_by_code(body.room_code)
    if not data:
        raise HTTPException(status_code=404, detail="존재하지 않는 방 코드입니다.")
    await firebase.add_student_to_room(data["room_id"], body.user_id)
    return Room(**{k: data[k] for k in Room.model_fields if k in data})


@router.get("/rooms/{room_id}", response_model=Room)
async def get_room(room_id: str):
    data = await firebase.get_room(room_id)
    if not data:
        raise HTTPException(status_code=404, detail="방을 찾을 수 없습니다.")
    return Room(**{k: data[k] for k in Room.model_fields if k in data})


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
