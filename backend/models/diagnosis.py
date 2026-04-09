from pydantic import BaseModel
from typing import Optional


class DiagnosisAnswer(BaseModel):
    question_id: int
    answer: str          # "A" | "B" | "C" | "D"


class DiagnosisRequest(BaseModel):
    user_id: str
    room_id: Optional[str] = None
    answers: list[DiagnosisAnswer]


class DimensionScores(BaseModel):
    visual: int          # 시각성 0-100
    analytical: int      # 분석성 0-100
    focus_depth: int     # 집중깊이 0-100
    detail_pref: int     # 상세선호 0-100
    speed: int           # 속도 0-100
    collaboration: int   # 협력성 0-100


class LearningProfile(BaseModel):
    learning_style: str     # 시각형 | 청각형 | 읽기형 | 실습형
    cognitive_style: str    # 분석형 | 직관형
    focus_pattern: str      # 단기집중형 | 장기몰입형
    preferred_format: str   # 요약형 | 상세형 | 예시형
    pace: str               # 속도형 | 숙고형
    interaction: str        # 독립형 | 협력형
    scores: DimensionScores
    analysis: str


class DiagnosisResponse(BaseModel):
    user_id: str
    profile: LearningProfile
    strengths: list[str]
    weaknesses: list[str]
    strategies: list[str]


class QuestionRequest(BaseModel):
    user_id: str
    lecture_id: str
    question: str
