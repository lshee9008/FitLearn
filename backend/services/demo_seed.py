"""
데모 체험용 콘텐츠 시드

- 서버 시작 시 대표 데모 강의(교수 확정 핵심 포인트·퀴즈 포함)를 idempotent하게 생성
- 방문자별 데모 계정 부트스트랩
  - 학생: 대표 데모 강의에 자동 수강
  - 교수: 개인용 데모 강의실 사본 + 가상 수강생(진단 완료) 생성 → 대시보드까지 바로 체험
"""
from __future__ import annotations

import copy
import logging
from datetime import datetime, timedelta, timezone

from services.firebase_service import FirebaseService, _get_db, _run

logger = logging.getLogger(__name__)

DEMO_PROFESSOR_UID = "fitlearn-demo-professor"
DEMO_PROFESSOR_NAME = "FitLearn 데모 교수"

# ── 강의 원문 ─────────────────────────────────────────────────────────────────

_ML_L1 = """# 1강. 머신러닝의 큰 그림 — 데이터에서 규칙을 배우는 방법

## 1. 머신러닝이란?
전통적인 프로그래밍은 사람이 규칙을 직접 작성하고(입력 + 규칙 → 출력), 머신러닝은 데이터와 정답을 주면 컴퓨터가 규칙을 스스로 찾아낸다(입력 + 출력 → 규칙).
아서 사무엘(1959)은 머신러닝을 "명시적으로 프로그래밍하지 않고도 컴퓨터가 학습할 수 있는 능력을 부여하는 연구 분야"라고 정의했다.

예) 스팸 메일 필터
- 규칙 기반: "무료", "당첨"이라는 단어가 있으면 스팸 → 새로운 수법이 나오면 규칙을 계속 추가해야 함
- 머신러닝: 스팸/정상으로 표시된 메일 수만 개를 학습 → 새로운 패턴도 스스로 일반화

## 2. 학습 방식의 3가지 분류

| 구분 | 데이터 | 목표 | 대표 예시 |
|---|---|---|---|
| 지도학습 (Supervised) | 입력 + 정답(레이블) | 새 입력의 정답 예측 | 집값 예측, 스팸 분류 |
| 비지도학습 (Unsupervised) | 입력만 | 데이터 속 구조 발견 | 고객 군집화, 이상 탐지 |
| 강화학습 (Reinforcement) | 행동에 대한 보상 | 누적 보상 최대화 | 게임 AI, 로봇 제어 |

### 2-1. 지도학습: 회귀 vs 분류
- 회귀(Regression): 연속적인 숫자를 예측한다. 예) 평수·역세권 여부로 집값(억 원) 예측
- 분류(Classification): 정해진 범주 중 하나를 고른다. 예) 메일이 스팸인지 아닌지

### 2-2. 비지도학습
정답이 없는 데이터에서 비슷한 것끼리 묶거나(군집화), 차원을 줄여(차원 축소) 패턴을 찾는다.
예) 쇼핑몰 고객을 구매 패턴에 따라 "주말 대량 구매형", "평일 소액 반복형" 등으로 자동 분류

### 2-3. 강화학습
에이전트가 환경 속에서 행동하고, 그 결과로 받는 보상을 최대화하도록 정책을 학습한다. 알파고가 대표 사례다.

## 3. 머신러닝 프로젝트의 흐름
1. 문제 정의 — 무엇을 예측할 것인가? (회귀/분류/군집)
2. 데이터 수집 및 정제 — 결측치, 이상치 처리
3. 특성(Feature) 설계 — 모델이 참고할 입력 변수 선택
4. 모델 학습 — 학습 데이터로 파라미터 조정
5. 평가 — 처음 보는 테스트 데이터로 성능 측정
6. 배포 및 모니터링

[시각자료: 머신러닝 워크플로 — 데이터 수집 → 전처리 → 특성 설계 → 학습 → 평가 → 배포, 평가 결과가 나쁘면 특성 설계 단계로 되돌아가는 순환 화살표]

## 4. 핵심 용어
- 특성(Feature): 모델의 입력 변수 (예: 평수, 방 개수)
- 레이블(Label): 예측하려는 정답 (예: 집값)
- 모델(Model): 입력을 출력으로 바꾸는 함수
- 학습(Training): 데이터에 맞게 모델의 파라미터를 조정하는 과정
- 일반화(Generalization): 처음 보는 데이터에서도 잘 동작하는 능력 — 머신러닝의 진짜 목표
"""

