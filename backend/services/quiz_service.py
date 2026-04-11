"""
수준판단 퀴즈 서비스
- 교수의 synopsis + core_concepts → Gemini로 5~7문제 생성
- 학생 답안 채점 → subject_level (beginner/intermediate/advanced) 판정
"""
import asyncio
import json
import logging
import os
import re

from google import genai
from google.genai import types

logger = logging.getLogger(__name__)
MODEL = "models/gemma-4-31b-it"


def _extract_json(text: str) -> list | dict:
    text = text.strip()
    match = re.search(r"```(?:json)?\s*([\s\S]+?)```", text)
    if match:
        text = match.group(1).strip()
    # 배열 우선
    s = text.find("[")
    if s != -1:
        e = text.rfind("]") + 1
        if e > s:
            return json.loads(text[s:e])
    # 객체
    s = text.find("{")
    e = text.rfind("}") + 1
    if s != -1 and e > s:
        return json.loads(text[s:e])
    return json.loads(text)


class QuizService:
    def __init__(self):
        api_key = os.getenv("GEMINI_API_KEY")
        if api_key:
            self._client = genai.Client(api_key=api_key)
        else:
            logger.warning("[QuizService] GEMINI_API_KEY 미설정 — 퀴즈 생성 기능 동작 보장 불가")
            self._client = None

    def _config(self) -> types.GenerateContentConfig:
        return types.GenerateContentConfig(
            temperature=0.3,
            max_output_tokens=2048,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
        )

    async def generate_quiz(
        self, synopsis: str, core_concepts: list[str], subject: str = ""
    ) -> list[dict]:
        """
        과목 줄거리 + 핵심개념 → 수준판단 퀴즈 5~7문제 생성
        4지선다, 정답 인덱스, 해설 포함
        """
        concepts_text = "\n".join(f"- {c}" for c in core_concepts) if core_concepts else "없음"

        prompt = f"""당신은 교육 전문가입니다. 아래 과목 정보를 기반으로 학생의 사전 지식 수준을 판별하는 퀴즈를 만드세요.

[과목]: {subject}
[과목 줄거리]: {synopsis}
[핵심 개념들]:
{concepts_text}

규칙:
1. 문제 수: 정확히 6문제
2. 각 문제는 4지선다 (options 배열에 4개)
3. 난이도 분포: 기초 2문제, 중급 2문제, 심화 2문제
4. 정답은 correct_index (0~3 중 하나)
5. 각 문제에 짧은 해설(explanation) 포함
6. 문제는 단순 암기보다 이해·적용을 묻는 형태로
7. 환각(hallucination) 없이 제공된 내용에서만 출제

반드시 아래 JSON 배열 형식만 출력 (JSON 외 텍스트 없이):
[
  {{
    "id": 1,
    "question": "문제 내용",
    "options": ["보기1", "보기2", "보기3", "보기4"],
    "correct_index": 0,
    "explanation": "이 보기가 정답인 이유"
  }}
]"""

        try:
            try:
                response = await asyncio.wait_for(
                    asyncio.to_thread(
                        self._client.models.generate_content,
                        model=MODEL,
                        contents=prompt,
                        config=self._config(),
                    ),
                    timeout=40.0,
                )
                questions = _extract_json(response.text)
                if not isinstance(questions, list):
                    raise ValueError("JSON 배열이 아님")
                # 필드 검증
                validated = []
                for i, q in enumerate(questions[:7]):
                    validated.append({
                        "id": i + 1,
                        "question": q.get("question", ""),
                        "options": q.get("options", [])[:4],
                        "correct_index": int(q.get("correct_index", 0)),
                        "explanation": q.get("explanation", ""),
                    })
                logger.info(f"[QuizService] 퀴즈 {len(validated)}문제 생성 완료")
                return validated
            except asyncio.TimeoutError:
                logger.error("[QuizService] 퀴즈 생성 타임아웃 → Fallback 전환")
                return _fallback_quiz(subject, synopsis, core_concepts)
            except Exception as e:
                logger.error(f"[QuizService] 퀴즈 생성 중 예외: {e} → Fallback 전환")
                return _fallback_quiz(subject, synopsis, core_concepts)
        except Exception as critical_e:
            logger.critical(f"[QuizService] 심각한 오류: {critical_e}")
            return _fallback_quiz(subject, synopsis, core_concepts)

    def grade_quiz(self, questions: list[dict], answers: list[int]) -> dict:
        """
        답안 채점 → score(0~100), subject_level 판정
        """
        total = len(questions)
        if total == 0:
            return {"score": 0, "subject_level": "beginner", "correct_count": 0, "total_count": 0}

        correct = sum(
            1 for i, q in enumerate(questions)
            if i < len(answers) and answers[i] == q.get("correct_index", -1)
        )
        score = round(correct / total * 100)

        if score >= 80:
            level = "advanced"
        elif score >= 50:
            level = "intermediate"
        else:
            level = "beginner"

        logger.info(f"[QuizService] 채점 완료: {correct}/{total} = {score}점 → {level}")
        return {
            "score": score,
            "subject_level": level,
            "correct_count": correct,
            "total_count": total,
        }


