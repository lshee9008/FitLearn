from fastapi import APIRouter, Request

router = APIRouter(tags=["dashboard"])


@router.get("/dashboard/{instructor_id}")
async def get_dashboard(request: Request, instructor_id: str):
    """강의자 인사이트: 질문 패턴 AI 분석 결과 반환"""
    # TODO: Claude로 질문 패턴 분석 구현
    return {"instructor_id": instructor_id, "insights": []}