_ML_L2 = """# 2강. 선형회귀와 경사하강법 — 모델은 어떻게 '학습'하는가

## 1. 선형회귀 모델
입력 x와 출력 y 사이의 관계를 직선으로 근사한다.

ŷ = w·x + b

- w(가중치, weight): 직선의 기울기 — x가 1 증가할 때 y가 얼마나 변하는가
- b(편향, bias): y절편
- ŷ(예측값)와 실제값 y의 차이를 최소화하는 w, b를 찾는 것이 목표

## 2. 손실 함수: 평균제곱오차(MSE)
예측이 얼마나 틀렸는지를 하나의 숫자로 나타낸다.

MSE = (1/n) · Σ (yᵢ − ŷᵢ)²

- 오차를 제곱하므로 큰 오차에 더 큰 벌점을 준다
- 항상 0 이상이며, 0에 가까울수록 좋은 모델이다

## 3. 경사하강법 (Gradient Descent)
손실 함수를 산이라고 생각하면, 가장 낮은 골짜기(최소 손실)를 찾아 내려가는 방법이다.
1. w, b를 임의의 값으로 시작한다
2. 현재 위치에서 손실이 가장 가파르게 줄어드는 방향(기울기의 반대 방향)을 계산한다
3. 학습률(learning rate)만큼 그 방향으로 이동한다
4. 손실이 더 이상 줄지 않을 때까지 2~3을 반복한다

업데이트 식:
w ← w − α · ∂MSE/∂w
b ← b − α · ∂MSE/∂b

[시각자료: U자형 손실 곡선 위에서 공이 계단식으로 굴러 내려가 최저점에 도달하는 그림. 학습률이 너무 크면 골짜기를 넘어 반대편으로 튕기고, 너무 작으면 아주 천천히 내려감]

### 학습률(α) 선택
- 너무 크면: 최저점을 지나쳐 발산할 수 있다
- 너무 작으면: 수렴이 매우 느리다
- 보통 0.1, 0.01, 0.001 등을 실험하며 고른다

## 4. 실습: NumPy로 경사하강법 직접 구현

```python
import numpy as np

# 공부 시간(x)과 시험 점수(y) 데이터
x = np.array([1, 2, 3, 4, 5], dtype=float)
y = np.array([52, 58, 65, 71, 78], dtype=float)

w, b = 0.0, 0.0
lr = 0.01        # 학습률
epochs = 2000

for epoch in range(epochs):
    y_pred = w * x + b
    error = y_pred - y
    loss = (error ** 2).mean()

    # 기울기 계산
    dw = 2 * (error * x).mean()
    db = 2 * error.mean()

    # 파라미터 업데이트
    w -= lr * dw
    b -= lr * db

    if epoch % 500 == 0:
        print(f"epoch {epoch:4d} | loss {loss:8.3f} | w {w:.3f} | b {b:.3f}")

print(f"최종 모델: 점수 = {w:.2f} × 공부시간 + {b:.2f}")
```

실행 결과(예시):
```
epoch    0 | loss 4183.600 | w 2.052 | b 0.648
epoch  500 | loss   25.471 | w 10.318 | b 31.882
epoch 1000 | loss    3.207 | w 7.995 | b 40.270
epoch 1500 | loss    0.502 | w 6.987 | b 43.909
최종 모델: 점수 = 6.55 × 공부시간 + 45.49
```

## 5. scikit-learn으로 한 줄 학습

```python
from sklearn.linear_model import LinearRegression

model = LinearRegression()
model.fit(x.reshape(-1, 1), y)
print(model.coef_[0], model.intercept_)   # 6.5, 45.3
print(model.predict([[6]]))               # 6시간 공부하면 약 84.3점
```

## 6. 정리
- 학습 = 손실 함수를 최소화하는 파라미터를 찾는 과정
- 경사하강법은 기울기의 반대 방향으로 조금씩 이동하며 최솟값을 찾는다
- 학습률은 너무 크지도, 작지도 않게 조정해야 한다
"""