def _fallback_quiz(subject: str, synopsis: str = "", core_concepts: list[str] | None = None) -> list[dict]:
    """AI 호출 실패 시에도 과목 핵심 개념을 최대한 반영하는 기본 6문항 퀴즈"""
    subject_name = subject.strip() or "이 과목"
    concepts = [
        re.sub(r"\s+", " ", str(concept)).strip(" -•\t")
        for concept in (core_concepts or [])
        if str(concept).strip()
    ]
    if not concepts and synopsis.strip():
        concepts = [
            chunk.strip()
            for chunk in re.split(r"[,·/.\n]", synopsis)
            if len(chunk.strip()) >= 2
        ]
    concepts = (concepts + [subject_name, "핵심 개념", "수업 목표"])[:6]

    def concept(index: int) -> str:
        return concepts[index % len(concepts)]

    return [
        {
            "id": 1,
            "question": f"{subject_name}에서 '{concept(0)}'을 학습할 때 가장 먼저 확인해야 할 것은 무엇인가요?",
            "options": ["용어의 뜻과 역할", "시험 점수 예측", "수강생 수", "강의 업로드 날짜"],
            "correct_index": 0,
            "explanation": "핵심 개념을 이해하려면 먼저 용어의 의미와 수업 안에서의 역할을 확인해야 합니다.",
        },
        {
            "id": 2,
            "question": f"'{concept(1)}'을 설명하는 자료를 읽을 때 좋은 학습 행동은 무엇인가요?",
            "options": ["정의와 예시를 연결한다", "이미지는 모두 건너뛴다", "낯선 용어를 외면한다", "결론만 보고 넘어간다"],
            "correct_index": 0,
            "explanation": "개념은 정의와 예시를 함께 연결해야 실제 문제에 적용하기 쉽습니다.",
        },
        {
            "id": 3,
            "question": f"{subject_name}의 핵심 내용을 실제 과제에 적용하려면 어떤 순서가 가장 적절한가요?",
            "options": ["개념 확인 → 예시 분석 → 직접 적용", "결과 복사 → 이유 생략 → 제출", "암기 → 무작위 적용 → 수정 안 함", "난이도 높은 문제부터 즉시 풀이"],
            "correct_index": 0,
            "explanation": "기초 개념을 확인하고 예시를 분석한 뒤 직접 적용하는 순서가 안정적입니다.",
        },
        {
            "id": 4,
            "question": f"'{concept(2)}'에 대해 학생이 중급 수준에 가까운 반응은 무엇인가요?",
            "options": ["이름만 들어봤다", "정의와 대표 예시를 연결해 설명한다", "강의명을 기억하지 못한다", "관련 없는 예시로만 설명한다"],
            "correct_index": 1,
            "explanation": "정의와 대표 예시를 연결해 설명할 수 있으면 단순 암기를 넘어선 이해가 있다고 볼 수 있습니다.",
        },
        {
            "id": 5,
            "question": f"{subject_name} 수업에서 심화 단계로 넘어가기 전 필요한 준비는 무엇인가요?",
            "options": ["핵심 용어와 흐름을 말로 정리한다", "모르는 부분을 그대로 둔다", "자료 제목만 외운다", "연습 없이 다음 장으로 넘긴다"],
            "correct_index": 0,
            "explanation": "심화 학습 전에는 핵심 용어와 전체 흐름을 스스로 설명할 수 있어야 합니다.",
        },
        {
            "id": 6,
            "question": f"'{concept(3)}'을 잘 이해했는지 확인하는 가장 좋은 방법은 무엇인가요?",
            "options": ["내 말로 요약하고 작은 예시에 적용해 본다", "문장을 그대로 베껴 쓴다", "정답만 표시하고 이유를 생략한다", "관련 없는 영상을 본다"],
            "correct_index": 0,
            "explanation": "자기 말 요약과 작은 예시 적용은 이해도를 확인하는 가장 직접적인 방법입니다.",
        },
    ]
