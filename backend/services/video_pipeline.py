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
from urllib.parse import parse_qs, urlparse

import google.generativeai as genai

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
    }


class VideoPipeline:
    async def transcribe_youtube_url(
        self,
        *,
        video_url: str,
        title: str,
        original_text: str,
        core_points: list[dict],
    ) -> dict[str, Any]:
        """Fetch YouTube captions and summarize them for grounded segment Q&A."""
        video_id = self._youtube_id(video_url)
        if not video_id:
            raise ValueError("유효한 YouTube 영상 URL이 아닙니다.")

        def _fetch():
            from youtube_transcript_api import YouTubeTranscriptApi

            try:
                return YouTubeTranscriptApi.get_transcript(video_id, languages=["ko", "en"])
            except Exception:
                transcripts = YouTubeTranscriptApi.list_transcripts(video_id)
                transcript = transcripts.find_transcript(["ko", "en"])
                return transcript.fetch()

        rows = await asyncio.to_thread(_fetch)
        if not rows:
            raise RuntimeError("YouTube 자막/전사를 찾을 수 없습니다.")

        segments = [
            {
                "start_minute": max(0, int(float(row.get("start", 0)) // 60)),
                "end_minute": max(0, int((float(row.get("start", 0)) + float(row.get("duration", 0))) // 60) + 1),
                "text": str(row.get("text", "")).replace("\n", " ").strip(),
            }
            for row in rows
            if str(row.get("text", "")).strip()
        ]
        transcript_text = "\n".join(
            f"[{item['start_minute']}~{item['end_minute']}분] {item['text']}"
            for item in segments
        )
        return await self._summarize_transcript(
            transcript_text=transcript_text[:14000],
            segments=segments,
            title=title,
            original_text=original_text,
            core_points=core_points,
            source="youtube",
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

            genai.configure(api_key=os.getenv("GEMINI_API_KEY"), transport="rest")
            uploaded = await asyncio.to_thread(
                genai.upload_file,
                path=temp_path,
                mime_type=mime_type or "video/mp4",
                display_name=filename or title or "lecture-video",
            )
            uploaded = await self._wait_until_ready(uploaded)

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
                    await asyncio.to_thread(genai.delete_file, uploaded.name)
                except Exception as e:
                    logger.info(f"[VideoPipeline] Gemini 파일 삭제 스킵: {e}")
            if temp_path:
                try:
                    os.unlink(temp_path)
                except OSError:
                    pass

    async def _wait_until_ready(self, uploaded):
        name = uploaded.name
        for _ in range(45):
            state = getattr(getattr(uploaded, "state", None), "name", "")
            if state in ("ACTIVE", "SUCCEEDED", ""):
                return uploaded
            if state == "FAILED":
                raise RuntimeError("Gemini File API 영상 처리 실패")
            await asyncio.sleep(2)
            uploaded = await asyncio.to_thread(genai.get_file, name)
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
아래 {source} 전사와 교수 핵심 포인트, 원본 교안을 근거로 학생용 영상 요약을 만드세요.
전사에 없는 내용을 꾸며내지 말고, 코드/실습 흐름은 가능한 한 단계별로 보존하세요.
한국어로만 작성하고 JSON만 출력하세요.

[강의 제목]
{title}

[교수 핵심 포인트]
{core_text}

[원본 교안 일부]
{original_text[:3000]}

[영상 전사]
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
        }

    @staticmethod
    def _youtube_id(url: str) -> str:
        parsed = urlparse(url or "")
        host = parsed.netloc.lower()
        if "youtu.be" in host:
            return parsed.path.strip("/").split("/")[0]
        if "youtube.com" in host:
            if parsed.path.startswith("/shorts/") or parsed.path.startswith("/embed/"):
                return parsed.path.strip("/").split("/")[1]
            return parse_qs(parsed.query).get("v", [""])[0]
        return ""
