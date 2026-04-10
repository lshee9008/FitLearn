from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class QuizQuestion(BaseModel):
    id: int
    question: str
    options: list[str]          # 4개 보기
    correct_index: int          # 정답 인덱스 (0~3)
    explanation: str = ""       # 해설


class QuizSubmitRequest(BaseModel):
    user_id: str
    answers: list[int]          # 각 문제별 선택 인덱스


class SubjectQuizResult(BaseModel):
    user_id: str
    room_id: str
    score: int                  # 0~100
    subject_level: str          # "beginner" | "intermediate" | "advanced"
    correct_count: int
    total_count: int
