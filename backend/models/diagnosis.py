from pydantic import BaseModel
from typing import Optional


class DiagnosisAnswer(BaseModel):
    question_id: int
    answer: str          # "A" | "B" | "C" | "D" | 자유서술
    response_time_ms: int = 0  # 응답 시간 (ms)


class DiagnosisRequest(BaseModel):
    user_id: str
    room_id: Optional[str] = None
    answers: list[DiagnosisAnswer]
    writing_response: str = ""      # 자유서술 Q0
    learning_history: dict = {}     # {subject, reason, difficulty}


class ReliabilityCheck(BaseModel):
    pair_s8_s16: float = 1.0    # 분석/집중 패턴 교차 검증
    pair_s9_s17: float = 1.0    # 전체그림/학습 진행 방식 교차 검증
    pair_s11_s18: float = 1.0   # 순차/시각 보조 선호 교차 검증
    overall: float = 1.0         # 전체 신뢰도 (0.0~1.0)


class DimensionScores(BaseModel):
    visual: int = 50         # 시각성 0-100
    analytical: int = 50     # 분석성 0-100
    focus_depth: int = 50    # 집중깊이 0-100
    detail_pref: int = 50    # 상세선호 0-100
    speed: int = 50          # 속도 0-100
    collaboration: int = 50  # 협력성 0-100
    metacognition: int = 50  # 메타인지 0-100 (신규)
    consistency: int = 50    # 일관성 0-100 (신규)


class LearningProfile(BaseModel):
    learning_style: str     # 시각형 | 청각형 | 읽기형 | 실습형
    cognitive_style: str    # 분석형 | 직관형
    focus_pattern: str      # 단기집중형 | 장기몰입형
    preferred_format: str   # 요약형 | 상세형 | 예시형
    pace: str               # 속도형 | 숙고형
    interaction: str        # 독립형 | 협력형
    scores: DimensionScores
    analysis: str
    reliability: ReliabilityCheck = ReliabilityCheck()
    writing_insight: str = ""       # 글쓰기 패턴 분석 결과
    # RAG 분석 확장 필드
    vark: dict = {}                 # VARK 점수
    felder: dict = {}               # Felder 차원 점수
    cognitive_load: dict = {}       # 인지부하 점수
    kolb_type: str = ""             # Kolb 유형
    confidence_score: int = 70      # AI 신뢰도 점수
    paper_citations: list[str] = [] # 논문 인용 목록


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
