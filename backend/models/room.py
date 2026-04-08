from pydantic import BaseModel
from typing import Optional


class RoomCreate(BaseModel):
    professor_uid: str
    subject: str
    description: str = ""


class Room(BaseModel):
    room_id: str
    room_code: str          # 6자리 입장 코드
    professor_uid: str
    professor_name: str = ""
    subject: str
    description: str = ""
    student_count: int = 0


class JoinRoomRequest(BaseModel):
    user_id: str
    room_code: str


class RoomStudent(BaseModel):
    user_id: str
    name: str
    primary_style: Optional[str] = None
    social_type: Optional[str] = None
    cognitive_type: Optional[str] = None
