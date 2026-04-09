"""
파일 파싱 서비스 — PDF, PPT/PPTX, DOCX, MD 텍스트 추출
"""
import io
from typing import Optional


class FileService:
    SUPPORTED = {"pdf", "ppt", "pptx", "docx", "md", "txt", "hwp", "hwpx"}

    async def extract_text(self, file_bytes: bytes, filename: str) -> str:
        ext = filename.lower().rsplit(".", 1)[-1]
        if ext not in self.SUPPORTED:
            raise ValueError(f"지원하지 않는 파일 형식입니다: .{ext}")

        if ext == "pdf":
            return self._from_pdf(file_bytes)
        elif ext in ("ppt", "pptx"):
            return self._from_pptx(file_bytes)
        elif ext == "docx":
            return self._from_docx(file_bytes)
        elif ext in ("hwp", "hwpx"):
            return self._from_hwp(file_bytes)
        elif ext in ("md", "txt"):
            return file_bytes.decode("utf-8", errors="ignore")

        return ""

    def _from_pdf(self, data: bytes) -> str:
        try:
            import PyPDF2
            reader = PyPDF2.PdfReader(io.BytesIO(data))
            pages = [page.extract_text() or "" for page in reader.pages]
            return "\n\n".join(p.strip() for p in pages if p.strip())
        except ImportError:
            return "[PDF 파싱 실패: PyPDF2 미설치]"

    def _from_pptx(self, data: bytes) -> str:
        try:
            from pptx import Presentation
            prs = Presentation(io.BytesIO(data))
            slides_text: list[str] = []
            for i, slide in enumerate(prs.slides, 1):
                texts: list[str] = []
                for shape in slide.shapes:
                    if hasattr(shape, "text") and shape.text.strip():
                        texts.append(shape.text.strip())
                if texts:
                    slides_text.append(f"[슬라이드 {i}]\n" + "\n".join(texts))
            return "\n\n".join(slides_text)
        except ImportError:
            return "[PPTX 파싱 실패: python-pptx 미설치]"

    def _from_docx(self, data: bytes) -> str:
        try:
            from docx import Document
            doc = Document(io.BytesIO(data))
            paragraphs = [p.text.strip() for p in doc.paragraphs if p.text.strip()]
            return "\n\n".join(paragraphs)
        except ImportError:
            return "[DOCX 파싱 실패: python-docx 미설치]"

    def _from_hwp(self, data: bytes) -> str:
        """한글 HWP/HWPX 파싱 — olefile 기반 텍스트 추출"""
        # HWPX는 ZIP 기반이라 XML 추출 시도
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

        # HWP 바이너리 — olefile 기반
        try:
            import olefile
            ole = olefile.OleFileIO(io.BytesIO(data))
            if ole.exists("BodyText/Section0"):
                raw = ole.openstream("BodyText/Section0").read()
                # 한글 텍스트 추출 (간단 디코딩)
                text_parts: list[str] = []
                i = 0
                while i < len(raw) - 1:
                    ch = (raw[i+1] << 8) | raw[i]
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
