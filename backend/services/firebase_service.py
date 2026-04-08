import json
import os
from datetime import datetime, timezone

import firebase_admin
from firebase_admin import credentials, firestore

_initialized = False


def _init_firebase() -> None:
    global _initialized
    if _initialized or firebase_admin._apps:
        _initialized = True
        return
    cred_json = os.getenv("FIREBASE_CREDENTIALS")
    if not cred_json:
        raise RuntimeError("환경변수 FIREBASE_CREDENTIALS가 설정되지 않았습니다.")
    cred_dict = json.loads(cred_json)
    cred = credentials.Certificate(cred_dict)
    firebase_admin.initialize_app(cred)
    _initialized = True


class FirebaseService:
    def __init__(self):
        _init_firebase()
        self.db = firestore.client()

    async def save_diagnosis(
        self, user_id: str, learning_type: str, answers: list[str]
    ) -> None:
        """진단 결과를 Firestore users/{user_id}/diagnosis 컬렉션에 저장"""
        try:
            doc_ref = self.db.collection("users").document(user_id)
            doc_ref.set(
                {
                    "learning_type": learning_type,
                    "answers": answers,
                    "diagnosed_at": datetime.now(timezone.utc),
                },
                merge=True,
            )
        except Exception:
            # Firebase 저장 실패가 진단 응답을 막지 않도록 예외를 삼킴
            pass

    async def get_learning_type(self, user_id: str) -> str | None:
        """저장된 학습 유형 조회"""
        try:
            doc = self.db.collection("users").document(user_id).get()
            if doc.exists:
                return doc.to_dict().get("learning_type")
        except Exception:
            pass
        return None
