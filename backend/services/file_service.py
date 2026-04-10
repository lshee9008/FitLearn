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

# Vision OCR 동시 실행 제한 (429 방지 — 한 번에 최대 2개)
_VISION_SEMAPHORE = asyncio.Semaphore(2)

# 슬라이드당 처리할 최대 이미지 수 (너무 많으면 quota 소진)
_MAX_IMAGES_PER_SLIDE = 3

# Vision OCR 모델 폴백 순서
_VISION_MODELS = [
    "gemini-2.0-flash-lite",   # 가장 빠르고 quota 별도
    "gemini-1.5-flash-8b",     # 폴백 1
    "gemini-1.5-flash",        # 폴백 2
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
            return self._from_docx(file_bytes)
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
        try:
            import PyPDF2
            reader = PyPDF2.PdfReader(io.BytesIO(data))
            pages_text: list[str] = []

            for i, page in enumerate(reader.pages, 1):
                text = (page.extract_text() or "").strip()

                # 텍스트가 거의 없는 이미지 페이지 → Vision 분석 (순차)
                if len(text) < 40:
                    try:
                        vision_text = await self._pdf_page_to_vision(data, i - 1)
                        if vision_text:
                            text = vision_text
                    except Exception as e:
                        logger.warning(f"[FileService] PDF p.{i} Vision 실패: {e}")

                if text:
                    pages_text.append(f"[페이지 {i}]\n{text}")

            return "\n\n".join(pages_text)
        except ImportError:
            return "[PDF 파싱 실패: PyPDF2 미설치]"

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

                # 이미지 순차 처리 (세마포어로 동시 실행 제한, 슬라이드당 최대 3개)
                limited_blobs = image_blobs[:_MAX_IMAGES_PER_SLIDE]
                for j, blob in enumerate(limited_blobs):
                    result = await self._analyze_image(blob)
                    if result and result.strip():
                        slide_parts.append(f"[슬라이드 이미지 {j+1}]\n{result.strip()}")
                    # 이미지 사이 짧은 대기 (API rate limit 보호)
                    if j < len(limited_blobs) - 1:
                        await asyncio.sleep(0.5)

                if slide_parts:
                    slides_text.append(f"[슬라이드 {i}]\n" + "\n\n".join(slide_parts))

            return "\n\n".join(slides_text)
        except ImportError:
            return "[PPTX 파싱 실패: python-pptx 미설치]"

    # ── DOCX ────────────────────────────────────────────────────────────────
    def _from_docx(self, data: bytes) -> str:
        try:
            from docx import Document
            doc = Document(io.BytesIO(data))
            paragraphs = [p.text.strip() for p in doc.paragraphs if p.text.strip()]
            return "\n\n".join(paragraphs)
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
        try:
            import google.generativeai as genai
            api_key = os.environ.get("GEMINI_API_KEY")
            if not api_key:
                return ""

            genai.configure(api_key=api_key, transport="rest")

            mime_map = {
                "jpg": "image/jpeg", "jpeg": "image/jpeg",
                "png": "image/png", "webp": "image/webp",
            }
            mime_type = mime_map.get(ext.lower(), "image/png")

            image_part = {
                "inline_data": {
                    "mime_type": mime_type,
                    "data": base64.b64encode(image_bytes).decode("utf-8"),
                }
            }

            prompt = """이 이미지를 분석하여 학습 교안에 포함할 수 있는 형태로 정확하게 변환하세요.

[판단 기준 및 처리 방법]

1. **코드 스크린샷** (프로그래밍 코드, 터미널 출력, 명령어 등):
   - 코드를 100% 정확하게 추출. 들여쓰기, 공백, 특수문자, 주석, 줄 번호 모두 보존.
   - 언어 자동 감지 후 코드블록으로 감싸세요.
   - 형식: ```python\n코드 내용\n```

2. **다이어그램 / 흐름도 / 아키텍처 / 네트워크 도식**:
   - 박스·노드 내 텍스트, 화살표 방향, 연결 레이블을 단계별로 서술.
   - 형식: [다이어그램]\n- 구성요소1 → 구성요소2 (설명)\n...

3. **수식 / 공식**:
   - 텍스트 수식으로 정확히 표현. 형식: `수식`

4. **표 / 비교 자료**:
   - 마크다운 표로 변환.

5. **일반 텍스트 슬라이드**:
   - 모든 텍스트 순서대로 추출.

출력 규칙:
- 이미지에 내용이 없으면 빈 문자열 반환.
- 설명·코멘트 없이 변환 결과만 출력.
- 한국어 설명은 유지, 코드는 원어 그대로 보존."""

            # 모델 폴백 체인 + 429 지수 백오프
            for model_name in _VISION_MODELS:
                for attempt in range(3):
                    try:
                        model = genai.GenerativeModel(model_name)
                        response = await asyncio.wait_for(
                            asyncio.to_thread(model.generate_content, [prompt, image_part]),
                            timeout=25.0,
                        )
                        result = response.text.strip()
                        if result.lower() in ("", "없음", "none", "n/a"):
                            return ""
                        return result

                    except asyncio.TimeoutError:
                        logger.warning(f"[FileService] Vision OCR 타임아웃 ({model_name})")
                        break  # 타임아웃은 다음 모델로

                    except Exception as e:
                        err = str(e)
                        if "429" in err or "quota" in err.lower():
                            wait = (2 ** attempt) * 3  # 3s, 6s, 12s
                            logger.warning(
                                f"[FileService] Vision 429 ({model_name} attempt {attempt+1}) "
                                f"— {wait}s 대기 후 재시도"
                            )
                            await asyncio.sleep(wait)
                            if attempt == 2:
                                logger.warning(f"[FileService] {model_name} 재시도 소진 → 다음 모델")
                                break  # 다음 모델로
                        else:
                            logger.warning(f"[FileService] Vision OCR 실패 ({model_name}): {e}")
                            break  # 다른 에러는 다음 모델로

            logger.error("[FileService] 모든 Vision 모델 실패 — 이미지 OCR 건너뜀")
            return ""

        except Exception as e:
            logger.warning(f"[FileService] Vision OCR 전체 실패: {e}")
            return ""
