"""
파일 파싱 서비스 — PDF, PPT/PPTX, DOCX, MD 텍스트 추출
이미지 내 코드 스크린샷 / 시각 자료 → Gemini Vision으로 2단계 처리
"""
import asyncio
import base64
import io
import logging
import os

logger = logging.getLogger(__name__)


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

                # 텍스트가 거의 없는 경우 → 이미지 페이지로 판단 → Vision 분석
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
        """PDF 페이지를 PNG로 렌더링 → Vision 분석"""
        try:
            import fitz  # PyMuPDF
            doc = fitz.open(stream=pdf_bytes, filetype="pdf")
            page = doc.load_page(page_index)
            pix = page.get_pixmap(dpi=180)  # 고해상도로 렌더링
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
                    # 텍스트 박스 / 테이블 추출
                    if hasattr(shape, "text") and shape.text.strip():
                        texts.append(shape.text.strip())

                    # 모든 이미지 형태 추출
                    # shape_type 13 = PICTURE, shape_type 14 = LINKED_PICTURE
                    if shape.shape_type in (13, 14):
                        try:
                            image_blobs.append(shape.image.blob)
                        except Exception:
                            pass

                slide_parts: list[str] = []
                if texts:
                    slide_parts.append("\n".join(texts))

                # 이미지 병렬 Vision 분석
                if image_blobs:
                    ocr_tasks = [self._analyze_image(blob) for blob in image_blobs]
                    ocr_results = await asyncio.gather(*ocr_tasks, return_exceptions=True)
                    for j, result in enumerate(ocr_results):
                        if isinstance(result, str) and result.strip():
                            slide_parts.append(f"[슬라이드 이미지 {j+1}]\n{result.strip()}")
                        elif isinstance(result, Exception):
                            logger.warning(f"[FileService] Slide {i} img {j+1} Vision 실패: {result}")

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

    # ── Gemini Vision 2단계 분석 (핵심) ─────────────────────────────────────
    async def _analyze_image(self, image_bytes: bytes, ext: str = "png") -> str:
        """
        이미지를 Gemini Vision으로 분석:
        1단계: 이미지 유형 판단 (코드 / 다이어그램·차트 / 일반 텍스트)
        2단계: 유형에 맞는 추출

        - 코드 스크린샷 → 코드블록으로 100% 정확하게 추출 (들여쓰기 보존)
        - 다이어그램/흐름도/차트 → 구성요소와 관계를 텍스트로 서술
        - 일반 텍스트/슬라이드 → 전체 텍스트 추출
        """
        try:
            import google.generativeai as genai
            api_key = os.environ.get("GEMINI_API_KEY")
            if not api_key:
                return ""

            genai.configure(api_key=api_key, transport="rest")
            model = genai.GenerativeModel("gemini-2.0-flash")

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

            prompt = """이 이미지를 분석하여 학습 교안에 사용할 수 있도록 정확하게 변환하세요.

[판단 기준 및 처리 방법]

1. **코드 스크린샷** (프로그래밍 코드, 터미널 출력, 명령어):
   - 코드를 100% 정확하게 추출하세요. 들여쓰기, 공백, 특수문자 모두 보존.
   - 언어를 감지하여 적절한 코드블록으로 감싸세요.
   - 형식: ```python\n코드\n```
   - 주석과 줄 번호도 포함하세요.

2. **다이어그램 / 흐름도 / 아키텍처 도식**:
   - 구성 요소와 연결 관계를 단계별로 텍스트로 서술하세요.
   - 화살표 방향, 레이블, 박스 내 텍스트를 모두 포함하세요.
   - 형식: [다이어그램 설명] → 단계별 설명 텍스트

3. **수식 / 공식**:
   - 수식을 텍스트로 정확하게 표현하세요.
   - 형식: `수식 표현`

4. **표 / 비교 자료**:
   - 마크다운 표 형식으로 변환하세요.

5. **일반 슬라이드 / 텍스트 이미지**:
   - 모든 텍스트를 순서대로 추출하세요.

출력 규칙:
- 이미지에 내용이 없으면 빈 문자열만 반환하세요.
- 설명이나 부가 코멘트 없이 변환 결과만 출력하세요.
- 반드시 한국어 설명을 유지하고, 코드는 원어 그대로 보존하세요."""

            response = await asyncio.wait_for(
                asyncio.to_thread(model.generate_content, [prompt, image_part]),
                timeout=25.0,
            )
            result = response.text.strip()
            # 빈 응답 필터링
            if result.lower() in ("", "없음", "none", "n/a"):
                return ""
            return result

        except asyncio.TimeoutError:
            logger.warning("[FileService] Vision OCR 타임아웃 (25s)")
            return ""
        except Exception as e:
            logger.warning(f"[FileService] Vision OCR 실패: {e}")
            return ""
