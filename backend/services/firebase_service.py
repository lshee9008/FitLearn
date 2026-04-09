"""
Firebase Firestore 서비스 — 사용자, 방, 진단, 교안 데이터 관리

주요 설계 원칙:
- 모든 Firestore 호출은 asyncio.to_thread()로 실행 (블로킹 방지)
- Firebase 미설정 또는 DB 미존재 시 no-op 모드로 동작 (서버 크래시 방지)
- 모든 쓰기 실패는 경고 로그만 남기고 계속 진행
"""
import asyncio
import json
import logging
import os
import secrets
import string
from datetime import datetime, timezone
from typing import Any, Optional

logger = logging.getLogger(__name__)

_firebase_ok = False  # Firebase 사용 가능 여부


def _init_firebase() -> bool:
    global _firebase_ok
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore as _fs

        if firebase_admin._apps:
            _firebase_ok = True
            return True

        cred_json = os.getenv("FIREBASE_CREDENTIALS")
        if not cred_json:
            logger.warning("[Firebase] FIREBASE_CREDENTIALS 미설정 — no-op 모드")
            return False

        cred = credentials.Certificate(json.loads(cred_json))
        firebase_admin.initialize_app(cred)
        _firebase_ok = True
        logger.info("[Firebase] 초기화 완료")
        return True
    except Exception as e:
        logger.error(f"[Firebase] 초기화 실패: {e}")
        return False


def _generate_room_code() -> str:
    chars = string.ascii_uppercase + string.digits
    return "".join(secrets.choice(chars) for _ in range(6))


def _get_db():
    """Firestore 클라이언트 반환. 실패 시 None."""
    try:
        from firebase_admin import firestore
        return firestore.client()
    except Exception as e:
        logger.error(f"[Firebase] DB 클라이언트 획득 실패: {e}")
        return None


# ── 초기화 실행 ──────────────────────────────────────────────────────────────
_init_firebase()


async def _run(fn, *args, **kwargs):
    """동기 Firestore 함수를 스레드 풀에서 실행 (이벤트 루프 블로킹 방지)"""
    return await asyncio.to_thread(fn, *args, **kwargs)


