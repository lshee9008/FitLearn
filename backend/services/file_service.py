"""
파일 파싱 서비스 — PDF, PPT/PPTX, DOCX, MD 텍스트 추출
이미지 내 코드 스크린샷 / 시각 자료 → Gemini Vision 순차 처리(세마포어)
429 시 지수 백오프 재시도, 모델 폴백
"""
import asyncio
import base64
import io
import logging
import os
import time



logger = logging.getLogger(__name__)

# Vision OCR 동시 실행 제한 (429 방지 — RPM 15 제한 대응을 위해 1로 순차 처리)
_VISION_SEMAPHORE = asyncio.Semaphore(1)

# 업로드 요청은 교수가 화면에서 기다리는 구간이므로 Vision OCR은 짧게만 시도한다.
# 전체 이미지 보존은 별도 백그라운드 파이프라인으로 확장하는 것이 안전하다.
_MAX_IMAGES_PER_PAGE = int(os.getenv("FITLEARN_MAX_IMAGES_PER_PAGE", "4"))
_MAX_IMAGES_PER_SLIDE = int(os.getenv("FITLEARN_MAX_IMAGES_PER_SLIDE", "4"))
_MAX_PDF_VISION_PAGES = int(os.getenv("FITLEARN_MAX_PDF_VISION_PAGES", "8"))
_VISION_TIMEOUT_SECONDS = float(os.getenv("FITLEARN_VISION_TIMEOUT_SECONDS", "20"))
_VISION_RETRIES = int(os.getenv("FITLEARN_VISION_RETRIES", "1"))
_VISION_QUOTA_COOLDOWN_SECONDS = int(os.getenv("FITLEARN_VISION_QUOTA_COOLDOWN_SECONDS", "75"))
_VISION_QUOTA_COOLDOWN_UNTIL = 0.0

# Vision OCR 모델 폴백 순서
_VISION_MODELS = [
    "gemini-2.5-flash-lite",  # 가장 빠른 OCR 후보
    "gemini-2.5-flash",       # 품질 폴백
    "gemini-2.0-flash",       # 이전 세대 폴백
]


