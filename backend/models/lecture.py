from pydantic import BaseModel
from typing import Optional


class CorePoint(BaseModel):
    id: int
    content: str
    confirmed: bool = True
    priority: int = 1            # 1(최우선) ~ 5


class LectureUploadResponse(BaseModel):
    lecture_id: str
    title: str
    core_points: list[CorePoint]


class CorePointConfirmRequest(BaseModel):
    lecture_id: str
    professor_uid: str
    confirmed_points: list[CorePoint]


class ReforgedContent(BaseModel):
    style: str
    content: str


class ReforgeRequest(BaseModel):
    user_id: str
    lecture_id: str
    lecture_content: str = ""    # legacy compat


class ReforgeResponse(BaseModel):
    lecture_id: str
    style: str
    content: str