_ML_L3 = """# 3강. 과적합과 교차검증 — 외운 모델 vs 이해한 모델

## 1. 과적합(Overfitting)과 과소적합(Underfitting)
- 과소적합: 모델이 너무 단순해서 학습 데이터의 패턴조차 잡지 못함 (학습 점수도 낮음)
- 과적합: 모델이 학습 데이터의 노이즈까지 외워서, 새로운 데이터에서는 성능이 떨어짐 (학습 점수만 높음)
- 적정 적합: 학습 데이터와 새로운 데이터 모두에서 비슷하게 좋은 성능

비유: 기출문제 답을 통째로 외운 학생은 기출 시험에서 100점이지만, 응용 문제가 나오면 무너진다. 이것이 과적합이다.

[시각자료: 같은 점 데이터에 대해 ① 직선(과소적합) ② 완만한 곡선(적정) ③ 모든 점을 지나는 구불구불한 곡선(과적합) 세 그래프를 나란히 비교]

## 2. 편향-분산 트레이드오프
| | 편향(Bias) | 분산(Variance) |
|---|---|---|
| 의미 | 모델의 가정이 틀려서 생기는 오차 | 데이터가 바뀔 때 예측이 흔들리는 정도 |
| 단순한 모델 | 높음 | 낮음 |
| 복잡한 모델 | 낮음 | 높음 |
모델 복잡도를 높이면 편향은 줄지만 분산이 커진다. 둘의 합이 최소인 지점을 찾아야 한다.

## 3. 데이터 분할: 학습 / 검증 / 테스트
- 학습(Train) 세트: 파라미터 학습에 사용
- 검증(Validation) 세트: 하이퍼파라미터 선택, 모델 비교에 사용
- 테스트(Test) 세트: 마지막에 단 한 번, 최종 성능 보고용
주의: 테스트 세트를 보면서 모델을 고치면 테스트 세트에 과적합된다(데이터 누수).

## 4. K-겹 교차검증 (K-Fold Cross Validation)
데이터를 K개 묶음으로 나눈 뒤, 매번 하나를 검증용으로 쓰고 나머지로 학습하는 과정을 K번 반복해 평균 점수를 낸다.
- 데이터가 적을 때도 안정적인 성능 추정이 가능하다
- 보통 K = 5 또는 10을 사용한다

[시각자료: 5개 블록으로 나뉜 데이터 막대 5줄. 각 줄마다 검증 블록(주황색)의 위치가 한 칸씩 이동]

## 5. 실습: 다항 회귀로 과적합 관찰하기

```python
import numpy as np
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import PolynomialFeatures
from sklearn.linear_model import LinearRegression
from sklearn.model_selection import cross_val_score

rng = np.random.default_rng(42)
X = np.sort(rng.uniform(0, 1, 30)).reshape(-1, 1)
y = np.sin(2 * np.pi * X).ravel() + rng.normal(0, 0.2, 30)

for degree in [1, 4, 15]:
    model = make_pipeline(PolynomialFeatures(degree), LinearRegression())
    train_score = model.fit(X, y).score(X, y)
    cv_score = cross_val_score(model, X, y, cv=5).mean()
    print(f"차수 {degree:2d} | 학습 R² {train_score:.3f} | 교차검증 R² {cv_score:.3f}")
```

실행 결과(예시):
```
차수  1 | 학습 R² 0.582 | 교차검증 R² 0.391
차수  4 | 학습 R² 0.951 | 교차검증 R² 0.904
차수 15 | 학습 R² 0.989 | 교차검증 R² -2.317
```
차수 15는 학습 점수는 가장 높지만 교차검증 점수가 음수로 무너진다 → 전형적인 과적합.

## 6. 과적합을 줄이는 방법
1. 데이터를 더 모은다
2. 모델을 단순하게 만든다 (특성 수·다항 차수 줄이기)
3. 규제(Regularization)를 건다 — Ridge(L2), Lasso(L1)
4. 조기 종료(Early Stopping) — 검증 손실이 오르기 시작하면 학습 중단
"""

