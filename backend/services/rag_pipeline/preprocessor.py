"""
논문 지식베이스 벡터화 — 서버 시작 시 1회 로드 후 메모리 캐싱
"""
import asyncio
import logging
import os

from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import FAISS
from langchain_google_genai import GoogleGenerativeAIEmbeddings

from .knowledge_base import PAPER_CHUNKS

logger = logging.getLogger(__name__)

_store: FAISS | None = None  # 서버 전체 공유 싱글톤


def _make_embeddings() -> GoogleGenerativeAIEmbeddings:
    return GoogleGenerativeAIEmbeddings(
        model="models/text-embedding-004",
        google_api_key=os.environ["GEMINI_API_KEY"],
        transport="rest",  # gRPC DNS 타임아웃 방지 (Render 호환)
    )


class PaperVectorStore:
    """논문 청크를 임베딩하여 FAISS에 저장 — 앱 시작 시 초기화"""

    @staticmethod
    async def initialize() -> None:
        global _store
        if _store is not None:
            return  # 이미 초기화됨

        logger.info("[RAG] 논문 지식베이스 벡터화 시작...")
        splitter = RecursiveCharacterTextSplitter(
            chunk_size=500, chunk_overlap=80
        )

        texts: list[str] = []
        metadatas: list[dict] = []

        for chunk in PAPER_CHUNKS:
            sub_chunks = splitter.split_text(chunk["content"])
            for sc in sub_chunks:
                texts.append(sc)
                metadatas.append({
                    "id": chunk["id"],
                    "paper": chunk["paper"],
                    "title": chunk["title"],
                })

        embeddings = _make_embeddings()
        _store = await asyncio.to_thread(
            FAISS.from_texts, texts, embeddings, metadatas=metadatas
        )
        logger.info(f"[RAG] 벡터화 완료: {len(texts)}개 청크")

    @staticmethod
    def get_store() -> FAISS | None:
        return _store
