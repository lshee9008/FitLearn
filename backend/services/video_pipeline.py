"""
Video lecture analysis pipeline.

Uploaded lecture videos are processed with Gemini File API into transcript,
chapters and a grounded summary. The pipeline is intentionally best-effort:
uploading a lecture must not fail just because transcription is delayed.
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import tempfile
from pathlib import Path
from typing import Any

from google import genai
from google.genai import types

from .reforge_service import generate_gemini_text

logger = logging.getLogger(__name__)


def _json_from_markdown(text: str) -> dict[str, Any]:
    cleaned = text.strip()
    fenced = re.search(r"```(?:json)?\s*(.*?)```", cleaned, re.DOTALL | re.IGNORECASE)
    if fenced:
        cleaned = fenced.group(1).strip()
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        logger.warning("[VideoPipeline] JSON 파싱 실패 — 원문 요약으로 폴백")
        return {
            "transcript": cleaned,
            "segments": [],
            "chapters": [],
            "summary_markdown": cleaned,
            "key_moments": [],
            "study_tips": [],
            "stuck_points": [],
        }


def _fallback_video_analysis(original_text: str, core_points: list[dict]) -> dict[str, Any]:
    points = [
        point.get("content", "").strip()
        for point in core_points
        if point.get("content", "").strip()
    ]
    summary = "\n".join(f"- {point}" for point in points[:8])
    return {
        "transcript": "",
        "segments": [],
        "chapters": [],
        "summary_markdown": (
            "## 영상 분석 대기\n\n"
            "영상 전사가 아직 완료되지 않았습니다. 현재는 교수 핵심 포인트와 교안을 기준으로 학습을 이어갈 수 있습니다.\n\n"
            f"{summary or original_text[:900]}"
        ),
        "key_moments": [],
        "study_tips": [],
        "stuck_points": [],
    }


def summarize_transcript_locally(
    *,
    transcript_text: str,
    title: str,
    original_text: str,
    core_points: list[dict],
    reason: str = "",
) -> dict[str, Any]:
    segments = _segments_from_transcript_text(transcript_text)
    points = [
        str(point.get("content", "")).strip()
        for point in core_points
        if str(point.get("content", "")).strip()
    ]
    transcript_lines = [
        segment.get("text", "").strip()
        for segment in segments
        if isinstance(segment, dict) and segment.get("text")
    ]
    basis = transcript_lines[:8] or points[:8]
    bullets = "\n".join(f"- {line}" for line in basis if line)
    if not bullets and original_text:
        bullets = "\n".join(
            f"- {line.strip()}"
            for line in re.split(r"[\n.]", original_text[:1200])
            if line.strip()
        )[:1400]

    return {
        "transcript": transcript_text,
        "segments": segments[:180],
        "chapters": _segments_to_chapters(segments),
        "summary_markdown": (
            f"## {title or '영상 강의'} 요약\n\n"
            "> AI 정밀 요약이 지연되어, 현재 확보된 영상 대본과 교수 핵심 포인트를 기준으로 먼저 제공합니다.\n\n"
            "### 핵심 흐름\n"
            f"{bullets or '- 영상 대본이 없어 교안 핵심 포인트 기준으로만 확인할 수 있습니다.'}\n\n"
            "### 학습 팁\n"
            "- 영상에서 사용한 용어를 교안의 핵심 포인트와 나란히 확인하세요.\n"
            "- 코드나 실습 장면은 영상 화면을 멈춘 뒤 그대로 따라 입력하고 결과를 비교하세요."
            + (f"\n\n> 처리 메모: {reason}" if reason else "")
        ),
        "key_moments": [
            {
                "minute": item.get("start_minute", 0),
                "label": "다시 볼 구간",
                "reason": item.get("text", "")[:120],
            }
            for item in segments[:5]
        ],
        "study_tips": [
            "자막 기반 요약이므로 영상 화면의 그림과 함께 확인하세요.",
            "실습/코드 장면은 그대로 따라하며 결과를 비교하세요.",
        ],
        "stuck_points": [],
    }


def _segments_to_chapters(segments: list[dict[str, Any]]) -> list[dict[str, Any]]:
    if not segments:
        return []
    chapters: list[dict[str, Any]] = []
    for bucket_start in range(0, min(60, max(int(s.get("end_minute", 0) or 0) for s in segments) + 1), 5):
        bucket = [
            s for s in segments
            if bucket_start <= int(s.get("start_minute", 0) or 0) < bucket_start + 5
        ]
        if not bucket:
            continue
        summary = " ".join(str(item.get("text", "")) for item in bucket[:4]).strip()
        chapters.append({
            "start_minute": bucket_start,
            "end_minute": bucket_start + 5,
            "title": f"{bucket_start}~{bucket_start + 5}분 핵심",
            "summary": summary[:450],
        })
    return chapters


def _segments_from_transcript_text(transcript_text: str) -> list[dict[str, Any]]:
    lines = [
        re.sub(r"\s+", " ", line.strip())
        for line in (transcript_text or "").splitlines()
        if line.strip()
    ]
    if not lines:
        return []

    segments: list[dict[str, Any]] = []
    current_minute = 0
    for index in range(0, len(lines), 4):
        chunk = " ".join(lines[index:index + 4]).strip()
        if not chunk:
            continue
        minute_match = re.search(r"(\d{1,3})\s*(?:분|:)", chunk)
        start = int(minute_match.group(1)) if minute_match else current_minute
        end = max(start + 1, start + 5)
        segments.append({
            "start_minute": start,
            "end_minute": end,
            "text": chunk[:900],
        })
        current_minute = end
    return segments[:180]


class VideoPipeline:
    async def summarize_transcript_text(
        self,
        *,
        transcript_text: str,
        title: str,
        original_text: str,
        core_points: list[dict],
    ) -> dict[str, Any]:
        segments = _segments_from_transcript_text(transcript_text)
        if not transcript_text.strip():
            return _fallback_video_analysis(original_text, core_points)
        try:
            return await self._summarize_transcript(
                transcript_text=transcript_text[:18000],
                segments=segments,
                title=title,
                original_text=original_text,
                core_points=core_points,
                source="transcript",
            )
        except Exception as e:
            logger.warning(f"[VideoPipeline] 대본 요약 실패 — 로컬 요약 폴백: {e}")
            return summarize_transcript_locally(
                transcript_text=transcript_text,
                title=title,
                original_text=original_text,
                core_points=core_points,
                reason=str(e)[:240],
            )

    async def transcribe_uploaded_video(
        self,
        *,
        video_bytes: bytes,
        filename: str,
        mime_type: str,
        title: str,
        original_text: str,
        core_points: list[dict],
    ) -> dict[str, Any]:
        """Transcribe and summarize an uploaded video using Gemini File API."""
        if not video_bytes:
            return _fallback_video_analysis(original_text, core_points)
        if not os.getenv("GEMINI_API_KEY"):
            raise RuntimeError("GEMINI_API_KEY가 설정되지 않았습니다.")

        suffix = Path(filename or "lecture.mp4").suffix or ".mp4"
        temp_path = ""
        uploaded = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp:
                temp.write(video_bytes)
                temp_path = temp.name

            _vp_client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
            uploaded = await asyncio.to_thread(
                _vp_client.files.upload,
                file=temp_path,
                config=types.UploadFileConfig(
                    mime_type=mime_type or "video/mp4",
                    display_name=filename or title or "lecture-video",
                ),
            )
            uploaded = await self._wait_until_ready(uploaded, _vp_client)

            core_text = "\n".join(
                f"- {point.get('content', '')}"
                for point in core_points[:10]
                if point.get("content")
            )
            prompt = f"""당신은 강의 영상 전사와 학습 요약을 담당하는 교육 AI입니다.
