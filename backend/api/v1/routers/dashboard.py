from fastapi import APIRouter, HTTPException

from services.firebase_service import FirebaseService
from services.gemini_service import GeminiService

router = APIRouter(tags=["dashboard"])
firebase = FirebaseService()
gemini = GeminiService()


@router.get("/dashboard/{room_id}")
async def get_dashboard(room_id: str):
    """교수용 대시보드: 학생 성향 분포 + AI 인사이트"""
    room = await firebase.get_room(room_id)
    if not room:
        raise HTTPException(status_code=404, detail="방을 찾을 수 없습니다.")

    students = await firebase.get_room_students(room_id)

    style_dist: dict[str, int] = {}
    social_dist: dict[str, int] = {}
    cognitive_dist: dict[str, int] = {}

    for s in students:
        if s.get("primary_style"):
            style_dist[s["primary_style"]] = style_dist.get(s["primary_style"], 0) + 1
        if s.get("social_type"):
            social_dist[s["social_type"]] = social_dist.get(s["social_type"], 0) + 1
        if s.get("cognitive_type"):
            cognitive_dist[s["cognitive_type"]] = cognitive_dist.get(s["cognitive_type"], 0) + 1

    diagnosed = [s for s in students if s.get("primary_style")]
    ai_insight = await gemini.analyze_student_patterns(diagnosed)

    return {
        "room": room,
        "total_students": len(students),
        "diagnosed_count": len(diagnosed),
        "style_distribution": style_dist,
        "social_distribution": social_dist,
        "cognitive_distribution": cognitive_dist,
        "ai_insight": ai_insight,
        "students": students,
    }