_WEB_L1 = """# 1강. HTTP 요청과 응답 — 웹은 어떻게 대화하는가

## 1. 클라이언트-서버 모델
브라우저(클라이언트)가 요청(Request)을 보내면 서버가 응답(Response)을 돌려준다. HTTP는 이 대화의 약속(프로토콜)이다.
- HTTP는 무상태(Stateless): 서버는 이전 요청을 기억하지 않는다 → 로그인 유지를 위해 쿠키·토큰을 사용
- 요청 하나에 응답 하나가 짝을 이룬다

[시각자료: 브라우저 → (GET /courses) → 서버 → (200 OK + JSON) → 브라우저 로 이어지는 시퀀스 다이어그램]

## 2. 요청(Request)의 구조
```
GET /api/v1/courses?page=2 HTTP/1.1
Host: fitlearn.example.com
Authorization: Bearer eyJhbGciOi...
Accept: application/json
```
- 시작줄: 메서드 + 경로 + HTTP 버전
- 헤더: 요청에 대한 부가 정보 (인증, 데이터 형식 등)
- 본문(Body): POST·PUT 요청에서 서버로 보내는 데이터

## 3. HTTP 메서드
| 메서드 | 의미 | 멱등성 | 예시 |
|---|---|---|---|
| GET | 조회 | O | 강의 목록 보기 |
| POST | 생성 | X | 새 강의 등록 |
| PUT | 전체 수정 | O | 강의 정보 전체 교체 |
| PATCH | 부분 수정 | 보통 X | 강의 제목만 변경 |
| DELETE | 삭제 | O | 강의 삭제 |
멱등성: 같은 요청을 여러 번 보내도 결과가 같은 성질. 네트워크 오류 시 재시도해도 안전한지 판단하는 기준이 된다.

## 4. 응답(Response)과 상태 코드
```
HTTP/1.1 200 OK
Content-Type: application/json

{"courses": [{"id": "ml-101", "title": "머신러닝 입문"}]}
```
| 범위 | 의미 | 자주 보는 코드 |
|---|---|---|
| 2xx | 성공 | 200 OK, 201 Created, 204 No Content |
| 3xx | 리다이렉션 | 301 Moved Permanently, 304 Not Modified |
| 4xx | 클라이언트 오류 | 400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found, 429 Too Many Requests |
| 5xx | 서버 오류 | 500 Internal Server Error, 503 Service Unavailable |

401 vs 403: 401은 "누구신지 모르겠어요(인증 필요)", 403은 "누군지는 알지만 권한이 없어요".

## 5. 실습: curl로 직접 요청 보내기
```bash
# GET 요청 — 응답 헤더까지 보기
curl -i https://httpbin.org/get

# POST 요청 — JSON 본문 전송
curl -X POST https://httpbin.org/post \\
  -H "Content-Type: application/json" \\
  -d '{"name": "fitlearn", "level": "beginner"}'
```
응답의 상태 코드와 Content-Type 헤더를 확인해보자.
"""

