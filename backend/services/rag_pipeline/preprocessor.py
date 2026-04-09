"""
논문 지식베이스 벡터화 — 서버 시작 시 1회 로드 후 메모리 캐싱

langchain_google_genai의 GoogleGenerativeAIEmbeddings는 내부적으로 gRPC를 사용하여
Render 같은 환경에서 DNS 타임아웃이 발생. genai.embed_content() REST API를 직접
사용하는 커스텀 임베딩 클래스를 사용.
"""
import asyncio
import logging
import os
from typing import List

import google.generativeai as genai
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import FAISS

from .knowledge_base import PAPER_CHUNKS

logger = logging.getLogger(__name__)

_store: FAISS | None = None  # 서버 전체 공유 싱글톤


class _RestEmbeddings:
    """genai.embed_content() REST 기반 임베딩 — gRPC 없이 동작"""

    def __init__(self, model: str = "models/text-embedding-004"):
        self.model = model

    def embed_documents(self, texts: List[str]) -> List[List[float]]:
        result = genai.embed_content(
            model=self.model,
            content=texts,
            task_type="retrieval_document",
        )
        emb = result.get("embedding", [])
        # 단일 텍스트면 중첩 리스트로, 다중이면 그대로
        if emb and isinstance(emb[0], (int, float)):
            return [emb]
        return emb

    def embed_query(self, text: str) -> List[float]:
        result = genai.embed_content(
            model=self.model,
            content=text,
            task_type="retrieval_query",
        )
        return result["embedding"]


class PaperVectorStore:
    """논문 청크를 임베딩하여 FAISS에 저장 — 앱 시작 시 초기화"""

    @staticmethod
    async def initialize() -> None:
        global _store
        if _store is not None:
            return  # 이미 초기화됨

        genai.configure(api_key=os.environ["GEMINI_API_KEY"], transport="rest")

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

        embeddings = _RestEmbeddings()
        _store = await asyncio.to_thread(
            FAISS.from_texts, texts, embeddings, metadatas=metadatas
        )
        logger.info(f"[RAG] 벡터화 완료: {len(texts)}개 청크")

    @staticmethod
    def get_store() -> FAISS | None:
        return _store
