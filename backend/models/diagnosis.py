from pydantic import BaseModel


class DiagnosisRequest(BaseModel):
    user_id: str
    answers: list[str]


class DiagnosisResponse(BaseModel):
    user_id: str
    learning_type: str        # "요약형" | "상세형" | "예시형"
    description: str          # 유형별 맞춤 학습 방식 설명


class QuestionRequest(BaseModel):
    user_id: str
    lecture_id: str
    question: str
