import logging
from fastapi import APIRouter, HTTPException

from models.user import RegisterRequest, UserProfile
from services.firebase_service import FirebaseService

logger = logging.getLogger(__name__)

router = APIRouter(tags=["auth"])
firebase = FirebaseService()


@router.post("/auth/register", response_model=UserProfile)
async def register(body: RegisterRequest):
    try:
        logger.info(f"[register] user_id={body.user_id} name={body.name} role={body.role} email={body.email}")
        await firebase.save_user(body.user_id, body.name, body.role.value, body.email)
        logger.info(f"[register] 성공 user_id={body.user_id}")
        return UserProfile(user_id=body.user_id, name=body.name, role=body.role, email=body.email)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[register] 실패 user_id={body.user_id} error={type(e).__name__}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"회원가입 처리 중 오류가 발생했습니다: {type(e).__name__}")


@router.get("/auth/profile/{user_id}", response_model=UserProfile)
async def get_profile(user_id: str):
    try:
        logger.info(f"[get_profile] user_id={user_id}")
        data = await firebase.get_user(user_id)
        if not data:
            logger.warning(f"[get_profile] 사용자 없음 user_id={user_id}")
            raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
        logger.info(f"[get_profile] 성공 user_id={user_id}")
        return UserProfile(user_id=user_id, **data)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[get_profile] 실패 user_id={user_id} error={type(e).__name__}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"프로필 조회 중 오류가 발생했습니다: {type(e).__name__}")
