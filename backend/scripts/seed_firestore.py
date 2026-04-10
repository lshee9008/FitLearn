"""
Firestore 임시 데이터 시드 스크립트
Usage:
  cd backend
  python scripts/seed_firestore.py [--env development|production]

필요 환경변수 (backend/.env.development 또는 FIREBASE_CREDENTIALS):
  FIREBASE_CREDENTIALS  - Firebase 서비스 계정 JSON 문자열
  FIREBASE_PROJECT_ID   - Firebase 프로젝트 ID
"""
import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

# ── 경로 설정 (backend/ 를 sys.path에 추가) ──────────────────────────────
BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))


def _load_env(env: str) -> None:
    """backend/.env.{env} 파일에서 환경변수 로드"""
    env_file = BACKEND_DIR / f".env.{env}"
    if not env_file.exists():
        print(f"[seed] .env.{env} 파일 없음 → 시스템 환경변수 사용")
        return
    with open(env_file, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            os.environ.setdefault(key.strip(), val.strip())
    print(f"[seed] 환경변수 로드 완료: {env_file}")


def _init_firebase() -> object:
    """Firebase Admin SDK 초기화 후 Firestore 클라이언트 반환"""
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore

        if firebase_admin._apps:
            return firestore.client()

        cred_json = os.getenv("FIREBASE_CREDENTIALS")
        if not cred_json:
            print("[seed] ERROR: FIREBASE_CREDENTIALS 환경변수가 없습니다.")
            print("  → backend/.env.development 파일에 FIREBASE_CREDENTIALS='{...}' 를 설정하세요.")
            sys.exit(1)

        cred = credentials.Certificate(json.loads(cred_json))
        firebase_admin.initialize_app(cred)
        db = firestore.client()
        print("[seed] Firebase 초기화 완료")
        return db
    except ImportError:
        print("[seed] ERROR: firebase-admin 패키지가 설치되지 않았습니다.")
        print("  → pip install firebase-admin")
        sys.exit(1)
    except Exception as e:
        print(f"[seed] Firebase 초기화 실패: {e}")
        sys.exit(1)


# ── 시드 데이터 정의 ─────────────────────────────────────────────────────────

NOW = datetime.now(timezone.utc)

USERS = [
    {
        "id": "prof-001",
        "data": {
            "userId": "prof-001",
            "name": "김교수",
            "email": "professor@test.com",
            "role": "professor",
            "department": "컴퓨터공학과",
            "bio": "딥러닝 전문가, 10년 강의 경력",
            "createdAt": NOW,
        },
    },
    {
        "id": "student-001",
        "data": {
            "userId": "student-001",
            "name": "이학생",
            "email": "student1@test.com",
            "role": "student",
            "createdAt": NOW,
            "learningProfile": {
                "vark": "시각형",
                "focusPattern": "단기집중",
                "difficultyResponse": "직진형",
                "dropoutRisk": "동기",
                "confidenceScore": 78,
            },
            "joinedRooms": ["room-001"],
            "subjectLevels": {"room-001": "intermediate"},
        },
    },
    {
        "id": "student-002",
        "data": {
            "userId": "student-002",
            "name": "박학생",
            "email": "student2@test.com",
            "role": "student",
            "createdAt": NOW,
            "learningProfile": {
                "vark": "청각형",
                "focusPattern": "장기몰입",
                "difficultyResponse": "우회형",
                "dropoutRisk": "고립",
                "confidenceScore": 85,
            },
            "joinedRooms": ["room-001"],
            "subjectLevels": {"room-001": "beginner"},
        },
    },
]

# diagnosis 컬렉션: reforge_service._TEST_PROFILES 형식과 호환
DIAGNOSES = [
    {
        "id": "student-001",
        "data": {
            "profile": {
                "learning_style": "시각형",
                "cognitive_style": "직관형",
                "focus_pattern": "단기집중형",
                "pace": "속도형",
                "preferred_format": "시각적 다이어그램",
                "kolb_type": "수렴형",
                "confidence_score": 78,
                # 5차원 확장 필드
                "difficulty_response": "직진형",
                "dropout_risk": ["동기"],
                "interaction": "독립형",
                "scores": {
                    "focus_depth": 55,
                    "speed": 70,
                    "collaboration": 40,
                    "consistency": 45,
                },
            },
            "report": {
                "summary": "시각적 자료와 다이어그램을 선호하는 단기집중형 학습자입니다.",
                "strengths": ["빠른 이해력", "시각적 정보 처리"],
                "weaknesses": ["장시간 집중 어려움", "동기 유지 필요"],
                "recommended_style": "시각적 요약 + 체크포인트 구성",
            },
            "diagnosed_at": NOW,
        },
    },
    {
        "id": "student-002",
        "data": {
            "profile": {
                "learning_style": "청각형",
                "cognitive_style": "직관형",
                "focus_pattern": "장기몰입형",
                "pace": "숙고형",
                "preferred_format": "대화체 설명",
                "kolb_type": "발산형",
                "confidence_score": 85,
                # 5차원 확장 필드
                "difficulty_response": "우회형",
                "dropout_risk": ["고립"],
                "interaction": "독립형",
                "scores": {
                    "focus_depth": 80,
                    "speed": 40,
                    "collaboration": 28,
                    "consistency": 70,
                },
            },
            "report": {
                "summary": "대화체 설명을 선호하는 장기몰입형 학습자입니다.",
                "strengths": ["깊은 이해", "높은 신뢰도"],
                "weaknesses": ["고립 위험", "협력 부족"],
                "recommended_style": "스토리텔링 + 단계별 심화",
            },
            "diagnosed_at": NOW,
        },
    },
]

ROOM = {
    "id": "room-001",
    "data": {
        "room_id": "room-001",
        "room_code": "DL2024",
        "professor_uid": "prof-001",
        "professor_name": "김교수",
        "subject": "딥러닝 기초",
        "description": "딥러닝의 기본 개념부터 실습까지",
        "room_type": "online",
        "synopsis": "1주차: 신경망 기초\n2주차: CNN\n3주차: RNN\n4주차: GAN",
        "core_concepts": ["역전파", "경사하강법", "활성화함수"],
        "youtube_url": "",
        "has_quiz": False,
        "students": ["student-001", "student-002"],
        "created_at": NOW,
    },
}

LECTURE = {
    "id": "lecture-001",
    "data": {
        "lecture_id": "lecture-001",
        "room_id": "room-001",
        "title": "1주차: 신경망 기초",
        "week_number": 1,
        "original_text": (
            "# 신경망 기초\n\n"
            "## 1. 퍼셉트론\n"
            "퍼셉트론은 인공 뉴런의 가장 기본적인 형태입니다.\n"
            "입력값에 가중치를 곱하고 편향을 더한 후 활성화 함수를 적용합니다.\n\n"
            "## 2. 활성화 함수\n"
            "- Sigmoid: σ(x) = 1 / (1 + e^(-x))\n"
            "- ReLU: f(x) = max(0, x)\n"
            "- Tanh: f(x) = (e^x - e^(-x)) / (e^x + e^(-x))\n\n"
            "## 3. 역전파 (Backpropagation)\n"
            "역전파는 출력 오차를 입력 방향으로 전파하며 가중치를 업데이트합니다.\n"
            "경사하강법(Gradient Descent)을 이용해 손실 함수를 최소화합니다.\n\n"
            "## 4. 경사하강법\n"
            "- 배치 경사하강법 (Batch GD)\n"
            "- 확률적 경사하강법 (SGD)\n"
            "- 미니배치 경사하강법 (Mini-batch GD)\n"
        ),
        "core_points": [
            {"id": 1, "content": "퍼셉트론의 구조와 동작 원리", "priority": 5, "topic": "퍼셉트론", "difficulty": "하"},
            {"id": 2, "content": "활성화 함수 종류와 특성 (Sigmoid, ReLU, Tanh)", "priority": 5, "topic": "활성화함수", "difficulty": "중"},
            {"id": 3, "content": "역전파 알고리즘과 가중치 업데이트 원리", "priority": 5, "topic": "역전파", "difficulty": "상"},
            {"id": 4, "content": "경사하강법 3가지 변형과 차이점", "priority": 4, "topic": "경사하강법", "difficulty": "중"},
        ],
        "confirmed": True,
        "created_at": NOW,
    },
}

SUBJECT_LEVELS = [
    {
        "id": "student-001_room-001",
        "data": {
            "user_id": "student-001",
            "room_id": "room-001",
            "score": 72,
            "subject_level": "intermediate",
            "correct_count": 4,
            "total_count": 5,
            "submitted_at": NOW,
        },
    },
    {
        "id": "student-002_room-001",
        "data": {
            "user_id": "student-002",
            "room_id": "room-001",
            "score": 40,
            "subject_level": "beginner",
            "correct_count": 2,
            "total_count": 5,
            "submitted_at": NOW,
        },
    },
]


# ── 시드 실행 ────────────────────────────────────────────────────────────────

def seed(db, force: bool = False) -> None:
    print("\n[seed] ─── Firestore 임시 데이터 주입 시작 ───")

    # 1. users
    print("\n[seed] 📁 users 컬렉션")
    for item in USERS:
        ref = db.collection("users").document(item["id"])
        if not force and ref.get().exists:
            print(f"  · {item['id']} — 이미 존재 (건너뜀, --force 로 덮어쓰기)")
            continue
        ref.set(item["data"])
        print(f"  ✓ {item['id']} ({item['data']['name']}, {item['data']['role']})")

    # 2. diagnosis
    print("\n[seed] 📁 diagnosis 컬렉션")
    for item in DIAGNOSES:
        ref = db.collection("diagnosis").document(item["id"])
        if not force and ref.get().exists:
            print(f"  · {item['id']} — 이미 존재 (건너뜀)")
            continue
        ref.set(item["data"])
        print(f"  ✓ {item['id']} (style={item['data']['profile']['learning_style']})")

    # 3. room
    print("\n[seed] 📁 rooms 컬렉션")
    room_ref = db.collection("rooms").document(ROOM["id"])
    if not force and room_ref.get().exists:
        print(f"  · {ROOM['id']} — 이미 존재 (건너뜀)")
    else:
        room_ref.set(ROOM["data"])
        print(f"  ✓ {ROOM['id']} ({ROOM['data']['subject']}, code={ROOM['data']['room_code']})")

    # 4. lecture (서브컬렉션)
    print("\n[seed] 📁 rooms/room-001/lectures 서브컬렉션")
    lec_ref = (
        db.collection("rooms").document("room-001")
        .collection("lectures").document(LECTURE["id"])
    )
    if not force and lec_ref.get().exists:
        print(f"  · {LECTURE['id']} — 이미 존재 (건너뜀)")
    else:
        lec_ref.set(LECTURE["data"])
        print(f"  ✓ {LECTURE['id']} ({LECTURE['data']['title']})")

    # 5. subject_levels
    print("\n[seed] 📁 subject_levels 컬렉션")
    for item in SUBJECT_LEVELS:
        ref = db.collection("subject_levels").document(item["id"])
        if not force and ref.get().exists:
            print(f"  · {item['id']} — 이미 존재 (건너뜀)")
            continue
        ref.set(item["data"])
        print(f"  ✓ {item['id']} (level={item['data']['subject_level']})")

    print("\n[seed] ─── 완료 ───────────────────────────────")
    print("[seed] 생성된 데이터:")
    print(f"  · users     : prof-001, student-001, student-002")
    print(f"  · diagnosis : student-001 (시각형), student-002 (청각형)")
    print(f"  · rooms     : room-001 (DL2024) — 학생 2명")
    print(f"  · lectures  : lecture-001 (1주차 신경망 기초)")
    print(f"  · subject_levels: student-001 (intermediate), student-002 (beginner)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Firestore 임시 데이터 시드")
    parser.add_argument(
        "--env", default="development", choices=["development", "production"],
        help="환경 (default: development)"
    )
    parser.add_argument(
        "--force", action="store_true",
        help="이미 존재하는 문서도 덮어쓰기"
    )
    args = parser.parse_args()

    _load_env(args.env)
    db = _init_firebase()
    seed(db, force=args.force)
