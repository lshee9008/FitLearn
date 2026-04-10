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

import google.generativeai as genai

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
    def _model(self):
        api_key = os.getenv("GEMINI_API_KEY")
        if api_key:
            genai.configure(api_key=api_key, transport="rest")
        else:
            logger.warning("[QuizService] GEMINI_API_KEY 미설정 — 퀴즈 생성 기능 동작 보장 불가")
            
        return genai.GenerativeModel(
            model_name=MODEL,
            generation_config=genai.GenerationConfig(
                temperature=0.3,
                max_output_tokens=2048,
            ),
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
                    asyncio.to_thread(self._model().generate_content, prompt),
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
                return _fallback_quiz(subject)
            except Exception as e:
                logger.error(f"[QuizService] 퀴즈 생성 중 예외: {e} → Fallback 전환")
                return _fallback_quiz(subject)
        except Exception as critical_e:
            logger.critical(f"[QuizService] 심각한 오류: {critical_e}")
            return _fallback_quiz(subject)

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


def _fallback_quiz(subject: str) -> list[dict]:
    """AI 호출 실패 시에도 동작 가능한 기본 6문항 퀴즈"""
    subject_name = subject.strip() or "이 과목"
    return [
        {
            "id": 1,
            "question": f"{subject_name}의 핵심 개념을 처음 들었을 때 가장 가까운 상태는 무엇인가요?",
            "options": ["처음 듣는다", "이름만 안다", "대략 설명할 수 있다", "다른 사람에게 설명할 수 있다"],
            "correct_index": 2,
            "explanation": "기초 개념을 설명할 수 있는 수준을 중간 기준으로 봅니다.",
        },
        {
            "id": 2,
            "question": f"{subject_name} 관련 문제를 만났을 때 가장 먼저 할 수 있는 행동은 무엇인가요?",
            "options": ["관련 용어를 찾는다", "예시를 보고 따라 한다", "핵심 원리를 떠올린다", "스스로 풀이 전략을 세운다"],
            "correct_index": 2,
            "explanation": "원리를 떠올리는 단계는 기본 이해가 형성된 상태입니다.",
        },
        {
            "id": 3,
            "question": f"{subject_name}를 배울 때 가장 어려운 지점은 무엇인가요?",
            "options": ["용어 자체가 낯설다", "예시는 이해되나 응용이 어렵다", "응용은 되지만 속도가 느리다", "대부분 익숙하다"],
            "correct_index": 1,
            "explanation": "예시 이해 후 응용이 어려운 단계는 입문을 지난 중간 단계로 볼 수 있습니다.",
        },
        {
            "id": 4,
            "question": f"{subject_name} 개념을 실제 과제나 문제에 적용해본 경험은 어느 정도인가요?",
            "options": ["없다", "한두 번 있다", "여러 번 있다", "익숙하게 반복 적용한다"],
            "correct_index": 2,
            "explanation": "여러 번 적용해본 경험은 중급 이상 판단의 근거가 됩니다.",
        },
        {
            "id": 5,
            "question": f"{subject_name}의 기본 개념과 심화 개념의 차이를 얼마나 구분할 수 있나요?",
            "options": ["거의 구분 못한다", "대표 개념 몇 개만 구분한다", "대부분 구분한다", "연결 구조까지 설명할 수 있다"],
            "correct_index": 2,
            "explanation": "대부분 구분 가능하면 학습 준비도가 충분한 편입니다.",
        },
        {
            "id": 6,
            "question": f"{subject_name} 수업을 들을 때 가장 적절한 시작 난이도는 무엇이라고 생각하나요?",
            "options": ["아주 기초부터", "기초와 예시 중심", "기초 요약 후 바로 응용", "심화 문제부터"],
            "correct_index": 1,
            "explanation": "기초와 예시 중심은 다수 학습자에게 적절한 기본 시작점입니다.",
        },
    ]