class FileService:
    SUPPORTED = {
        "pdf", "ppt", "pptx", "docx", "md", "txt", "hwp", "hwpx",
        "py", "js", "ts", "java", "c", "cpp", "cs", "go", "rs", "kt", "swift",
        "jpg", "jpeg", "png", "webp", "csv", "json", "xml",
    }

    async def extract_text(self, file_bytes: bytes, filename: str) -> str:
        ext = filename.lower().rsplit(".", 1)[-1]
        if ext not in self.SUPPORTED:
            raise ValueError(f"지원하지 않는 파일 형식입니다: .{ext}")

        if ext == "pdf":
            return await self._from_pdf(file_bytes)
        elif ext in ("ppt", "pptx"):
            return await self._from_pptx(file_bytes)
        elif ext == "docx":
            return await self._from_docx_async(file_bytes)
        elif ext in ("hwp", "hwpx"):
            return self._from_hwp(file_bytes)
        elif ext in ("md", "txt"):
            return file_bytes.decode("utf-8", errors="ignore")
        elif ext in ("jpg", "jpeg", "png", "webp"):
            return await self._analyze_image(file_bytes)
        elif ext in ("py", "js", "ts", "java", "c", "cpp", "cs", "go", "rs", "kt", "swift"):
            return file_bytes.decode("utf-8", errors="ignore")
        elif ext in ("csv", "json", "xml"):
            return file_bytes.decode("utf-8", errors="ignore")[:8000]
        return ""

    # ── PDF ──────────────────────────────────────────────────────────────────
    async def _from_pdf(self, data: bytes) -> str:
        # 1차: pdfplumber (레이아웃 보존 + 표 추출)
        try:
            import pdfplumber
            pages_text: list[str] = []
            vision_pages_used = 0
            with pdfplumber.open(io.BytesIO(data)) as pdf:
                for i, page in enumerate(pdf.pages, 1):
                    parts: list[str] = []

                    text = (page.extract_text(x_tolerance=2, y_tolerance=3) or "").strip()
                    if text:
                        parts.append(text)

                    # 표 추출 → 마크다운 변환
                    for table in page.extract_tables():
                        if not table:
                            continue
                        rows = []
                        for j, row in enumerate(table):
                            cells = [str(c or "").strip() for c in row]
                            rows.append("| " + " | ".join(cells) + " |")
                            if j == 0:
                                rows.append("| " + " | ".join(["---"] * len(cells)) + " |")
                        parts.append("\n".join(rows))

                    combined = "\n\n".join(parts).strip()

                    # 텍스트가 거의 없는 페이지 또는 이미지/도식이 포함된 페이지 → Vision 분석
                    has_visuals = bool(getattr(page, "images", None))
                    should_try_vision = (
                        len(combined) < 40
                        or (has_visuals and vision_pages_used < _MAX_PDF_VISION_PAGES)
                    )
                    if should_try_vision:
                        try:
                            vision_pages_used += 1
                            vision_text = await self._pdf_page_to_vision(data, i - 1)
                            if vision_text:
                                combined = (
                                    f"{combined}\n\n[페이지 {i} 시각자료/코드 캡처]\n{vision_text}"
                                    if combined else vision_text
                                )
                            elif has_visuals:
                                combined = (
                                    f"{combined}\n\n[페이지 {i} 시각자료]\n이 페이지에는 이미지·도식·코드 캡처가 포함되어 있으나 OCR 결과가 비어 있습니다. 재해석 시 원본 파일과 함께 확인하세요."
                                    if combined else f"[페이지 {i} 시각자료]\n이미지·도식·코드 캡처가 포함되어 있으나 OCR 결과가 비어 있습니다. 원본 파일 확인이 필요합니다."
                                )
                        except Exception as e:
                            logger.warning(f"[FileService] PDF p.{i} Vision 실패: {e}")

                    if combined:
                        pages_text.append(f"[페이지 {i}]\n{combined}")

            return "\n\n".join(pages_text)

        except ImportError:
            logger.debug("[FileService] pdfplumber 미설치 — PyPDF2 폴백")

        # 2차 폴백: PyPDF2
        try:
            import PyPDF2
            reader = PyPDF2.PdfReader(io.BytesIO(data))
            pages_text = []
            vision_pages_used = 0
            for i, page in enumerate(reader.pages, 1):
                text = (page.extract_text() or "").strip()
                if len(text) < 40 and vision_pages_used < _MAX_PDF_VISION_PAGES:
                    try:
                        vision_pages_used += 1
                        vision_text = await self._pdf_page_to_vision(data, i - 1)
                        if vision_text:
                            text = vision_text
                        else:
                            text = f"[페이지 {i} 시각자료]\n이미지 기반 페이지로 보이나 OCR 결과가 비어 있습니다. 원본 파일 확인이 필요합니다."
                    except Exception as e:
                        logger.warning(f"[FileService] PDF p.{i} Vision 실패: {e}")
                if text:
                    pages_text.append(f"[페이지 {i}]\n{text}")
            return "\n\n".join(pages_text)
        except ImportError:
            return "[PDF 파싱 실패: pdfplumber·PyPDF2 미설치]"

    async def _pdf_page_to_vision(self, pdf_bytes: bytes, page_index: int) -> str:
        try:
            import fitz
            doc = fitz.open(stream=pdf_bytes, filetype="pdf")
            page = doc.load_page(page_index)
            pix = page.get_pixmap(dpi=150)
            img_bytes = pix.tobytes("png")
            return await self._analyze_image(img_bytes)
        except ImportError:
            logger.debug("[FileService] PyMuPDF 미설치 — PDF 이미지 OCR 건너뜀")
            return ""

    # ── PPT/PPTX ────────────────────────────────────────────────────────────
    async def _from_pptx(self, data: bytes) -> str:
        try:
            from pptx import Presentation
            prs = Presentation(io.BytesIO(data))
            slides_text: list[str] = []

            for i, slide in enumerate(prs.slides, 1):
                texts: list[str] = []
                image_blobs: list[bytes] = []

                for shape in slide.shapes:
                    if hasattr(shape, "text") and shape.text.strip():
                        texts.append(shape.text.strip())
                    if shape.shape_type in (13, 14):  # PICTURE / LINKED_PICTURE
                        try:
                            image_blobs.append(shape.image.blob)
                        except Exception:
                            pass

                slide_parts: list[str] = []
                if texts:
                    slide_parts.append("\n".join(texts))

                # 이미지 순차 처리 (세마포어로 동시 실행 제한, 슬라이드당 최대 4개)
                limited_blobs = image_blobs[:_MAX_IMAGES_PER_SLIDE]
                for j, blob in enumerate(limited_blobs):
                    result = await self._analyze_image(blob)
                    if result and result.strip():
                        slide_parts.append(f"[슬라이드 {i} 시각자료/코드 캡처 {j+1}]\n{result.strip()}")
                    else:
                        slide_parts.append(f"[슬라이드 {i} 시각자료 {j+1}]\n이미지·도식·코드 캡처가 포함되어 있으나 OCR 결과가 비어 있습니다. 원본 슬라이드와 함께 확인하세요.")
                    # 이미지 사이 짧은 대기 (API rate limit 보호)
                    if j < len(limited_blobs) - 1:
                        await asyncio.sleep(0.5)

                if slide_parts:
                    slides_text.append(f"[슬라이드 {i}]\n" + "\n\n".join(slide_parts))

            return "\n\n".join(slides_text)
        except ImportError:
            return "[PPTX 파싱 실패: python-pptx 미설치]"

    # ── DOCX ────────────────────────────────────────────────────────────────
    async def _from_docx_async(self, data: bytes) -> str:
        try:
            from docx import Document
            doc = Document(io.BytesIO(data))
            paragraphs = [p.text.strip() for p in doc.paragraphs if p.text.strip()]
            parts = ["\n\n".join(paragraphs)] if paragraphs else []

            image_blobs: list[bytes] = []
            try:
                for rel in doc.part.rels.values():
                    if "image" in rel.reltype:
                        image_blobs.append(rel.target_part.blob)
            except Exception as e:
                logger.debug(f"[FileService] DOCX 이미지 관계 추출 실패: {e}")

            for i, blob in enumerate(image_blobs[:_MAX_IMAGES_PER_PAGE], 1):
                result = await self._analyze_image(blob)
                if result and result.strip():
                    parts.append(f"[DOCX 시각자료/코드 캡처 {i}]\n{result.strip()}")
                else:
                    parts.append(f"[DOCX 시각자료 {i}]\n이미지·도식·코드 캡처가 포함되어 있으나 OCR 결과가 비어 있습니다. 원본 파일과 함께 확인하세요.")

            return "\n\n".join(part for part in parts if part.strip())
        except ImportError:
            return "[DOCX 파싱 실패: python-docx 미설치]"

    # ── HWP/HWPX ────────────────────────────────────────────────────────────
    def _from_hwp(self, data: bytes) -> str:
        try:
            import zipfile, xml.etree.ElementTree as ET
            with zipfile.ZipFile(io.BytesIO(data)) as z:
                texts: list[str] = []
                for name in z.namelist():
                    if name.endswith(".xml") and "Contents" in name:
                        with z.open(name) as f:
                            tree = ET.parse(f)
                            for elem in tree.iter():
                                if elem.text and elem.text.strip():
                                    texts.append(elem.text.strip())
                if texts:
                    return "\n".join(texts)
        except Exception:
            pass

        try:
            import olefile
            ole = olefile.OleFileIO(io.BytesIO(data))
            if ole.exists("BodyText/Section0"):
                raw = ole.openstream("BodyText/Section0").read()
                text_parts: list[str] = []
                i = 0
                while i < len(raw) - 1:
                    ch = (raw[i + 1] << 8) | raw[i]
                    if 0x20 <= ch <= 0xFFFF and ch not in (0x0D, 0x0A):
                        try:
                            text_parts.append(chr(ch))
                        except ValueError:
                            pass
                    elif ch in (0x0D, 0x0A):
                        text_parts.append("\n")
                    i += 2
                text = "".join(text_parts).strip()
                if text:
                    return text
        except Exception:
            pass

        return "[HWP 파일 텍스트 추출 실패]"

    # ── Gemini Vision OCR (세마포어 + 지수 백오프 + 모델 폴백) ───────────────
    async def _analyze_image(self, image_bytes: bytes, ext: str = "png") -> str:
        """
        이미지를 Gemini Vision으로 분석:
        - 코드 스크린샷 → 코드블록 정확 추출 (들여쓰기·공백 보존)
        - 다이어그램/차트 → 구성요소·관계 텍스트 서술
        - 표 → 마크다운 표 변환
        - 세마포어로 동시 호출 수 제한, 429 시 지수 백오프 재시도
        """
        async with _VISION_SEMAPHORE:
            return await self._analyze_image_inner(image_bytes, ext)

    async def _analyze_image_inner(self, image_bytes: bytes, ext: str = "png") -> str:
        import httpx

        api_key = os.environ.get("GEMINI_API_KEY")
        if not api_key:
            return ""

        global _VISION_QUOTA_COOLDOWN_UNTIL
        if time.monotonic() < _VISION_QUOTA_COOLDOWN_UNTIL:
            logger.info("[FileService] Vision quota cooldown 중 — 이미지 OCR 스킵")
            return ""

        mime_map = {
            "jpg": "image/jpeg", "jpeg": "image/jpeg",
            "png": "image/png", "webp": "image/webp",
        }
        mime_type = mime_map.get(ext.lower(), "image/png")
        b64_data = base64.b64encode(image_bytes).decode("utf-8")

        prompt = """이 이미지를 분석하여 학생이 수업 중 그대로 따라갈 수 있는 교안 재료로 정확하게 변환하세요.

[판단 기준 및 처리 방법]

1. **코드 스크린샷** (프로그래밍 코드, 터미널 출력, 명령어 등):
   - 코드를 100% 정확하게 추출. 들여쓰기, 공백, 특수문자, 주석, 줄 번호 모두 보존.
   - 코드가 잘려 있거나 흐릿하면 추측하지 말고 `[판독 불확실: ...]`로 표시.
   - 터미널 명령어와 출력은 각각 별도 코드블록으로 보존.
   - 언어 자동 감지 후 코드블록으로 감싸세요.
   - 형식: ```python\n코드 내용\n```

2. **다이어그램 / 흐름도 / 아키텍처 / 네트워크 도식**:
   - 박스·노드 내 텍스트, 화살표 방향, 연결 레이블을 단계별로 서술.
   - 가능하면 Mermaid가 아니라 일반 마크다운 목록으로 작성.
   - 형식: [시각자료]\n- 구성요소1 → 구성요소2 (설명)\n...

3. **수식 / 공식**:
   - 텍스트 수식으로 정확히 표현. 형식: `수식`

4. **표 / 비교 자료**:
   - 마크다운 표로 변환.

5. **일반 텍스트 슬라이드**:
   - 모든 텍스트 순서대로 추출.

출력 규칙:
- 이미지에 내용이 없으면 빈 문자열 반환.
- 설명·코멘트 없이 변환 결과만 출력.
- 원본 슬라이드의 텍스트, 코드, 그림 의미를 임의로 요약하지 말고 보존 중심으로 출력.
- 한국어 설명은 유지, 코드는 원어 그대로 보존."""

        body = {
            "contents": [{
                "role": "user",
                "parts": [
                    {"text": prompt},
                    {"inline_data": {"mime_type": mime_type, "data": b64_data}},
                ],
            }],
            "generationConfig": {
                "temperature": 0.1,
                "maxOutputTokens": 2048,
                "thinkingConfig": {"thinkingBudget": 0},
            },
        }

        # 모델 폴백 체인. 업로드 화면을 막지 않도록 429 장기 대기는 하지 않는다.
        for model_name in _VISION_MODELS:
            url = (
                f"https://generativelanguage.googleapis.com/v1beta/models"
                f"/{model_name}:generateContent?key={api_key}"
            )
            for attempt in range(_VISION_RETRIES):
                try:
                    async with httpx.AsyncClient(timeout=_VISION_TIMEOUT_SECONDS) as client:
                        resp = await client.post(url, json=body)

                    if resp.status_code == 429:
                        _VISION_QUOTA_COOLDOWN_UNTIL = time.monotonic() + _VISION_QUOTA_COOLDOWN_SECONDS
                        logger.warning(
                            f"[FileService] Vision 429 ({model_name} attempt {attempt+1}) — 업로드 지연 방지를 위해 스킵"
                        )
                        return ""

                    resp.raise_for_status()
                    data = resp.json()
                    result = data["candidates"][0]["content"]["parts"][0]["text"].strip()
                    if result.lower() in ("", "없음", "none", "n/a"):
                        return ""
                    return result

                except asyncio.TimeoutError:
                    logger.warning(f"[FileService] Vision OCR 타임아웃 ({model_name})")
                    break  # 타임아웃은 다음 모델로

                except Exception as e:
                    logger.warning(f"[FileService] Vision OCR 실패 ({model_name}): {e}")
                    break  # 다른 에러는 다음 모델로

        logger.error("[FileService] 모든 Vision 모델 실패 — 이미지 OCR 건너뜀")
        return ""