class FirebaseService:
    def __init__(self):
        self._db = None  # 지연 초기화

    @property
    def db(self):
        if self._db is None:
            self._db = _get_db()
        return self._db

    def _safe_db(self):
        """DB 없을 때 경고 후 None 반환"""
        db = self.db
        if db is None:
            logger.warning("[Firebase] DB 없음 — 작업 건너뜀")
        return db

    # ── 사용자 ────────────────────────────────────────────────────

    async def save_user(self, user_id: str, name: str, role: str, email: str = "") -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            def _write():
                db.collection("users").document(user_id).set(
                    {"name": name, "role": role, "email": email,
                     "created_at": datetime.now(timezone.utc)},
                    merge=True,
                )
            await _run(_write)
        except Exception as e:
            logger.warning(f"[Firebase] save_user 실패: {e}")

    async def get_user(self, user_id: str) -> Optional[dict]:
        db = self._safe_db()
        if db is None:
            return None
        try:
            def _read():
                doc = db.collection("users").document(user_id).get()
                return doc.to_dict() if doc.exists else None
            return await _run(_read)
        except Exception as e:
            logger.warning(f"[Firebase] get_user 실패: {e}")
            return None

    # ── 방 ────────────────────────────────────────────────────────

    async def create_room(
        self, professor_uid: str, professor_name: str, subject: str, description: str
    ) -> dict:
        code = _generate_room_code()
        db = self._safe_db()
        if db is None:
            return {"room_id": "offline", "room_code": code, "professor_uid": professor_uid,
                    "subject": subject, "description": description, "students": []}
        try:
            def _write():
                room_ref = db.collection("rooms").document()
                data = {
                    "room_id": room_ref.id, "room_code": code,
                    "professor_uid": professor_uid, "professor_name": professor_name,
                    "subject": subject, "description": description,
                    "students": [], "created_at": datetime.now(timezone.utc),
                }
                room_ref.set(data)
                return data
            return await _run(_write)
        except Exception as e:
            logger.error(f"[Firebase] create_room 실패: {e}")
            raise

    async def get_rooms_by_student(self, user_id: str) -> list[dict]:
        db = self._safe_db()
        if db is None:
            return []
        try:
            def _read():
                docs = (
                    db.collection("rooms")
                    .where("students", "array_contains", user_id)
                    .stream()
                )
                result = []
                for doc in docs:
                    d = doc.to_dict()
                    d["student_count"] = len(d.get("students", []))
                    result.append(d)
                return result
            return await _run(_read)
        except Exception as e:
            logger.warning(f"[Firebase] get_rooms_by_student 실패: {e}")
            return []

    async def get_rooms_by_professor(self, professor_uid: str) -> list[dict]:
        db = self._safe_db()
        if db is None:
            return []
        try:
            def _read():
                docs = (
                    db.collection("rooms")
                    .where("professor_uid", "==", professor_uid)
                    .stream()
                )
                result = []
                for doc in docs:
                    d = doc.to_dict()
                    d["student_count"] = len(d.get("students", []))
                    result.append(d)
                return result
            return await _run(_read)
        except Exception as e:
            logger.warning(f"[Firebase] get_rooms_by_professor 실패: {e}")
            return []

    async def get_room_by_code(self, code: str) -> Optional[dict]:
        db = self._safe_db()
        if db is None:
            return None
        try:
            def _read():
                docs = list(
                    db.collection("rooms")
                    .where("room_code", "==", code.upper())
                    .limit(1)
                    .stream()
                )
                return docs[0].to_dict() if docs else None
            return await _run(_read)
        except Exception as e:
            logger.warning(f"[Firebase] get_room_by_code 실패: {e}")
            return None

    async def get_room(self, room_id: str) -> Optional[dict]:
        db = self._safe_db()
        if db is None:
            return None
        try:
            def _read():
                doc = db.collection("rooms").document(room_id).get()
                if not doc.exists:
                    return None
                d = doc.to_dict()
                d["student_count"] = len(d.get("students", []))
                return d
            return await _run(_read)
        except Exception as e:
            logger.warning(f"[Firebase] get_room 실패: {e}")
            return None

    async def add_student_to_room(self, room_id: str, user_id: str) -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            from firebase_admin import firestore
            def _write():
                db.collection("rooms").document(room_id).update(
                    {"students": firestore.ArrayUnion([user_id])}
                )
            await _run(_write)
        except Exception as e:
            logger.warning(f"[Firebase] add_student_to_room 실패: {e}")

    async def delete_room(self, room_id: str) -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            await _run(lambda: db.collection("rooms").document(room_id).delete())
        except Exception as e:
            logger.warning(f"[Firebase] delete_room 실패: {e}")

    async def get_room_students(self, room_id: str) -> list[dict]:
        db = self._safe_db()
        if db is None:
            return []
        try:
            def _read():
                doc = db.collection("rooms").document(room_id).get()
                if not doc.exists:
                    return []
                student_ids = doc.to_dict().get("students", [])
                result = []
                for uid in student_ids:
                    user_doc = db.collection("users").document(uid).get()
                    if user_doc.exists:
                        u = user_doc.to_dict()
                        diag_doc = db.collection("diagnosis").document(uid).get()
                        profile = diag_doc.to_dict().get("profile", {}) if diag_doc.exists else {}
                        result.append({
                            "user_id": uid,
                            "name": u.get("name", uid),
                            "primary_style": profile.get("learning_style"),
                            "cognitive_style": profile.get("cognitive_style"),
                        })
                return result
            return await _run(_read)
        except Exception as e:
            logger.warning(f"[Firebase] get_room_students 실패: {e}")
            return []

    # ── 진단 ──────────────────────────────────────────────────────

    async def save_diagnosis(self, user_id: str, profile: dict, report: dict) -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            def _write():
                db.collection("diagnosis").document(user_id).set(
                    {"profile": profile, "report": report,
                     "diagnosed_at": datetime.now(timezone.utc)},
                    merge=True,
                )
                db.collection("users").document(user_id).set(
                    {"learning_profile": profile}, merge=True
                )
            await _run(_write)
        except Exception as e:
            logger.warning(f"[Firebase] save_diagnosis 실패: {e}")

    async def get_diagnosis(self, user_id: str) -> Optional[dict]:
        db = self._safe_db()
        if db is None:
            return None
        try:
            def _read():
                doc = db.collection("diagnosis").document(user_id).get()
                return doc.to_dict() if doc.exists else None
            return await _run(_read)
        except Exception as e:
            logger.warning(f"[Firebase] get_diagnosis 실패: {e}")
            return None

    # ── 교안 ──────────────────────────────────────────────────────

    async def save_lecture(
        self, room_id: str, title: str, original_text: str, core_points: list
    ) -> str:
        db = self._safe_db()
        if db is None:
            return "offline-lecture"
        try:
            def _write():
                ref = (
                    db.collection("rooms").document(room_id)
                    .collection("lectures").document()
                )
                ref.set({
                    "lecture_id": ref.id,
                    "room_id": room_id,
                    "title": title,
                    "original_text": original_text,
                    "core_points": core_points,
                    "confirmed": False,
                    "created_at": datetime.now(timezone.utc),
                })
                return ref.id
            return await _run(_write)
        except Exception as e:
            logger.error(f"[Firebase] save_lecture 실패: {e}")
            raise

    async def get_lecture(self, room_id: str, lecture_id: str) -> Optional[dict]:
        db = self._safe_db()
        if db is None:
            return None
        try:
            def _read():
                doc = (
                    db.collection("rooms").document(room_id)
                    .collection("lectures").document(lecture_id)
                    .get()
                )
                return doc.to_dict() if doc.exists else None
            return await _run(_read)
        except Exception as e:
            logger.warning(f"[Firebase] get_lecture 실패: {e}")
            return None

    async def confirm_core_points(
        self, room_id: str, lecture_id: str, core_points: list
    ) -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            def _write():
                db.collection("rooms").document(room_id)\
                    .collection("lectures").document(lecture_id)\
                    .update({"core_points": core_points, "confirmed": True})
            await _run(_write)
        except Exception as e:
            logger.warning(f"[Firebase] confirm_core_points 실패: {e}")

    async def get_lectures_in_room(self, room_id: str) -> list[dict]:
        db = self._safe_db()
        if db is None:
            return []
        try:
            def _read():
                docs = (
                    db.collection("rooms").document(room_id)
                    .collection("lectures")
                    .stream()
                )
                return [doc.to_dict() for doc in docs]
            return await _run(_read)
        except Exception as e:
            logger.warning(f"[Firebase] get_lectures_in_room 실패: {e}")
            return []

    async def save_reforged_all(
        self,
        room_id: str,
        lecture_id: str,
        user_id: str,
        styles: dict[str, str],
        primary_style: str,
    ) -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            def _write():
                db.collection("rooms").document(room_id)\
                    .collection("lectures").document(lecture_id)\
                    .collection("reforged").document(user_id)\
                    .set({
                        "styles": styles,
                        "primary_style": primary_style,
                        "generated_at": datetime.now(timezone.utc),
                    })
            await _run(_write)
        except Exception as e:
            logger.warning(f"[Firebase] save_reforged_all 실패: {e}")

    async def get_reforged_all(
        self, room_id: str, lecture_id: str, user_id: str
    ) -> Optional[dict]:
        db = self._safe_db()
        if db is None:
            return None
        try:
            def _read():
                doc = (
                    db.collection("rooms").document(room_id)
                    .collection("lectures").document(lecture_id)
                    .collection("reforged").document(user_id)
                    .get()
                )
                if not doc.exists:
                    return None
                d = doc.to_dict()
                return {
                    "lecture_id": lecture_id,
                    "primary_style": d.get("primary_style", "읽기형"),
                    "styles": d.get("styles", {}),
                }
            return await _run(_read)
        except Exception as e:
            logger.warning(f"[Firebase] get_reforged_all 실패: {e}")
            return None

    # ── 하위호환 ─────────────────────────────────────────────────

    async def save_reforged(
        self, room_id: str, lecture_id: str, user_id: str, content: str, style: str
    ) -> None:
        await self.save_reforged_all(room_id, lecture_id, user_id, {style: content}, style)

    async def get_reforged(
        self, room_id: str, lecture_id: str, user_id: str
    ) -> Optional[dict]:
        result = await self.get_reforged_all(room_id, lecture_id, user_id)
        if not result:
            return None
        primary = result["primary_style"]
        return {"content": result["styles"].get(primary, ""), "style": primary}
