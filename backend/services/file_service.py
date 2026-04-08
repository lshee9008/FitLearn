"""
파일 파싱 서비스 — PDF, PPT/PPTX, DOCX, MD 텍스트 추출
"""
import io
from typing import Optional


class FileService:
    SUPPORTED = {"pdf", "ppt", "pptx", "docx", "md", "txt"}

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
