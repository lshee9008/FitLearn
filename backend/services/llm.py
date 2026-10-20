"""
Gemini 호출 공통 모듈 — 모든 AI 호출은 여기를 거친다.
- 모델 폴백 체인 (GEMINI_MODEL → GEMINI_MODEL_FALLBACKS)
- 쿼터 초과 시 쿨다운
- 비스트리밍 / SSE 스트리밍
"""
import asyncio
import json
import logging
import os
import time

import httpx

logger = logging.getLogger(__name__)

DEFAULT_MODEL = "gemini-3.5-flash"
MODEL = os.getenv("GEMINI_MODEL", DEFAULT_MODEL)
MODEL_FALLBACKS = [
    model.strip()
    for model in os.getenv(
        "GEMINI_MODEL_FALLBACKS",
        "gemini-flash-latest,gemini-2.5-flash",
    ).split(",")
    if model.strip()
]
_working_model = MODEL
_quota_cooldown_until = 0.0
_API_BASE = "https://generativelanguage.googleapis.com/v1beta/models"


def _is_quota_error(error: Exception) -> bool:
    message = str(error).lower()
    return "429" in message or "quota" in message or "rate-limit" in message


def _activate_quota_cooldown(seconds: int = 75) -> None:
    global _quota_cooldown_until
    _quota_cooldown_until = max(_quota_cooldown_until, time.monotonic() + seconds)


def _thinking_config(model: str) -> dict:
    """응답 지연을 줄이기 위해 모델 세대별로 사고(thinking) 단계를 최소화."""
    if model.startswith("gemini-2.5"):
        return {"thinkingBudget": 0}
    if model.startswith("gemini-3") or model.startswith("gemini-flash"):
        return {"thinkingLevel": "minimal"}
    return {}


def _to_parts(contents) -> list[dict]:
    if isinstance(contents, str):
        return [{"text": contents}]
    if isinstance(contents, list):
        parts = []
        for item in contents:
            if isinstance(item, str):
                parts.append({"text": item})
            elif hasattr(item, "uri") and hasattr(item, "mime_type"):
                parts.append({"file_data": {"mime_type": item.mime_type, "file_uri": item.uri}})
            else:
                parts.append({"text": str(item)})
        return parts
    return [{"text": str(contents)}]


def _request_body(contents, model: str, temperature: float, max_output_tokens: int, thinking: bool = True) -> dict:
    generation = {"temperature": temperature, "maxOutputTokens": max_output_tokens}
    if thinking and _thinking_config(model):
        generation["thinkingConfig"] = _thinking_config(model)
    return {"contents": [{"role": "user", "parts": _to_parts(contents)}], "generationConfig": generation}


def _api_headers() -> dict:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY가 설정되지 않았습니다.")
    return {"x-goog-api-key": api_key}


def _candidate_text(data: dict) -> str:
    parts = (data.get("candidates") or [{}])[0].get("content", {}).get("parts", []) or []
    return "".join(p.get("text", "") for p in parts if not p.get("thought"))


def _model_candidates() -> list[str]:
    candidates = []
    for model_name in [_working_model, MODEL, *MODEL_FALLBACKS]:
        if model_name and model_name not in candidates:
            candidates.append(model_name)
    return candidates


async def _call_gemini_rest(
    contents,
    *,
    model: str,
    temperature: float,
    max_output_tokens: int,
    timeout: float,
) -> str:
    headers = _api_headers()
    url = f"{_API_BASE}/{model}:generateContent"
    async with httpx.AsyncClient(timeout=timeout) as client:
        response = await client.post(
            url, json=_request_body(contents, model, temperature, max_output_tokens), headers=headers
        )
        if response.status_code == 400 and "thinking" in response.text.lower():
            response = await client.post(
                url, json=_request_body(contents, model, temperature, max_output_tokens, thinking=False),
                headers=headers,
            )
        data = response.json()

    if not response.is_success:
        raise Exception(f"Gemini API 오류 ({response.status_code}): {data}")

    text = _candidate_text(data)
    if not text:
        raise RuntimeError(f"Gemini 응답 파싱 실패: {str(data)[:300]}")
    return text


