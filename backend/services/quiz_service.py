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
        genai.configure(api_key=os.environ["GEMINI_API_KEY"], transport="rest")
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
            logger.error("[QuizService] 퀴즈 생성 타임아웃")
            return _fallback_quiz(subject)
        except Exception as e:
            logger.error(f"[QuizService] 퀴즈 생성 실패: {e}")
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
    """AI 호출 실패 시 기본 퀴즈"""
    return [
        {
            "id": 1,
            "question": f"{subject} 과목을 수강한 경험이 있나요?",
            "options": ["전혀 없음", "약간 있음", "어느 정도 있음", "많이 있음"],
            "correct_index": -1,  # -1 = 자가진단형 (채점 제외)
            "explanation": "자가 신고 문항입니다.",
        }
    ]