아래 업로드 영상을 분석하되, 원본 교안과 교수 핵심 포인트를 함께 근거로 삼으세요.
한국어로만 작성하고, 영상에서 확인되지 않는 내용은 추정하지 마세요.
코드/실습 장면이 있으면 가능한 한 그대로 보존하고, 시간이 불확실하면 start_minute/end_minute를 0으로 두세요.

[강의 제목]
{title}

[교수 핵심 포인트]
{core_text}

[원본 교안 일부]
{original_text[:3500]}

반드시 아래 JSON만 출력하세요.
{{
  "transcript": "영상 전체 전사 또는 구간별 핵심 발화 요약",
  "segments": [
    {{"start_minute": 0, "end_minute": 5, "text": "해당 구간의 실제 설명 또는 확인 가능한 내용"}}
  ],
  "chapters": [
    {{"start_minute": 0, "end_minute": 5, "title": "챕터 제목", "summary": "학습 요약"}}
  ],
  "summary_markdown": "## 영상 요약\\n- 핵심 요지\\n- 실습 흐름\\n- 주의점",
  "key_moments": [
    {{"minute": 0, "label": "학생이 다시 보면 좋은 지점", "reason": "이유"}}
  ],
  "study_tips": [
    "핵심 개념을 암기하기보다는 원리를 이해하세요.",
    "실습 코드를 직접 타이핑하며 에러를 겪어보는 것이 중요합니다."
  ],
  "stuck_points": [
    {{"minute": 10, "topic": "주제", "reason": "이유"}}
  ]
}}"""
            raw = await generate_gemini_text(
                [uploaded, prompt],
                temperature=0.15,
                max_output_tokens=2600,
                timeout=95.0,
                feature="video_transcription",
            )
            parsed = _json_from_markdown(raw)
            return self._normalize_result(parsed)
        finally:
            if uploaded is not None:
                try:
                    await asyncio.to_thread(_vp_client.files.delete, name=uploaded.name)
                except Exception as e:
                    logger.info(f"[VideoPipeline] Gemini 파일 삭제 스킵: {e}")
            if temp_path:
                try:
                    os.unlink(temp_path)
                except OSError:
                    pass

    async def _wait_until_ready(self, uploaded, client: genai.Client):
        name = uploaded.name
        for _ in range(300):
            state = getattr(getattr(uploaded, "state", None), "name", "")
            if state in ("ACTIVE", "SUCCEEDED", ""):
                return uploaded
            if state == "FAILED":
                raise RuntimeError("Gemini File API 영상 처리 실패")
            await asyncio.sleep(2)
            uploaded = await asyncio.to_thread(client.files.get, name=name)
        raise TimeoutError("Gemini File API 영상 처리 대기 시간 초과")

    async def _summarize_transcript(
        self,
        *,
        transcript_text: str,
        segments: list[dict[str, Any]],
        title: str,
        original_text: str,
        core_points: list[dict],
        source: str,
    ) -> dict[str, Any]:
        core_text = "\n".join(
            f"- {point.get('content', '')}"
            for point in core_points[:10]
            if point.get("content")
        )
        prompt = f"""당신은 온라인 강의 전사 기반 요약 전문가입니다.
