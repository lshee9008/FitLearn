from pydantic import BaseModel
from typing import Optional


class DiagnosisAnswer(BaseModel):
    question_id: int
    answer: str          # "A" | "B" | "C" | "D"


class DiagnosisRequest(BaseModel):
    user_id: str
    room_id: Optional[str] = None
    answers: list[DiagnosisAnswer]


class LearningProfile(BaseModel):
    primary_style: str           # 시각형 | 청각형 | 읽기형 | 운동형
    secondary_style: str
    social_type: str             # 내향형 | 외향형
    cognitive_type: str          # 분석형 | 직관형
    personality_summary: str


class DiagnosisResponse(BaseModel):
    user_id: str
    profile: LearningProfile
    strengths: list[str]
    weaknesses: list[str]
    recommendations: list[str]
    ai_analysis: str


class QuestionRequest(BaseModel):
    user_id: str
    lecture_id: str
    question: str
