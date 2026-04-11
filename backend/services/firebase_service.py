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
from services.redis_service import RedisService

logger = logging.getLogger(__name__)

_firebase_ok = False  # Firebase 사용 가능 여부
_cache = RedisService()
_CACHE_TTL = 60 * 5


def _normalize_firestore_value(value):
    if isinstance(value, dict):
        return {k: _normalize_firestore_value(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_normalize_firestore_value(v) for v in value]
    if hasattr(value, "isoformat"):
        try:
            return value.isoformat()
        except Exception:
            return value
    return value


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
        bucket_name = os.getenv("FIREBASE_STORAGE_BUCKET")
        options = {}
        if bucket_name:
            options["storageBucket"] = bucket_name

        if options:
            firebase_admin.initialize_app(cred, options)
        else:
            firebase_admin.initialize_app(cred)

        _firebase_ok = True
        logger.info(f"[Firebase] 초기화 완료 (Storage: {'사용' if bucket_name else '미사용'})")
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

    async def _cache_get(self, key: str):
        try:
            return await _cache.get(key)
        except Exception as e:
            logger.warning(f"[Cache] get 실패 key={key}: {e}")
            return None

    async def _cache_set(self, key: str, value, ttl: int = _CACHE_TTL):
        try:
            await _cache.set(key, _normalize_firestore_value(value), ttl=ttl)
        except Exception as e:
            logger.warning(f"[Cache] set 실패 key={key}: {e}")

    async def _cache_delete_prefix(self, prefix: str):
        try:
            await _cache.delete_prefix(prefix)
        except Exception as e:
            logger.warning(f"[Cache] delete_prefix 실패 prefix={prefix}: {e}")

    # ── 사용자 ────────────────────────────────────────────────────

    async def save_user(self, user_id: str, name: str, role: str, email: str = "") -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            def _write():
                db.collection("users").document(user_id).set(
                    {"name": name, "role": role, "email": email,
                     "is_active": True,
                     "last_seen_at": datetime.now(timezone.utc),
                     "created_at": datetime.now(timezone.utc)},
                    merge=True,
                )
            await _run(_write)
        except Exception as e:
            logger.warning(f"[Firebase] save_user 실패: {e}")

    async def touch_user(self, user_id: str) -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            def _write():
                db.collection("users").document(user_id).set(
                    {
                        "is_active": True,
                        "last_seen_at": datetime.now(timezone.utc),
                    },
                    merge=True,
                )
            await _run(_write)
        except Exception as e:
            logger.warning(f"[Firebase] touch_user 실패: {e}")

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
        self, professor_uid: str, professor_name: str, subject: str, description: str,
        room_type: str = "offline", synopsis: str = "",
        core_concepts: list = None, youtube_url: str = ""
    ) -> dict:
        code = _generate_room_code()
        db = self._safe_db()
        base = {
            "room_id": "offline", "room_code": code,
            "professor_uid": professor_uid, "professor_name": professor_name,
            "subject": subject, "description": description,
            "room_type": room_type, "synopsis": synopsis,
            "core_concepts": core_concepts or [], "youtube_url": youtube_url,
            "has_quiz": False, "students": [],
        }
        if db is None:
            return base
        try:
            def _write():
                room_ref = db.collection("rooms").document()
                now = datetime.now(timezone.utc)
                data = {**base, "room_id": room_ref.id, "created_at": now}
                room_ref.set(data)
                data["created_at"] = now.isoformat()
                return data
            data = await _run(_write)
            await self._cache_delete_prefix(f"professor_rooms:{professor_uid}")
            await self._cache_delete_prefix("room_catalog:")
            return data
        except Exception as e:
            logger.error(f"[Firebase] create_room 실패: {e}")
            return base

    async def get_rooms_by_student(self, user_id: str) -> list[dict]:
        cache_key = f"student_rooms:{user_id}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached
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
                    d = _normalize_firestore_value(doc.to_dict())
                    d["student_count"] = len(d.get("students", []))
                    result.append(d)
                return result
            result = await _run(_read)
            await self._cache_set(cache_key, result)
            return result
        except Exception as e:
            logger.warning(f"[Firebase] get_rooms_by_student 실패: {e}")
            return []

    async def get_rooms_by_professor(self, professor_uid: str) -> list[dict]:
        cache_key = f"professor_rooms:{professor_uid}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached
        db = self._safe_db()
        if db is None:
            return []
        try:
            def _read():
                try:
                    docs = list((
                        db.collection("rooms")
                        .where("professor_uid", "==", professor_uid)
                        .order_by("created_at", direction="DESCENDING")
                        .stream()
                    ))
                    ordered = True
                except Exception as e:
                    if "requires an index" not in str(e).lower():
                        raise
                    logger.warning("[Firebase] professor rooms 인덱스 없음 — 메모리 정렬로 폴백")
                    docs = list((
                        db.collection("rooms")
                        .where("professor_uid", "==", professor_uid)
                        .stream()
                    ))
                    ordered = False
                result = []
                for doc in docs:
                    d = _normalize_firestore_value(doc.to_dict())
                    d["student_count"] = len(d.get("students", []))
                    result.append(d)
                if not ordered:
                    result.sort(key=lambda item: item.get("created_at") or "", reverse=True)
                return result
            result = await _run(_read)
            await self._cache_set(cache_key, result)
            return result
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
                return _normalize_firestore_value(docs[0].to_dict()) if docs else None
            return await _run(_read)
        except Exception as e:
            logger.warning(f"[Firebase] get_room_by_code 실패: {e}")
            return None

    async def get_room(self, room_id: str) -> Optional[dict]:
        cache_key = f"room:{room_id}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached
        db = self._safe_db()
        if db is None:
            return None
        try:
            def _read():
                doc = db.collection("rooms").document(room_id).get()
                if not doc.exists:
                    return None
                d = _normalize_firestore_value(doc.to_dict())
                d["student_count"] = len(d.get("students", []))
                return d
            result = await _run(_read)
            if result is not None:
                await self._cache_set(cache_key, result)
            return result
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
            await self._cache_delete_prefix(f"room:{room_id}")
            await self._cache_delete_prefix(f"room_students:{room_id}")
            await self._cache_delete_prefix(f"student_rooms:{user_id}")
            await self._cache_delete_prefix(f"room_catalog:{user_id}")
        except Exception as e:
            logger.warning(f"[Firebase] add_student_to_room 실패: {e}")

    async def create_room_application(self, room_id: str, user_id: str, note: str = "") -> dict:
        db = self._safe_db()
        if db is None:
            return {
                "application_id": f"{room_id}_{user_id}",
                "room_id": room_id,
                "user_id": user_id,
                "status": "pending",
                "note": note,
            }
        try:
            room = await self.get_room(room_id)
            if not room:
                raise ValueError("room_not_found")
            if user_id in (room.get("students") or []):
                return {
                    "application_id": f"{room_id}_{user_id}",
                    "room_id": room_id,
                    "user_id": user_id,
                    "status": "approved",
                }

            user = await self.get_user(user_id) or {}

            def _write():
                doc_id = f"{room_id}_{user_id}"
                ref = db.collection("room_applications").document(doc_id)
                now = datetime.now(timezone.utc)
                current = ref.get()
                existing = current.to_dict() if current.exists else {}
                data = {
                    "application_id": doc_id,
                    "room_id": room_id,
                    "user_id": user_id,
                    "student_name": user.get("name", user_id),
                    "professor_uid": room.get("professor_uid", ""),
                    "room_subject": room.get("subject", ""),
                    "room_type": room.get("room_type", "offline"),
                    "status": "pending",
                    "note": note,
                    "review_note": "",
                    "created_at": existing.get("created_at", now),
                    "updated_at": now,
                }
                ref.set(data, merge=True)
                data["created_at"] = _normalize_firestore_value(data["created_at"])
                data["updated_at"] = now.isoformat()
                return data

            result = await _run(_write)
            await self._cache_delete_prefix(f"student_hub:{user_id}")
            await self._cache_delete_prefix(f"student_applications:{user_id}")
            await self._cache_delete_prefix(f"room_applications:{room_id}")
            await self._cache_delete_prefix(f"room_catalog:{user_id}")
            return result
        except Exception as e:
            logger.warning(f"[Firebase] create_room_application 실패: {e}")
            raise

    async def get_student_applications(self, user_id: str) -> list[dict]:
        cache_key = f"student_applications:{user_id}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached
        db = self._safe_db()
        if db is None:
            return []
        try:
            def _read():
                docs = list(
                    db.collection("room_applications")
                    .where("user_id", "==", user_id)
                    .stream()
                )
                result = []
                for doc in docs:
                    data = _normalize_firestore_value(doc.to_dict())
                    result.append(data)
                result.sort(key=lambda item: item.get("updated_at") or "", reverse=True)
                return result
            result = await _run(_read)
            await self._cache_set(cache_key, result)
            return result
        except Exception as e:
            logger.warning(f"[Firebase] get_student_applications 실패: {e}")
            return []

    async def get_room_applications(self, room_id: str, status: str | None = None) -> list[dict]:
        cache_key = f"room_applications:{room_id}:{status or 'all'}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached
        db = self._safe_db()
        if db is None:
            return []
        try:
            def _read():
                docs = list(
                    db.collection("room_applications")
                    .where("room_id", "==", room_id)
                    .stream()
                )
                result = []
                for doc in docs:
                    data = _normalize_firestore_value(doc.to_dict())
                    if status and data.get("status") != status:
                        continue
                    result.append(data)
                result.sort(key=lambda item: item.get("updated_at") or "", reverse=True)
                return result
            result = await _run(_read)
            await self._cache_set(cache_key, result)
            return result
        except Exception as e:
            logger.warning(f"[Firebase] get_room_applications 실패: {e}")
            return []

    async def review_room_application(
        self,
        room_id: str,
        user_id: str,
        status: str,
        note: str = "",
    ) -> dict:
        db = self._safe_db()
        if db is None:
            return {
                "application_id": f"{room_id}_{user_id}",
                "room_id": room_id,
                "user_id": user_id,
                "status": status,
            }
        try:
            def _write():
                doc_id = f"{room_id}_{user_id}"
                ref = db.collection("room_applications").document(doc_id)
                snap = ref.get()
                if not snap.exists:
                    raise ValueError("application_not_found")
                now = datetime.now(timezone.utc)
                ref.set(
                    {
                        "status": status,
                        "review_note": note,
                        "updated_at": now,
                    },
                    merge=True,
                )
                data = snap.to_dict() or {}
                data.update({
                    "status": status,
                    "review_note": note,
                    "updated_at": now.isoformat(),
                })
                data["created_at"] = _normalize_firestore_value(data.get("created_at"))
                return data

            result = await _run(_write)
            if status == "approved":
                await self.add_student_to_room(room_id, user_id)
            await self._cache_delete_prefix(f"student_hub:{user_id}")
            await self._cache_delete_prefix(f"student_applications:{user_id}")
            await self._cache_delete_prefix(f"room_applications:{room_id}")
            await self._cache_delete_prefix(f"room:{room_id}")
            await self._cache_delete_prefix(f"room_catalog:{user_id}")
            return result
        except Exception as e:
            logger.warning(f"[Firebase] review_room_application 실패: {e}")
            raise

    async def get_room_catalog(self, user_id: str) -> list[dict]:
        cache_key = f"room_catalog:{user_id}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached
        db = self._safe_db()
        if db is None:
            return []
        try:
            applications = await self.get_student_applications(user_id)
            application_map = {
                item.get("room_id"): item.get("status")
                for item in applications
            }

            def _read():
                docs = list(
                    db.collection("rooms")
                    .order_by("created_at", direction="DESCENDING")
                    .stream()
                )
                result = []
                for doc in docs:
                    data = _normalize_firestore_value(doc.to_dict())
                    if user_id in (data.get("students") or []):
                        continue
                    result.append({
                        **data,
                        "student_count": len(data.get("students", [])),
                        "application_status": application_map.get(data.get("room_id")),
                    })
                return result

            result = await _run(_read)
            await self._cache_set(cache_key, result)
            return result
        except Exception as e:
            logger.warning(f"[Firebase] get_room_catalog 실패: {e}")
            return []

    async def delete_room(self, room_id: str) -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            await _run(lambda: db.collection("rooms").document(room_id).delete())
            await self._cache_delete_prefix(f"room:{room_id}")
            await self._cache_delete_prefix(f"room_students:{room_id}")
            await self._cache_delete_prefix(f"room_lectures:{room_id}")
            await self._cache_delete_prefix(f"room_quiz:{room_id}")
            await self._cache_delete_prefix("room_catalog:")
        except Exception as e:
            logger.warning(f"[Firebase] delete_room 실패: {e}")

    async def get_room_students(self, room_id: str) -> list[dict]:
        cache_key = f"room_students:{room_id}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached
        db = self._safe_db()
        if db is None:
            return []
        try:
            def _read():
                doc = db.collection("rooms").document(room_id).get()
                if not doc.exists:
                    return []
                student_ids = doc.to_dict().get("students", [])
                if not student_ids:
                    return []

                refs = [db.collection("users").document(uid) for uid in student_ids]
                docs = list(db.get_all(refs))
                user_map = {
                    doc.id: doc.to_dict()
                    for doc in docs
                    if doc.exists
                }

                result = []
                for uid in student_ids:
                    u = user_map.get(uid, {})
                    profile = u.get("learning_profile", {}) or {}
                    result.append({
                        "user_id": uid,
                        "name": u.get("name", uid),
                        "primary_style": profile.get("learning_style"),
                        "social_type": profile.get("interaction"),
                        "cognitive_type": profile.get("cognitive_style"),
                    })
                return result
            result = await _run(_read)
            await self._cache_set(cache_key, result)
            return result
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
            await self._cache_delete_prefix("room_students:")
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
        self, room_id: str, title: str, original_text: str, core_points: list,
        week_number: int = 0,
        lecture_id: str = "",
        order_index: int = 0,
        video_url: str = "",
        video_type: str = "none",
        video_title: str = "",
        video_status: str = "none",
        video_source: str = "none",
        material_url: str = "",
    ) -> str:
        db = self._safe_db()
        if db is None:
            return "offline-lecture"
        try:
            def _write():
                ref = (
                    db.collection("rooms").document(room_id)
                    .collection("lectures").document(lecture_id)
                    if lecture_id
                    else db.collection("rooms").document(room_id)
                    .collection("lectures").document()
                )
                payload = {
                    "lecture_id": ref.id,
                    "room_id": room_id,
                    "title": title,
                    "week_number": week_number,
                    "order_index": order_index,
                    "original_text": original_text,
                    "core_points": core_points,
                    "confirmed": False,
                    "video_url": video_url,
                    "video_type": video_type,
                    "video_title": video_title,
                    "video_status": video_status,
                    "video_source": video_source,
                    "video_asset_url": "",
                    "video_duration": 0,
                    "video_transcript": "",
                    "video_segments": [],
                    "video_summary": "",
                    "video_key_moments": [],
                    "transcription_status": "idle",
                    "transcription_error": "",
                    "chapters": [],
                    "summary_status": "idle",
                    "summary_cache": {},
                    "material_url": material_url,
                    "is_placeholder": False,
                    "created_at": datetime.now(timezone.utc),
                    "updated_at": datetime.now(timezone.utc),
                }
                ref.set(payload, merge=True)
                return ref.id
            lecture_id = await _run(_write)
            await self._cache_delete_prefix(f"room_lectures:{room_id}")
            return lecture_id
        except Exception as e:
            logger.error(f"[Firebase] save_lecture 실패: {e}")
            return "offline-lecture"

    async def create_lecture_shells(self, room_id: str, lectures: list[dict]) -> list[dict]:
        db = self._safe_db()
        if db is None:
            return []
        try:
            def _write():
                room_ref = db.collection("rooms").document(room_id).collection("lectures")
                created = []
                now = datetime.now(timezone.utc)
                for index, lecture in enumerate(lectures, start=1):
                    ref = room_ref.document()
                    data = {
                        "lecture_id": ref.id,
                        "room_id": room_id,
                        "title": lecture.get("title", "").strip() or f"강의 {index}",
                        "week_number": 0,
                        "order_index": lecture.get("order", index),
                        "video_url": lecture.get("video_url", ""),
                        "video_type": lecture.get("video_type") or ("youtube" if lecture.get("video_url") else "none"),
                        "video_title": lecture.get("video_title", ""),
                        "video_status": "ready" if lecture.get("video_url") else "none",
                        "video_source": "youtube" if lecture.get("video_url") else "none",
                        "video_asset_url": "",
                        "video_duration": 0,
                        "video_transcript": "",
                        "video_segments": [],
                        "video_summary": "",
                        "video_key_moments": [],
                        "transcription_status": "idle",
                        "transcription_error": "",
                        "chapters": [],
                        "summary_status": "idle",
                        "summary_cache": {},
                        "material_url": lecture.get("material_url", ""),
                        "original_text": "",
                        "core_points": [],
                        "confirmed": False,
                        "is_placeholder": True,
                        "created_at": now,
                        "updated_at": now,
                    }
                    ref.set(data)
                    created.append({**data, "created_at": now.isoformat(), "updated_at": now.isoformat()})
                return created
            result = await _run(_write)
            await self._cache_delete_prefix(f"room_lectures:{room_id}")
            return result
        except Exception as e:
            logger.warning(f"[Firebase] create_lecture_shells 실패: {e}")
            return []

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
                return _normalize_firestore_value(doc.to_dict()) if doc.exists else None
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
            await self._cache_delete_prefix(f"room_lectures:{room_id}")
        except Exception as e:
            logger.warning(f"[Firebase] confirm_core_points 실패: {e}")

    async def get_lectures_in_room(self, room_id: str) -> list[dict]:
        cache_key = f"room_lectures:{room_id}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached
        db = self._safe_db()
        if db is None:
            return []
        try:
            def _read():
                docs = (
                    db.collection("rooms").document(room_id)
                    .collection("lectures")
                    .order_by("order_index")
                    .stream()
                )
                result = []
                for doc in docs:
                    data = doc.to_dict()
                    for key in ("created_at", "updated_at"):
                        value = data.get(key)
                        if value is not None and hasattr(value, "isoformat"):
                            data[key] = value.isoformat()
                    result.append(data)
                return result
            result = await _run(_read)
            await self._cache_set(cache_key, result)
            return result
        except Exception as e:
            logger.warning(f"[Firebase] get_lectures_in_room 실패: {e}")
            return []

    async def update_lecture_meta(self, room_id: str, lecture_id: str, data: dict) -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            payload = {
                **data,
                "updated_at": datetime.now(timezone.utc),
            }
            await _run(
                lambda: db.collection("rooms").document(room_id)
                .collection("lectures").document(lecture_id)
                .set(payload, merge=True)
            )
            await self._cache_delete_prefix(f"room_lectures:{room_id}")
        except Exception as e:
            logger.warning(f"[Firebase] update_lecture_meta 실패: {e}")

    async def reorder_lectures(self, room_id: str, items: list[dict]) -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            def _write():
                batch = db.batch()
                now = datetime.now(timezone.utc)
                for item in items:
                    ref = db.collection("rooms").document(room_id).collection("lectures").document(item["lecture_id"])
                    batch.update(ref, {
                        "order_index": item["order_index"],
                        "updated_at": now,
                    })
                batch.commit()
            await _run(_write)
            await self._cache_delete_prefix(f"room_lectures:{room_id}")
        except Exception as e:
            logger.warning(f"[Firebase] reorder_lectures 실패: {e}")

    async def delete_lecture(self, room_id: str, lecture_id: str) -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            await _run(
                lambda: db.collection("rooms").document(room_id)
                .collection("lectures").document(lecture_id).delete()
            )
            await self._cache_delete_prefix(f"room_lectures:{room_id}")
        except Exception as e:
            logger.warning(f"[Firebase] delete_lecture 실패: {e}")

    async def save_reforged_all(
        self,
        room_id: str,
        lecture_id: str,
        user_id: str,
        styles: dict[str, str],
        primary_style: str,
        subject_level: str = "",
        cache_version: int = 1,
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
                        "subject_level": subject_level,
                        "cache_version": cache_version,
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
                    "subject_level": d.get("subject_level", ""),
                    "cache_version": d.get("cache_version", 1),
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

    # ── 강의실 메타 업데이트 ───────────────────────────────────────

    async def update_room_meta(self, room_id: str, meta: dict) -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            await _run(lambda: db.collection("rooms").document(room_id).update(meta))
            await self._cache_delete_prefix(f"room:{room_id}")
            await self._cache_delete_prefix("professor_rooms:")
            await self._cache_delete_prefix("student_rooms:")
        except Exception as e:
            logger.warning(f"[Firebase] update_room_meta 실패: {e}")

    async def save_room_quiz(self, room_id: str, questions: list) -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            def _write():
                db.collection("rooms").document(room_id).update(
                    {"subject_quiz": questions, "has_quiz": True}
                )
            await _run(_write)
            await self._cache_delete_prefix(f"room_quiz:{room_id}")
            await self._cache_delete_prefix(f"room:{room_id}")
            await self._cache_delete_prefix("professor_rooms:")
            await self._cache_delete_prefix("student_rooms:")
        except Exception as e:
            logger.warning(f"[Firebase] save_room_quiz 실패: {e}")

    async def get_room_quiz(self, room_id: str) -> list:
        cache_key = f"room_quiz:{room_id}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached
        db = self._safe_db()
        if db is None:
            return []
        try:
            def _read():
                doc = db.collection("rooms").document(room_id).get()
                return doc.to_dict().get("subject_quiz", []) if doc.exists else []
            result = await _run(_read)
            await self._cache_set(cache_key, result)
            return result
        except Exception as e:
            logger.warning(f"[Firebase] get_room_quiz 실패: {e}")
            return []

    # ── 수준판단 결과 ──────────────────────────────────────────────

    async def save_subject_level(
        self, user_id: str, room_id: str, score: int, level: str,
        correct: int, total: int
    ) -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            def _write():
                db.collection("subject_levels").document(f"{user_id}_{room_id}").set({
                    "user_id": user_id, "room_id": room_id,
                    "score": score, "subject_level": level,
                    "correct_count": correct, "total_count": total,
                    "submitted_at": datetime.now(timezone.utc),
                })
            await _run(_write)
            await self._cache_delete_prefix(f"subject_level:{user_id}:{room_id}")
        except Exception as e:
            logger.warning(f"[Firebase] save_subject_level 실패: {e}")

    async def get_subject_level(self, user_id: str, room_id: str) -> Optional[dict]:
        cache_key = f"subject_level:{user_id}:{room_id}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached
        db = self._safe_db()
        if db is None:
            return None
        try:
            def _read():
                doc = db.collection("subject_levels").document(f"{user_id}_{room_id}").get()
                return doc.to_dict() if doc.exists else None
            result = await _run(_read)
            if result is not None:
                await self._cache_set(cache_key, result)
            return result
        except Exception as e:
            logger.warning(f"[Firebase] get_subject_level 실패: {e}")
            return None

    # ── 공지사항 ───────────────────────────────────────────────────

    async def save_notice(
        self, room_id: str, content: str, professor_uid: str, title: str = ""
    ) -> str:
        db = self._safe_db()
        if db is None:
            return "offline"
        try:
            def _write():
                ref = db.collection("rooms").document(room_id).collection("notices").document()
                ref.set({
                    "notice_id": ref.id, "room_id": room_id,
                    "title": title, "content": content,
                    "professor_uid": professor_uid,
                    "created_at": datetime.now(timezone.utc),
                })
                return ref.id
            notice_id = await _run(_write)
            await self._cache_delete_prefix(f"room_notices:{room_id}")
            return notice_id
        except Exception as e:
            logger.warning(f"[Firebase] save_notice 실패: {e}")
            return "offline"

    async def get_notices(self, room_id: str) -> list:
        cache_key = f"room_notices:{room_id}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached
        db = self._safe_db()
        if db is None:
            return []
        try:
            def _read():
                docs = (
                    db.collection("rooms").document(room_id)
                    .collection("notices")
                    .order_by("created_at", direction="DESCENDING")
                    .limit(30)
                    .stream()
                )
                return [_normalize_firestore_value(doc.to_dict()) for doc in docs]
            result = await _run(_read)
            await self._cache_set(cache_key, result)
            return result
        except Exception as e:
            logger.warning(f"[Firebase] get_notices 실패: {e}")
            return []

    async def delete_notice(self, room_id: str, notice_id: str) -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            await _run(
                lambda: db.collection("rooms").document(room_id)
                .collection("notices").document(notice_id).delete()
            )
            await self._cache_delete_prefix(f"room_notices:{room_id}")
        except Exception as e:
            logger.warning(f"[Firebase] delete_notice 실패: {e}")

    # ── 원본 파일 URL 저장 ─────────────────────────────────────────

    async def save_original_file_url(
        self, room_id: str, lecture_id: str, url: str, filename: str
    ) -> None:
        db = self._safe_db()
        if db is None:
            return
        try:
            def _write():
                db.collection("rooms").document(room_id)\
                    .collection("lectures").document(lecture_id)\
                    .update({"original_file_url": url, "original_filename": filename})
            await _run(_write)
            await self._cache_delete_prefix(f"room_lectures:{room_id}")
        except Exception as e:
            logger.warning(f"[Firebase] save_original_file_url 실패: {e}")

    async def get_lecture_original_url(self, room_id: str, lecture_id: str) -> Optional[str]:
        data = await self.get_lecture(room_id, lecture_id)
        return data.get("original_file_url") if data else None

    # ── 원본 파일 Storage 업로드 ────────────────────────────────────

    async def upload_original_file(
        self, room_id: str, lecture_id: str, file_bytes: bytes, filename: str, content_type: str
    ) -> Optional[str]:
        db = self._safe_db()
        bucket_name = os.getenv("FIREBASE_STORAGE_BUCKET")
        if db is None or not bucket_name:
            return None
            
        try:
            from firebase_admin import storage
            import uuid
            
            def _upload():
                bucket = storage.bucket()
                unique_name = f"rooms/{room_id}/lectures/{lecture_id}/{uuid.uuid4().hex}_{filename}"
                blob = bucket.blob(unique_name)
                
                # 메타데이터를 설정하여 브라우저에서 바로 열리지 않고 다운로드되도록 함
                blob.upload_from_string(
                    file_bytes, 
                    content_type=content_type
                )
                
                # 공개 URL 생성 보다는 서명된 URL 또는 만료 기한 없는 토큰 방식 사용
                # MVP에서는 단순 공개 토큰 만들어서 URL 리턴
                blob.make_public()
                return blob.public_url

            url = await _run(_upload)
            
            # Firestore에 url 저장
            await self.save_original_file_url(room_id, lecture_id, url, filename)
            return url
        except Exception as e:
            logger.warning(f"[Firebase] upload_original_file 실패: {e}")
            return None

    async def upload_lecture_asset(
        self,
        room_id: str,
        lecture_id: str,
        file_bytes: bytes,
        filename: str,
        content_type: str,
        kind: str,
    ) -> Optional[str]:
        db = self._safe_db()
        bucket_name = os.getenv("FIREBASE_STORAGE_BUCKET")
        if db is None or not bucket_name:
            return None

        try:
            from firebase_admin import storage
            import uuid

            def _upload():
                bucket = storage.bucket()
                unique_name = (
                    f"rooms/{room_id}/lectures/{lecture_id}/{kind}/"
                    f"{uuid.uuid4().hex}_{filename}"
                )
                blob = bucket.blob(unique_name)
                blob.upload_from_string(file_bytes, content_type=content_type)
                blob.make_public()
                return blob.public_url

            url = await _run(_upload)

            field_name = "video_asset_url" if kind == "video" else "material_url"

            def _write():
                payload = {
                    field_name: url,
                    f"{kind}_filename": filename,
                    "updated_at": datetime.now(timezone.utc),
                }
                if kind == "video":
                    payload.update({
                        "video_url": url,
                        "video_type": "upload",
                        "video_source": "uploaded_file",
                        "video_status": "ready",
                    })
                db.collection("rooms").document(room_id) \
                    .collection("lectures").document(lecture_id) \
                    .set(payload, merge=True)

            await _run(_write)
            await self._cache_delete_prefix(f"room_lectures:{room_id}")
            return url
        except Exception as e:
            logger.warning(f"[Firebase] upload_lecture_asset 실패 ({kind}): {e}")
            return None
