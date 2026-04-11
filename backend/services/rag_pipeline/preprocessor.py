"""
논문 지식베이스 벡터화 — 서버 시작 시 1회 로드 후 메모리 캐싱

google-genai 신 SDK의 client.models.embed_content() REST API를 사용.
"""
import asyncio
import logging
import os
from typing import List

from google import genai
from google.genai import types
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import FAISS

from .knowledge_base import PAPER_CHUNKS

logger = logging.getLogger(__name__)

_store: FAISS | None = None  # 서버 전체 공유 싱글톤


class _RestEmbeddings:
    """client.models.embed_content() REST 기반 임베딩 — gRPC 없이 동작"""

    def __init__(self, client: genai.Client, model: str = "models/text-embedding-004"):
        self._client = client
        self.model = model

    def embed_documents(self, texts: List[str]) -> List[List[float]]:
        result = self._client.models.embed_content(
            model=self.model,
            contents=texts,
            config=types.EmbedContentConfig(task_type="RETRIEVAL_DOCUMENT"),
        )
        return [e.values for e in result.embeddings]

    def embed_query(self, text: str) -> List[float]:
        result = self._client.models.embed_content(
            model=self.model,
            contents=text,
            config=types.EmbedContentConfig(task_type="RETRIEVAL_QUERY"),
        )
        return result.embeddings[0].values


class PaperVectorStore:
    """논문 청크를 임베딩하여 FAISS에 저장 — 앱 시작 시 초기화"""

    @staticmethod
    async def initialize() -> None:
        global _store
        if _store is not None:
            return  # 이미 초기화됨

        api_key = os.environ.get("GEMINI_API_KEY", "")
        if not api_key:
            logger.warning("[RAG] GEMINI_API_KEY 미설정 — RAG 비활성화")
            return

        client = genai.Client(api_key=api_key)

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

        embeddings = _RestEmbeddings(client)
        _store = await asyncio.to_thread(
            FAISS.from_texts, texts, embeddings, metadatas=metadatas
        )
        logger.info(f"[RAG] 벡터화 완료: {len(texts)}개 청크")

    @staticmethod
    def get_store() -> FAISS | None:
        return _store
