"""외부 API 없이 도는 스모크 테스트 — 데모 체험 핵심 경로 검증"""
from fastapi.testclient import TestClient

import main
from services.reforge_service import _clean_markdown


def _client() -> TestClient:
    return TestClient(main.app)


def test_health_and_demo_catalog():
    with _client() as c:
        health = c.get("/api/v1/health").json()
        assert health["status"] == "ok"
        assert health["storage"] == "memory"
        courses = c.get("/api/v1/courses").json()["courses"]
        demo = [x for x in courses if x.get("is_demo")]
        assert len(demo) >= 2
        assert all(x["lecture_count"] > 0 for x in demo)


def test_student_bootstrap_quick_diagnosis_and_hub():
    with _client() as c:
        boot = c.post("/api/v1/demo/bootstrap", json={"role": "student"}).json()
        uid = boot["user_id"]
        assert uid.startswith("demo-student-")

        diag = c.post("/api/v1/diagnosis/quick", json={
            "user_id": uid,
            "answers": {"q1": "A", "q2": "A", "q3": "D", "q4": "B", "q5": "C", "q6": "B"},
        })
        assert diag.status_code == 200
        assert diag.json()["profile"]["learning_style"] == "시각형"

        hub = c.get(f"/api/v1/rooms/student/{uid}/hub").json()
        assert {r["room_id"] for r in hub["enrolled_rooms"]} >= {"demo-ml-101", "demo-web-101"}

        # 같은 ID로 재방문하면 같은 계정을 이어서 사용
        again = c.post("/api/v1/demo/bootstrap", json={"role": "student", "user_id": uid}).json()
        assert again["user_id"] == uid


def test_professor_bootstrap_creates_private_room_hidden_from_catalog():
    with _client() as c:
        boot = c.post("/api/v1/demo/bootstrap", json={"role": "professor"}).json()
        room_id = boot["room_id"]
        rooms = c.get(f"/api/v1/rooms/professor/{boot['user_id']}").json()
        assert [r["room_id"] for r in rooms] == [room_id]
        students = c.get(f"/api/v1/rooms/{room_id}/students").json()
        assert len(students) == 8 and all(s["primary_style"] for s in students)
        catalog_ids = {x["id"] for x in c.get("/api/v1/courses").json()["courses"]}
        assert room_id not in catalog_ids


def test_markdown_cleaner_keeps_code_and_lines():
    text = "**가중치** | **목표**\n\n**선형회귀** $x^2$\n\n```bash\necho $HOME\n```"
    out = _clean_markdown(text)
    assert "**가중치** | **목표**\n\n**선형회귀**" in out
    assert "`x^2`" in out
    assert "echo $HOME" in out