_WEB_L2 = """# 2강. REST API 설계와 FastAPI 실습

## 1. REST란?
REST(Representational State Transfer)는 자원(Resource)을 URL로 표현하고, 그 자원에 대한 행위를 HTTP 메서드로 표현하는 설계 스타일이다.

## 2. 좋은 URL 설계 규칙
1. 자원은 명사, 복수형으로: /courses, /courses/42/lectures
2. 행위는 URL이 아니라 메서드로: POST /courses (O) vs /createCourse (X)
3. 계층 관계는 경로로 표현: /courses/42/lectures/3
4. 필터·정렬·페이지는 쿼리 스트링으로: /courses?level=beginner&sort=popular

| 하고 싶은 일 | 나쁜 예 | 좋은 예 |
|---|---|---|
| 강의 목록 조회 | GET /getCourses | GET /courses |
| 강의 생성 | POST /courses/new | POST /courses |
| 3번 강의 삭제 | GET /deleteCourse?id=3 | DELETE /courses/3 |

## 3. FastAPI로 REST API 만들기

```python
# main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI()

class Course(BaseModel):
    title: str
    level: str = "beginner"

courses: dict[int, Course] = {}
next_id = 1

@app.get("/courses")
def list_courses(level: str | None = None):
    items = [{"id": i, **c.model_dump()} for i, c in courses.items()]
    return [c for c in items if level is None or c["level"] == level]

@app.post("/courses", status_code=201)
def create_course(course: Course):
    global next_id
    courses[next_id] = course
    next_id += 1
    return {"id": next_id - 1, **course.model_dump()}

@app.delete("/courses/{course_id}", status_code=204)
def delete_course(course_id: int):
    if course_id not in courses:
        raise HTTPException(status_code=404, detail="강의를 찾을 수 없습니다")
    del courses[course_id]
```

실행:
```bash
pip install fastapi uvicorn
uvicorn main:app --reload
# 브라우저에서 http://127.0.0.1:8000/docs 접속 → 자동 생성된 Swagger 문서에서 바로 테스트
```

## 4. 요청 검증은 Pydantic이 자동으로
title 없이 POST를 보내면 FastAPI가 422 Unprocessable Entity와 함께 어떤 필드가 잘못됐는지 알려준다. 직접 if문으로 검사할 필요가 없다.

[시각자료: Swagger UI 화면 — POST /courses 펼침, Request body 예시 JSON, Execute 버튼, 아래에 201 응답]

## 5. 정리
- URL은 자원(명사), 메서드는 행위(동사)
- 상태 코드로 결과를 정확히 표현한다 (201 생성, 204 삭제 성공, 404 없음)
- FastAPI는 타입 힌트만으로 검증·문서화를 자동 처리한다
"""

# ── 강의 정의 ─────────────────────────────────────────────────────────────────