async def stream_gemini_text(
    contents,
    *,
    temperature: float = 0.6,
    max_output_tokens: int = 8192,
    timeout: float = 120.0,
    feature: str = "gemini-stream",
):
    """Gemini SSE 스트리밍. 첫 청크가 나오기 전 실패하면 다음 모델로 폴백."""
    global _working_model
    if time.monotonic() < _quota_cooldown_until:
        raise RuntimeError("Gemini quota cooldown active")

    headers = _api_headers()
    last_error: Exception | None = None
    for model_name in _model_candidates():
        url = f"{_API_BASE}/{model_name}:streamGenerateContent?alt=sse"
        emitted = False
        try:
            async with httpx.AsyncClient(timeout=httpx.Timeout(timeout, connect=15.0)) as client:
                async with client.stream(
                    "POST", url, headers=headers,
                    json=_request_body(contents, model_name, temperature, max_output_tokens),
                ) as response:
                    if response.status_code != 200:
                        body = (await response.aread()).decode("utf-8", "ignore")
                        raise Exception(f"Gemini API 오류 ({response.status_code}): {body[:300]}")
                    async for line in response.aiter_lines():
                        if not line.startswith("data:"):
                            continue
                        try:
                            chunk = _candidate_text(json.loads(line[5:]))
                        except Exception:
                            continue
                        if chunk:
                            emitted = True
                            yield chunk
            if emitted:
                _working_model = model_name
                return
            raise RuntimeError("Gemini 스트림 응답이 비어 있습니다.")
        except Exception as e:
            if emitted:
                raise
            if _is_quota_error(e):
                _activate_quota_cooldown()
                logger.warning(f"[{feature}] quota 감지: {e}")
                raise RuntimeError("Gemini quota exceeded") from e
            last_error = e
            logger.warning(f"[{feature}] model={model_name} 스트림 실패 — 다음 모델 시도: {e}")
    raise RuntimeError(f"Gemini 스트리밍 실패: {last_error}")


async def generate_gemini_text(
    contents,
    *,
    temperature: float = 0.7,
    max_output_tokens: int = 2048,
    timeout: float = 60.0,
    feature: str = "gemini",
) -> str:
    global _working_model

    if time.monotonic() < _quota_cooldown_until:
        raise RuntimeError("Gemini quota cooldown active")

    candidates = _model_candidates()

    loop = asyncio.get_running_loop()
    deadline = loop.time() + timeout
    last_error: Exception | None = None
    for model_name in candidates:
        remaining = deadline - loop.time()
        if remaining <= 0:
            raise asyncio.TimeoutError(f"{feature} 전체 생성 시간 초과 ({timeout}s)")
        try:
            text = await asyncio.wait_for(
                _call_gemini_rest(
                    contents,
                    model=model_name,
                    temperature=temperature,
                    max_output_tokens=max_output_tokens,
                    timeout=remaining,
                ),
                timeout=remaining,
            )
            if not text:
                raise RuntimeError("Gemini 응답이 비어 있습니다.")
            _working_model = model_name
            return text
        except asyncio.TimeoutError:
            logger.warning(f"[{feature}] model={model_name} 시간 초과 ({timeout}s)")
            raise
        except Exception as e:
            if _is_quota_error(e):
                _activate_quota_cooldown()
                logger.warning(f"[{feature}] Gemini quota 감지 — fallback 중단: {e}")
                raise RuntimeError("Gemini quota exceeded") from e
            last_error = e
            logger.warning(f"[{feature}] model={model_name} 실패 — 다음 모델 시도: {e}")

    raise RuntimeError(f"Gemini 생성 실패: {last_error}")
