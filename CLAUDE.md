# FitLearn

KIT/KEG 수강생 성향을 AI로 진단하고 같은 교안을 개인 맞춤형으로 재가공해주는 AI 학습 엔진

## 기술 스택

**Frontend**
- Flutter Web 3.x
- Riverpod 2.0 (상태관리)
- GoRouter (네비게이션)
- Dio (HTTP 클라이언트)
- SSE 스트리밍 수신 처리
- Vercel 배포

**Backend**
- FastAPI (Python 3.11+)
- LangChain + Claude API (`claude-sonnet-4-20250514`)
- asyncio.gather() 병렬 처리 (3버전 동시 생성)
- SSE (Server-Sent Events) 스트리밍 응답
- RAG 파이프라인 (교안 벡터화 → 유형별 재가공)
- Redis (Semantic Caching, 세션 저장)
- Firebase Firestore (수강생 데이터)
- Firebase Auth + JWT 미들웨어
- slowapi (Rate Limiting)
- Sentry (에러 모니터링)
- Render 배포

**DevOps**
- Docker + docker-compose (백엔드 컨테이너화)
- GitHub Actions CI/CD (push → 테스트 → 자동 배포)
- 환경 분리 (`.env.development` / `.env.production`)
- GitHub Secrets (API 키 관리)

## 핵심 기능

1. **온보딩 진단** → 학습 유형 분류 (요약형 / 상세형 / 예시형)
2. **교안 RAG 재가공** → `asyncio.gather()`로 3버전 병렬 생성 (SSE 스트리밍)
3. **강의자 대시보드** → 질문 패턴 AI 분석

## AI 파이프라인 전략

- **RAG**: 교안 벡터화 후 관련 청크 검색 → 재가공 정확도 향상
- **Prompt Chaining**: 진단 → 분류 → 재가공 단계별 체인 연결
- **Few-shot Prompting**: 유형 분류 예시 포함으로 정확도 향상
- **Structured Output (JSON Mode)**: Claude 응답 JSON 강제로 파싱 오류 제거
- **Self-consistency**: 유형 분류 다중 샘플링 후 최빈값 선택
- **Temperature 튜닝**:
  - 진단 분류: `temperature=0.2` (일관성)
  - 교안 재가공: `temperature=0.7` (창의성)
- **Fallback Chain**: API 실패 시 캐시 → 기본 템플릿 순 폴백
- **asyncio.gather()**: 3버전 병렬 생성으로 순차 대비 3배 속도
- **Semantic Caching**: 유사 교안 Redis 캐시 히트로 비용 절감

## API 구조

```
POST /api/v1/diagnosis      - 진단 → 유형 분류 + Redis 저장
POST /api/v1/reforge        - 교안 → RAG 기반 3버전 병렬 생성 (SSE)
POST /api/v1/questions      - 수강생 질문 수집
GET  /api/v1/dashboard/{id} - 강의자 인사이트
GET  /api/v1/health         - 헬스체크
```

## 프로젝트 구조

```
FitLearn/
├── CLAUDE.md
├── .github/
│   └── workflows/
│       ├── frontend.yml   # Flutter Web 빌드 → Vercel
│       └── backend.yml    # Docker 빌드 → Render
├── frontend/              # Flutter Web
│   └── lib/
│       ├── core/
│       │   ├── theme/
│       │   ├── router/
│       │   └── constants/
│       ├── features/
│       │   ├── onboarding/
│       │   │   ├── provider/
│       │   │   ├── view/
│       │   │   └── widget/
│       │   ├── lecture/
│       │   │   ├── provider/
│       │   │   ├── view/
│       │   │   └── widget/
│       │   └── dashboard/
│       │       ├── provider/
│       │       ├── view/
│       │       └── widget/
│       └── shared/
│           ├── widgets/
│           └── services/
└── backend/               # FastAPI
    ├── Dockerfile
    ├── docker-compose.yml
    ├── main.py
    ├── .env.development
    ├── .env.production
    ├── api/
    │   └── v1/
    │       └── routers/
    │           ├── diagnosis.py
    │           ├── reforge.py
    │           ├── questions.py
    │           └── dashboard.py
    ├── services/
    │   ├── claude_service.py
    │   ├── rag_service.py
    │   ├── redis_service.py
    │   └── sentry_service.py
    └── models/
        ├── diagnosis.py
        └── lecture.py
```

## 코딩 컨벤션

- Flutter: feature-first 폴더 구조, Riverpod Provider 완전 분리
- FastAPI: router / service / model 3레이어 엄격히 분리
- 모든 Claude API 호출은 `claude_service.py`에서만
- 환경변수는 `.env`에서만 관리, 절대 하드코딩 금지
- 모든 API 에러 핸들링 필수 (HTTPException + Sentry 캡처)
- `asyncio` 사용 시 반드시 `gather()`로 병렬화
- Redis 없을 시 인메모리 딕셔너리로 폴백
- CORS 설정 필수 (Flutter Web ↔ FastAPI)
- Firebase Auth 토큰 검증 미들웨어 전체 라우터 적용

## 주의사항

- Claude API 스트리밍은 SSE로만 처리
- Rate Limiting: 진단 10req/min, 재가공 5req/min
- Docker 컨테이너 내 Redis 연결은 서비스명으로
- GitHub Actions secrets에 `ANTHROPIC_API_KEY` 등록 필수
- Vercel 배포 시 Flutter Web `build/web` 폴더 지정