DEMO_COURSES: list[dict] = [
    {
        "room_id": "demo-ml-101",
        "subject": "파이썬으로 시작하는 머신러닝 입문",
        "description": "선형회귀부터 과적합까지, 코드로 직접 따라 하며 머신러닝의 핵심 원리를 익히는 입문 강의",
        "synopsis": "머신러닝의 학습 방식(지도·비지도·강화)을 구분하고, 선형회귀와 경사하강법을 NumPy로 직접 구현한 뒤, 과적합과 교차검증으로 좋은 모델을 고르는 방법까지 다룹니다.",
        "core_concepts": ["지도학습과 비지도학습", "선형회귀와 손실 함수", "경사하강법", "과적합과 교차검증"],
        "tags": ["AI", "Python", "입문"],
        "lectures": [
            {
                "lecture_id": "ml-l1",
                "title": "머신러닝의 큰 그림",
                "text": _ML_L1,
                "points": [
                    ("전통 프로그래밍은 규칙을 사람이 작성하고, 머신러닝은 데이터와 정답으로부터 규칙을 스스로 학습한다", 5, "머신러닝 정의", "하"),
                    ("지도학습(정답 있음)·비지도학습(정답 없음)·강화학습(보상)의 차이와 대표 예시", 5, "학습 방식 분류", "하"),
                    ("지도학습은 연속값을 예측하는 회귀와 범주를 고르는 분류로 나뉜다", 4, "회귀 vs 분류", "중"),
                    ("머신러닝의 진짜 목표는 처음 보는 데이터에서도 잘 동작하는 일반화이다", 4, "일반화", "중"),
                ],
            },
            {
                "lecture_id": "ml-l2",
                "title": "선형회귀와 경사하강법",
                "text": _ML_L2,
                "points": [
                    ("선형회귀 모델 ŷ = w·x + b에서 w는 기울기, b는 절편이며 오차를 최소화하는 w, b를 찾는다", 5, "선형회귀", "하"),
                    ("평균제곱오차(MSE)는 오차를 제곱해 평균낸 손실 함수로, 큰 오차에 더 큰 벌점을 준다", 5, "손실 함수", "중"),
                    ("경사하강법은 기울기의 반대 방향으로 학습률만큼 이동하며 손실의 최솟값을 찾는다", 5, "경사하강법", "중"),
                    ("학습률이 너무 크면 발산하고 너무 작으면 수렴이 느리다", 4, "학습률", "중"),
                    ("NumPy 실습 코드로 w, b가 반복 업데이트되며 손실이 줄어드는 과정을 직접 확인한다", 4, "실습", "중"),
                ],
            },
            {
                "lecture_id": "ml-l3",
                "title": "과적합과 교차검증",
                "text": _ML_L3,
                "points": [
                    ("과적합은 학습 데이터의 노이즈까지 외워 새 데이터에서 성능이 떨어지는 현상이다", 5, "과적합", "중"),
                    ("모델이 복잡해질수록 편향은 줄고 분산은 커지는 편향-분산 트레이드오프가 있다", 4, "편향-분산", "상"),
                    ("테스트 세트는 최종 평가에 단 한 번만 사용하고, 모델 선택은 검증 세트로 한다", 5, "데이터 분할", "중"),
                    ("K-겹 교차검증은 데이터를 K개로 나눠 돌아가며 검증해 안정적인 성능을 추정한다", 4, "교차검증", "중"),
                    ("다항 차수 실습에서 학습 점수와 교차검증 점수의 격차로 과적합을 진단한다", 4, "실습", "상"),
                ],
            },
        ],
        "quiz": [
            ("스팸 메일 분류처럼 정답(레이블)이 있는 데이터로 학습하는 방식은?", ["비지도학습", "지도학습", "강화학습", "전이학습"], 1, "정답(스팸/정상)이 주어진 데이터로 학습하므로 지도학습입니다."),
            ("다음 중 '회귀' 문제에 해당하는 것은?", ["사진 속 동물이 고양이인지 판별", "고객을 비슷한 그룹으로 묶기", "아파트 면적으로 매매가 예측", "바둑에서 다음 수 두기"], 2, "매매가처럼 연속적인 숫자를 예측하는 것이 회귀입니다."),
            ("경사하강법에서 학습률이 너무 클 때 생길 수 있는 문제는?", ["학습이 전혀 시작되지 않는다", "최솟값을 지나쳐 발산할 수 있다", "항상 더 정확해진다", "데이터가 줄어든다"], 1, "보폭이 너무 크면 골짜기를 넘어 반대편으로 튕기며 발산할 수 있습니다."),
            ("학습 점수는 매우 높은데 교차검증 점수가 크게 낮다면?", ["과소적합", "과적합", "데이터 누수 없음", "적정 적합"], 1, "학습 데이터만 외운 과적합의 전형적인 신호입니다."),
            ("최종 성능 보고용 테스트 세트의 올바른 사용법은?", ["하이퍼파라미터를 고를 때마다 확인", "학습 데이터와 합쳐서 사용", "마지막에 단 한 번만 평가", "검증 세트 대신 반복 사용"], 2, "테스트 세트로 모델을 고치면 테스트 세트에 과적합됩니다."),
        ],
    },
    {
        "room_id": "demo-web-101",
        "subject": "웹 개발 기초: HTTP와 REST API",
        "description": "브라우저와 서버가 대화하는 원리부터 FastAPI로 나만의 REST API를 만드는 실습까지",
        "synopsis": "HTTP 요청·응답 구조와 메서드, 상태 코드를 이해하고 REST 설계 원칙에 따라 FastAPI로 CRUD API를 직접 구현합니다.",
        "core_concepts": ["HTTP 요청과 응답", "HTTP 메서드와 상태 코드", "REST URL 설계", "FastAPI 실습"],
        "tags": ["Web", "Backend", "입문"],
        "lectures": [
            {
                "lecture_id": "web-l1",
                "title": "HTTP 요청과 응답",
                "text": _WEB_L1,
                "points": [
                    ("HTTP는 클라이언트가 요청하고 서버가 응답하는 무상태 프로토콜이다", 5, "HTTP 기본", "하"),
                    ("요청은 시작줄(메서드·경로)·헤더·본문으로 구성된다", 4, "요청 구조", "하"),
                    ("GET·POST·PUT·PATCH·DELETE의 의미와 멱등성 차이", 5, "HTTP 메서드", "중"),
                    ("상태 코드 2xx·3xx·4xx·5xx의 의미, 특히 401과 403의 차이", 5, "상태 코드", "중"),
                ],
            },
            {
                "lecture_id": "web-l2",
                "title": "REST API 설계와 FastAPI 실습",
                "text": _WEB_L2,
                "points": [
                    ("REST는 자원을 URL(명사)로, 행위를 HTTP 메서드(동사)로 표현한다", 5, "REST 원칙", "하"),
                    ("필터·정렬·페이지는 경로가 아닌 쿼리 스트링으로 표현한다", 4, "URL 설계", "중"),
                    ("FastAPI 실습 코드로 목록 조회·생성·삭제 API와 적절한 상태 코드(201, 204, 404)를 구현한다", 5, "FastAPI 실습", "중"),
                    ("Pydantic 모델로 요청 본문이 자동 검증되어 잘못된 요청에는 422가 반환된다", 4, "요청 검증", "중"),
                ],
            },
        ],
        "quiz": [
            ("HTTP가 '무상태(Stateless)'라는 말의 의미는?", ["서버가 꺼져 있다", "서버가 이전 요청을 기억하지 않는다", "응답에 본문이 없다", "암호화되지 않는다"], 1, "각 요청은 독립적이며, 상태 유지를 위해 쿠키·토큰을 씁니다."),
            ("새로운 강의를 생성할 때 가장 적절한 요청은?", ["GET /createCourse", "POST /courses", "PUT /courses/new", "DELETE /courses"], 1, "자원 생성은 컬렉션 URL에 POST로 요청합니다."),
            ("로그인은 했지만 관리자 페이지 접근 권한이 없을 때 적절한 상태 코드는?", ["401", "403", "404", "500"], 1, "403은 인증은 되었지만 권한이 없음을 의미합니다."),
            ("같은 요청을 여러 번 보내도 결과가 같은 성질을 무엇이라 하나요?", ["멱등성", "무상태성", "캐시 가능성", "일관성"], 0, "GET·PUT·DELETE는 멱등, POST는 멱등하지 않습니다."),
            ("FastAPI에서 필수 필드가 빠진 JSON을 POST하면 기본적으로 반환되는 상태 코드는?", ["200", "400", "404", "422"], 3, "Pydantic 검증 실패 시 422 Unprocessable Entity를 반환합니다."),
        ],
    },
]

