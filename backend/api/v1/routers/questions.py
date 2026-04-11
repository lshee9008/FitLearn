from fastapi import APIRouter, Request

from models.diagnosis import QuestionRequest

router = APIRouter(tags=["questions"])



@router.post("/questions")
async def submit_question(request: Request, body: QuestionRequest):
    """수강생 질문 수집 및 Firestore 저장"""
    # TODO: Firestore 저장 구현
    return {"status": "received", "question_id": "placeholder"}