아래 {source} 대본과 교수 핵심 포인트, 원본 교안을 근거로 학생용 영상 요약을 만드세요.
전사에 없는 내용을 꾸며내지 말고, 코드/실습 흐름은 가능한 한 단계별로 보존하세요.
한국어로만 작성하고 JSON만 출력하세요.

[강의 제목]
{title}

[교수 핵심 포인트]
{core_text}

[원본 교안 일부]
{original_text[:3000]}

[영상 대본]
{transcript_text}

{{
  "transcript": "정리된 전체 전사",
  "segments": [
    {{"start_minute": 0, "end_minute": 5, "text": "구간 내용"}}
  ],
  "chapters": [
    {{"start_minute": 0, "end_minute": 5, "title": "챕터 제목", "summary": "요약"}}
  ],
  "summary_markdown": "## 영상 요약\\n- 핵심 요지\\n- 실습 흐름\\n- 다시 볼 구간",
  "key_moments": [
    {{"minute": 0, "label": "다시 볼 지점", "reason": "이유"}}
  ],
  "study_tips": ["핵심 로직 이해", "실습 결과 확인"],
  "stuck_points": [
    {{"minute": 5, "topic": "주제", "reason": "이유"}}
  ]
}}"""
        raw = await generate_gemini_text(
            prompt,
            temperature=0.18,
            max_output_tokens=2600,
            timeout=45.0,
            feature=f"video_{source}_summary",
        )
        parsed = _json_from_markdown(raw)
        if not parsed.get("segments"):
            parsed["segments"] = segments[:180]
        if not parsed.get("transcript"):
            parsed["transcript"] = transcript_text
        return self._normalize_result(parsed)

    @staticmethod
    def _normalize_result(parsed: dict[str, Any]) -> dict[str, Any]:
        return {
            "transcript": str(parsed.get("transcript", "")).strip(),
            "segments": parsed.get("segments") or [],
            "chapters": parsed.get("chapters") or [],
            "summary_markdown": str(parsed.get("summary_markdown", "")).strip(),
            "key_moments": parsed.get("key_moments") or [],
            "study_tips": parsed.get("study_tips") or [],
            "stuck_points": parsed.get("stuck_points") or [],
        }
