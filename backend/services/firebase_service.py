"""
Firebase Firestore 서비스 — 사용자, 방, 진단, 교안 데이터 관리
"""
import json
import os
import secrets
import string
from datetime import datetime, timezone
from typing import Optional

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
    cred = credentials.Certificate(json.loads(cred_json))
    firebase_admin.initialize_app(cred)
    _initialized = True


def _generate_room_code() -> str:
    chars = string.ascii_uppercase + string.digits
    return "".join(secrets.choice(chars) for _ in range(6))


class FirebaseService:
    def __init__(self):
        _init_firebase()
        self.db = firestore.client()

    # ── 사용자 ────────────────────────────────────────────────────

    async def save_user(self, user_id: str, name: str, role: str, email: str = "") -> None:
        self.db.collection("users").document(user_id).set(
            {"name": name, "role": role, "email": email, "created_at": datetime.now(timezone.utc)},
            merge=True,
        )

    async def get_user(self, user_id: str) -> Optional[dict]:
        doc = self.db.collection("users").document(user_id).get()
        return doc.to_dict() if doc.exists else None

    # ── 방 ────────────────────────────────────────────────────────

    async def create_room(self, professor_uid: str, professor_name: str, subject: str, description: str) -> dict:
        code = _generate_room_code()
        room_ref = self.db.collection("rooms").document()
        data = {
            "room_id": room_ref.id,
            "room_code": code,
            "professor_uid": professor_uid,
            "professor_name": professor_name,
            "subject": subject,
            "description": description,
            "students": [],
            "created_at": datetime.now(timezone.utc),
        }
        room_ref.set(data)
        return data

    async def get_rooms_by_professor(self, professor_uid: str) -> list[dict]:
        docs = (
            self.db.collection("rooms")
            .where("professor_uid", "==", professor_uid)
            .stream()
        )
        rooms = []
        for doc in docs:
            d = doc.to_dict()
            d["student_count"] = len(d.get("students", []))
            rooms.append(d)
        return rooms

    async def get_room_by_code(self, code: str) -> Optional[dict]:
        docs = list(
            self.db.collection("rooms")
            .where("room_code", "==", code.upper())
            .limit(1)
            .stream()
        )
        return docs[0].to_dict() if docs else None

    async def get_room(self, room_id: str) -> Optional[dict]:
        doc = self.db.collection("rooms").document(room_id).get()
        if not doc.exists:
            return None
        d = doc.to_dict()
        d["student_count"] = len(d.get("students", []))
        return d

    async def add_student_to_room(self, room_id: str, user_id: str) -> None:
        ref = self.db.collection("rooms").document(room_id)
        ref.update({"students": firestore.ArrayUnion([user_id])})

    async def delete_room(self, room_id: str) -> None:
        self.db.collection("rooms").document(room_id).delete()

    async def get_room_students(self, room_id: str) -> list[dict]:
        doc = self.db.collection("rooms").document(room_id).get()
        if not doc.exists:
            return []
        student_ids = doc.to_dict().get("students", [])
        result = []
        for uid in student_ids:
            user_doc = self.db.collection("users").document(uid).get()
            if user_doc.exists:
                u = user_doc.to_dict()
                diag_doc = self.db.collection("diagnosis").document(uid).get()
                profile = {}
                if diag_doc.exists:
                    profile = diag_doc.to_dict().get("profile", {})
                result.append({
                    "user_id": uid,
                    "name": u.get("name", uid),
                    "primary_style": profile.get("primary_style"),
                    "social_type": profile.get("social_type"),
                    "cognitive_type": profile.get("cognitive_type"),
                })
        return result

    # ── 진단 ──────────────────────────────────────────────────────

    async def save_diagnosis(self, user_id: str, profile: dict, report: dict) -> None:
        self.db.collection("diagnosis").document(user_id).set(
            {"profile": profile, "report": report, "diagnosed_at": datetime.now(timezone.utc)},
            merge=True,
        )
        self.db.collection("users").document(user_id).set(
            {"learning_profile": profile}, merge=True
        )

    async def get_diagnosis(self, user_id: str) -> Optional[dict]:
        doc = self.db.collection("diagnosis").document(user_id).get()
        return doc.to_dict() if doc.exists else None

    # ── 교안 ──────────────────────────────────────────────────────

    async def save_lecture(self, room_id: str, title: str, original_text: str, core_points: list) -> str:
        ref = self.db.collection("rooms").document(room_id).collection("lectures").document()
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

    async def get_lecture(self, room_id: str, lecture_id: str) -> Optional[dict]:
        doc = (
            self.db.collection("rooms").document(room_id)
            .collection("lectures").document(lecture_id)
            .get()
        )
        return doc.to_dict() if doc.exists else None

    async def confirm_core_points(self, room_id: str, lecture_id: str, core_points: list) -> None:
        self.db.collection("rooms").document(room_id).collection("lectures").document(lecture_id).update(
            {"core_points": core_points, "confirmed": True}
        )

    async def get_lectures_in_room(self, room_id: str) -> list[dict]:
        docs = (
            self.db.collection("rooms").document(room_id)
            .collection("lectures")
            .stream()
        )
        return [doc.to_dict() for doc in docs]

    async def save_reforged(self, room_id: str, lecture_id: str, user_id: str, content: str, style: str) -> None:
        self.db.collection("rooms").document(room_id)\
            .collection("lectures").document(lecture_id)\
            .collection("reforged").document(user_id)\
            .set({"content": content, "style": style, "generated_at": datetime.now(timezone.utc)})

    async def get_reforged(self, room_id: str, lecture_id: str, user_id: str) -> Optional[dict]:
        doc = (
            self.db.collection("rooms").document(room_id)
            .collection("lectures").document(lecture_id)
            .collection("reforged").document(user_id)
            .get()
        )
        return doc.to_dict() if doc.exists else None
