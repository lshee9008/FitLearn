"""
RAG 파이프라인: 교안 벡터화 → 유사 청크 검색 → 재가공 컨텍스트 주입
"""
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import FAISS
from langchain_anthropic import AnthropicEmbeddings


class RAGService:
    def __init__(self):
        self.splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)
        self.vectorstore = None

    async def ingest(self, lecture_content: str) -> None:
        """교안을 청크로 분할 후 벡터 저장소에 인덱싱"""
        chunks = self.splitter.split_text(lecture_content)
        # TODO: 실제 임베딩 모델 연결
        # self.vectorstore = FAISS.from_texts(chunks, embedding=...)

    async def retrieve(self, query: str, k: int = 3) -> list[str]:
        """쿼리와 유사한 상위 k개 청크 반환"""
        if self.vectorstore is None:
            return []
        docs = self.vectorstore.similarity_search(query, k=k)
        return [d.page_content for d in docs]
