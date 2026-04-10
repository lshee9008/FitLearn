from pydantic import BaseModel
from typing import Optional, Literal


class RoomCreate(BaseModel):
    professor_uid: str
    subject: str
    description: str = ""
    room_type: Literal["online", "offline"] = "offline"
    synopsis: str = ""                      # 강의 줄거리/소개
    core_concepts: list[str] = []          # 핵심 개념 목록
    youtube_url: str = ""                   # 온라인 강의 YouTube URL


class Room(BaseModel):
    room_id: str
    room_code: str
    professor_uid: str
    professor_name: str = ""
    subject: str
    description: str = ""
    room_type: str = "offline"
    synopsis: str = ""
    core_concepts: list[str] = []
    youtube_url: str = ""
    student_count: int = 0
    has_quiz: bool = False                  # 수준판단 퀴즈 생성 여부


class JoinRoomRequest(BaseModel):
    user_id: str
    room_code: str


class RoomStudent(BaseModel):
    user_id: str
    name: str
    primary_style: Optional[str] = None
    social_type: Optional[str] = None
    cognitive_type: Optional[str] = None
    subject_level: Optional[str] = None    # beginner | intermediate | advanced


class RoomMetaUpdate(BaseModel):
    synopsis: str = ""
    core_concepts: list[str] = []
    youtube_url: str = ""
    room_type: Optional[Literal["online", "offline"]] = None