FEATURED_ROOM_ID = DEMO_COURSES[0]["room_id"]

# 교수 데모 대시보드용 가상 수강생
_VIRTUAL_STUDENTS = [
    ("김서연", "시각형", "직관형", "협력형", "단기집중형"),
    ("이도윤", "실습형", "직관형", "독립형", "단기집중형"),
    ("박지호", "읽기형", "분석형", "독립형", "장기몰입형"),
    ("최하은", "시각형", "분석형", "협력형", "장기몰입형"),
    ("정민재", "청각형", "직관형", "협력형", "단기집중형"),
    ("강유나", "실습형", "분석형", "독립형", "단기집중형"),
    ("윤시우", "시각형", "직관형", "독립형", "단기집중형"),
    ("한예린", "읽기형", "분석형", "협력형", "장기몰입형"),
]


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _write_course(db, course: dict, *, room_id: str, professor_uid: str, professor_name: str,
                  students: list[str], is_demo_copy: bool, created_at: datetime) -> None:
    room_ref = db.collection("rooms").document(room_id)
    room_ref.set({
        "room_id": room_id,
        "room_code": room_id.replace("demo-", "").upper()[:6].ljust(6, "X"),
        "professor_uid": professor_uid,
        "professor_name": professor_name,
        "subject": course["subject"],
        "description": course["description"],
        "room_type": "online",
        "synopsis": course["synopsis"],
        "core_concepts": course["core_concepts"],
        "youtube_url": "",
        "price": 0,
        "completion_rate": 0,
        "has_quiz": True,
        "subject_quiz": [
            {"id": i + 1, "question": q, "options": opts, "correct_index": ans, "explanation": exp}
            for i, (q, opts, ans, exp) in enumerate(course["quiz"])
        ],
        "students": students,
        "is_demo": True,
        "is_demo_copy": is_demo_copy,
        "created_at": created_at,
        "updated_at": created_at,
    })
    db.collection("courses").document(room_id).set({
        "id": room_id,
        "roomId": room_id,
        "title": course["subject"],
        "description": course["description"],
        "thumbnail": "",
        "instructor": professor_name,
        "professor_uid": professor_uid,
        "professor_name": professor_name,
        "price": 0,
        "tags": course["tags"],
        "curriculum": [lec["title"] for lec in course["lectures"]],
        "room_type": "online",
        "is_demo": True,
        "is_demo_copy": is_demo_copy,
        "created_at": created_at,
        "updated_at": created_at,
    })
    for index, lec in enumerate(course["lectures"], start=1):
        lecture_id = lec["lecture_id"]
        room_ref.collection("lectures").document(lecture_id).set({
            "lecture_id": lecture_id,
            "room_id": room_id,
            "title": lec["title"],
            "week_number": index,
            "order_index": index,
            "original_text": lec["text"].strip(),
            "core_points": [
                {"id": i + 1, "content": c, "priority": p, "topic": t, "difficulty": d}
                for i, (c, p, t, d) in enumerate(lec["points"])
            ],
            "confirmed": True,
            "video_url": "",
            "video_type": "none",
            "video_title": "",
            "video_status": "none",
            "video_source": "none",
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
            "material_url": "",
            "is_placeholder": False,
            "created_at": created_at,
            "updated_at": created_at,
        })


