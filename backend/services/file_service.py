"""
파일 파싱 서비스 — PDF, PPT/PPTX, DOCX, MD 텍스트 추출
PPT/PDF 내 이미지(코드 스크린샷 등) → Gemini Vision OCR로 추출
"""
import asyncio
import base64
import io
import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)


class FileService:
    SUPPORTED = {"pdf", "ppt", "pptx", "docx", "md", "txt", "hwp", "hwpx",
                 "py", "js", "ts", "java", "c", "cpp", "cs", "go", "rs", "kt", "swift",
                 "jpg", "jpeg", "png", "webp", "csv", "json", "xml"}

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
            return await self._ocr_image_bytes(file_bytes, ext)
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
                text = page.extract_text() or ""
                text = text.strip()

                # 이미지 기반 페이지(텍스트 추출 결과가 빈 경우) → Vision OCR
                if not text or len(text) < 30:
                    try:
                        img_text = await self._ocr_pdf_page(data, i - 1)
                        if img_text:
                            text = f"[이미지 OCR] {img_text}"
                    except Exception as e:
                        logger.warning(f"[FileService] PDF 페이지 {i} OCR 실패: {e}")

                if text:
                    pages_text.append(f"[페이지 {i}]\n{text}")

            return "\n\n".join(pages_text)
        except ImportError:
            return "[PDF 파싱 실패: PyPDF2 미설치]"

    async def _ocr_pdf_page(self, pdf_bytes: bytes, page_index: int) -> str:
        """PDF 특정 페이지를 이미지로 변환 후 Vision OCR"""
        try:
            import fitz  # PyMuPDF
            doc = fitz.open(stream=pdf_bytes, filetype="pdf")
            page = doc.load_page(page_index)
            pix = page.get_pixmap(dpi=150)
            img_bytes = pix.tobytes("png")
            return await self._ocr_image_bytes(img_bytes, "png")
        except ImportError:
            logger.debug("[FileService] PyMuPDF 미설치 — PDF 이미지 OCR 건너뜀")
            return ""

    # ── PPT/PPTX ────────────────────────────────────────────────────────────
    async def _from_pptx(self, data: bytes) -> str:
        try:
            from pptx import Presentation
            from pptx.util import Inches
            prs = Presentation(io.BytesIO(data))
            slides_text: list[str] = []

            for i, slide in enumerate(prs.slides, 1):
                texts: list[str] = []
                image_parts: list[bytes] = []

                for shape in slide.shapes:
                    # 텍스트 추출
                    if hasattr(shape, "text") and shape.text.strip():
                        texts.append(shape.text.strip())

                    # 이미지 추출 (코드 스크린샷 등)
                    if shape.shape_type == 13:  # MSO_SHAPE_TYPE.PICTURE
                        try:
                            img_bytes = shape.image.blob
                            image_parts.append(img_bytes)
                        except Exception:
                            pass

                slide_parts: list[str] = []
                if texts:
                    slide_parts.append("\n".join(texts))

                # 이미지 Vision OCR (병렬)
                if image_parts:
                    ocr_tasks = [
                        self._ocr_image_bytes(img, "png")
                        for img in image_parts
                    ]
                    ocr_results = await asyncio.gather(*ocr_tasks, return_exceptions=True)
                    for j, result in enumerate(ocr_results):
                        if isinstance(result, str) and result.strip():
                            slide_parts.append(f"[이미지 {j+1} OCR]\n{result.strip()}")
                        elif isinstance(result, Exception):
                            logger.warning(f"[FileService] 슬라이드 {i} 이미지 {j+1} OCR 실패: {result}")

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
        """한글 HWP/HWPX 파싱 — olefile 기반 텍스트 추출"""
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

        return "[HWP 파일 텍스트 추출 실패 — 다른 형식으로 변환 후 업로드해주세요]"

    # ── Gemini Vision OCR ────────────────────────────────────────────────────
    async def _ocr_image_bytes(self, image_bytes: bytes, ext: str = "png") -> str:
        """
        Gemini Vision으로 이미지 내 텍스트(코드 포함) OCR 추출
        코드 스크린샷이면 코드블록 형식으로 반환
        """
        try:
            import google.generativeai as genai
            api_key = os.environ.get("GEMINI_API_KEY")
            if not api_key:
                return ""

            genai.configure(api_key=api_key, transport="rest")
            model = genai.GenerativeModel("gemini-2.0-flash")

            mime_map = {"jpg": "image/jpeg", "jpeg": "image/jpeg",
                        "png": "image/png", "webp": "image/webp"}
            mime_type = mime_map.get(ext.lower(), "image/png")

            image_part = {
                "inline_data": {
                    "mime_type": mime_type,
                    "data": base64.b64encode(image_bytes).decode("utf-8"),
                }
            }

            prompt = """이 이미지에서 모든 텍스트를 추출하세요.
규칙:
1. 코드가 있으면 ```언어\n코드\n``` 형식으로 감싸서 정확하게 추출하세요.
2. 코드 들여쓰기와 구문을 100% 정확하게 보존하세요.
3. 일반 텍스트, 제목, 설명도 모두 추출하세요.
4. 이미지에 텍스트가 없으면 빈 문자열을 반환하세요.
5. OCR 결과만 출력하고 부가 설명은 쓰지 마세요."""

            response = await asyncio.wait_for(
                asyncio.to_thread(model.generate_content, [prompt, image_part]),
                timeout=20.0,
            )
            return response.text.strip()

        except asyncio.TimeoutError:
            logger.warning("[FileService] Vision OCR 타임아웃 (20s)")
            return ""
        except Exception as e:
            logger.warning(f"[FileService] Vision OCR 실패: {e}")
            return ""
