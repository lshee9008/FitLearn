from fastapi import APIRouter, HTTPException

from models.user import RegisterRequest, UserProfile
from services.firebase_service import FirebaseService

router = APIRouter(tags=["auth"])
firebase = FirebaseService()


@router.post("/auth/register", response_model=UserProfile)
async def register(body: RegisterRequest):
    await firebase.save_user(body.user_id, body.name, body.role.value, body.email)
    return UserProfile(user_id=body.user_id, name=body.name, role=body.role, email=body.email)


@router.get("/auth/profile/{user_id}", response_model=UserProfile)
async def get_profile(user_id: str):
    data = await firebase.get_user(user_id)
    if not data:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
    return UserProfile(user_id=user_id, **data)
