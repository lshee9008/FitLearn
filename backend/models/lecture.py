from pydantic import BaseModel
from typing import Optional


class CorePoint(BaseModel):
    id: int
    content: str
    confirmed: bool = True
    priority: int = 3           # 1-5 (5=최우선)
    topic: str = ""             # 주제 분류
    difficulty: str = "중"      # 상 | 중 | 하
    review_question: str = ""   # 교수 검토용 AI 생성 질문


class LectureShellCreate(BaseModel):
    title: str
    order: int = 0
    video_url: str = ""
    material_url: str = ""


class LectureShellBatchRequest(BaseModel):
    lectures: list[LectureShellCreate]


class LectureMetaUpdate(BaseModel):
    title: Optional[str] = None
    order_index: Optional[int] = None
    week_number: Optional[int] = None
    video_url: Optional[str] = None
    material_url: Optional[str] = None


class LectureReorderItem(BaseModel):
    lecture_id: str
    order_index: int


class LectureReorderRequest(BaseModel):
    items: list[LectureReorderItem]


class LectureUploadResponse(BaseModel):
    lecture_id: str
    title: str
    core_points: list[CorePoint]
    lecture_summary: str = ""           # 교안 전체 요약 (2-3문장)
    topics: list[str] = []             # 주제 분류 목록
    learning_objectives: list[str] = [] # 학습 목표
    estimated_difficulty: str = "중"    # 전체 난이도
    word_count: int = 0                 # 원본 텍스트 길이


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
