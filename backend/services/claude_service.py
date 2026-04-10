import asyncio
import json
import os
from typing import AsyncGenerator

import google.generativeai as genai

MODEL = "gemma-4-31b-it"
LEARNING_TYPES = ["요약형", "상세형", "예시형"]


class ClaudeService:
    def __init__(self):
        api_key = os.getenv("GEMINI_API_KEY")
        if api_key:
            genai.configure(api_key=api_key)

    async def classify_learning_type(self, answers: list[str]) -> str:
        """Few-shot + Self-consistency로 학습 유형 분류 (temperature=0.2)"""
        prompt = self._build_diagnosis_prompt(answers)

        # Self-consistency: 3회 샘플링 후 최빈값
        tasks = [self._classify_once(prompt) for _ in range(3)]
        results = await asyncio.gather(*tasks)
        return max(set(results), key=results.count)

    async def _classify_once(self, prompt: str) -> str:
        model = genai.GenerativeModel(
            model_name=MODEL,
            generation_config=genai.GenerationConfig(
                temperature=0.2,
                max_output_tokens=100,
            ),
        )
        response = await asyncio.to_thread(model.generate_content, prompt)
        text = response.text.strip()
        for t in LEARNING_TYPES:
            if t in text:
                return t
        return "요약형"  # fallback

    async def reforge_parallel_stream(
        self, lecture_content: str, user_id: str
    ) -> AsyncGenerator[str, None]:
        """3가지 유형 병렬 재가공 후 SSE 스트리밍 (asyncio.gather + temperature=0.7)"""
        tasks = [self._reforge_one(lecture_content, t) for t in LEARNING_TYPES]
        results = await asyncio.gather(*tasks)

        for learning_type, content in zip(LEARNING_TYPES, results):
            data = json.dumps({"type": learning_type, "content": content}, ensure_ascii=False)
            yield f"data: {data}\n\n"

        yield "data: [DONE]\n\n"

    async def _reforge_one(self, lecture_content: str, learning_type: str) -> str:
        prompt = self._build_reforge_prompt(lecture_content, learning_type)
        model = genai.GenerativeModel(
            model_name=MODEL,
            generation_config=genai.GenerationConfig(
                temperature=0.7,
                max_output_tokens=2048,
            ),
        )
        response = await asyncio.to_thread(model.generate_content, prompt)
        return response.text

    def _build_diagnosis_prompt(self, answers: list[str]) -> str:
        examples = (
            "예시1: '핵심만 빠르게 알고 싶어요' → 요약형\n"
            "예시2: '모든 개념을 단계별로 설명해주세요' → 상세형\n"
            "예시3: '실제 사례를 들어주세요' → 예시형\n"
        )
        joined = "\n".join(f"- {a}" for a in answers)
        return (
            f"{examples}\n"
            f"다음 수강생 응답을 분석해 학습 유형(요약형/상세형/예시형) 중 하나만 JSON으로 반환하세요.\n"
            f"응답: {joined}\n"
            f'형식: {{"learning_type": "요약형"}}'
        )

    def _build_reforge_prompt(self, lecture_content: str, learning_type: str) -> str:
        style_guide = {
            "요약형": "핵심 개념만 bullet point로 간결하게 정리",
            "상세형": "모든 개념을 단계별로 논리적으로 상세 설명",
            "예시형": "각 개념마다 실생활 예시와 코드 예시를 풍부하게 포함",
        }
        return (
            f"다음 교안을 [{learning_type}] 스타일로 재가공해주세요.\n"
            f"스타일 가이드: {style_guide[learning_type]}\n\n"
            f"원본 교안:\n{lecture_content}"
        )