async def ensure_demo_content() -> None:
    """대표 데모 강의를 생성(이미 있으면 콘텐츠만 최신화). 서버 시작 시 호출."""
    db = _get_db()
    if db is None:
        return

    def _write():
        db.collection("users").document(DEMO_PROFESSOR_UID).set({
            "name": DEMO_PROFESSOR_NAME, "role": "professor", "email": "",
            "is_active": False, "is_demo": True,
        }, merge=True)
        for i, course in enumerate(DEMO_COURSES):
            room_id = course["room_id"]
            snap = db.collection("rooms").document(room_id).get()
            prev = (snap.to_dict() or {}) if snap.exists else {}
            _write_course(
                db, course, room_id=room_id,
                professor_uid=DEMO_PROFESSOR_UID, professor_name=DEMO_PROFESSOR_NAME,
                students=prev.get("students", []), is_demo_copy=False,
                created_at=prev.get("created_at") or (_now() - timedelta(minutes=i)),
            )

    try:
        await _run(_write)
        await FirebaseService()._cache_delete_prefix("room")
        logger.info(f"[demo_seed] 데모 강의 {len(DEMO_COURSES)}개 준비 완료")
    except Exception as e:
        logger.error(f"[demo_seed] 데모 강의 생성 실패: {e}")


async def bootstrap_demo_user(user_id: str, role: str, name: str) -> dict:
    """방문자 데모 계정 준비. 반환: 바로 이동할 강의실 정보."""
    fb = FirebaseService()
    await fb.save_user(user_id, name, role, "")
    db = _get_db()

    if role == "student":
        for course in DEMO_COURSES:
            await fb.add_student_to_room(course["room_id"], user_id)
        await fb._cache_delete_prefix(f"student_hub:{user_id}")
        await fb._cache_delete_prefix(f"student_rooms:{user_id}")
        return {"role": role, "room_id": FEATURED_ROOM_ID}

    # 교수: 개인 데모 강의실 사본 + 가상 수강생
    course = copy.deepcopy(DEMO_COURSES[0])
    room_id = f"demo-copy-{user_id}"[:120]

    def _write():
        if db.collection("rooms").document(room_id).get().exists:
            return
        student_ids = []
        for idx, (sname, vark, cog, inter, focus) in enumerate(_VIRTUAL_STUDENTS):
            sid = f"{room_id}-s{idx + 1}"
            student_ids.append(sid)
            profile = {
                "learning_style": vark, "cognitive_style": cog, "interaction": inter,
                "focus_pattern": focus, "preferred_format": "상세형", "pace": "숙고형",
                "confidence_score": 72 + idx * 3,
            }
            db.collection("users").document(sid).set({
                "name": sname, "role": "student", "email": "", "is_demo": True,
                "learning_profile": profile,
            }, merge=True)
        _write_course(
            db, course, room_id=room_id,
            professor_uid=user_id, professor_name=name,
            students=student_ids, is_demo_copy=True, created_at=_now(),
        )
        db.collection("rooms").document(room_id).set({"completion_rate": 46}, merge=True)

    await _run(_write)
    await fb._cache_delete_prefix(f"professor_rooms:{user_id}")
    return {"role": role, "room_id": room_id}
