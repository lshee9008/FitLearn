"""
FAISS 검색 — 학생 응답 패턴에서 관련 논문 청크 Top-K 반환
"""
import logging
from .preprocessor import PaperVectorStore

logger = logging.getLogger(__name__)


def _answers_to_query(answers: list[dict]) -> str:
    """15개 답변을 RAG 검색 쿼리로 변환"""
    a_map = {a["question_id"]: a["answer"] for a in answers}

    # 파트 A (Q1-5): 학습 스타일 모달리티
    style_answers = [a_map.get(i, "") for i in range(1, 6)]
    style_counts = {
        "시각형": style_answers.count("A"),
        "청각형": style_answers.count("B"),
        "읽기형": style_answers.count("C"),
        "실습형": style_answers.count("D"),
    }
    dominant_style = max(style_counts, key=lambda k: style_counts[k])

    # 파트 B (Q6-10): 인지 유형
    cognitive_a = sum(1 for i in range(6, 11) if a_map.get(i) == "A")
    cognitive_type = "분석형" if cognitive_a >= 3 else "직관형"

    # 파트 C (Q11-15): 환경 패턴
    focus = "단기집중형" if a_map.get(12) == "A" else "장기몰입형"
    pace = "속도형" if a_map.get(13) == "A" else "숙고형"

    query = (
        f"{dominant_style} 학습자 교육 방법 "
        f"{cognitive_type} 인지 처리 방식 "
        f"{focus} 집중 패턴 {pace} 학습 페이스 "
        f"VARK 모달리티 Felder Silverman 인지부하 Kolb 경험학습"
    )
    logger.debug(f"[RAG] 검색 쿼리: {query}")
    return query


class Retriever:
    def __init__(self, k: int = 5):
        self.k = k

    async def retrieve(self, answers: list[dict]) -> list[dict]:
        """학생 답변 → 관련 논문 청크 Top-K 반환"""
        store = PaperVectorStore.get_store()
        if store is None:
            logger.warning("[RAG] 벡터 스토어 미초기화 — 빈 컨텍스트 반환")
            return []

        query = _answers_to_query(answers)
        docs = store.similarity_search_with_score(query, k=self.k)

        results = []
        for doc, score in docs:
            results.append({
                "content": doc.page_content,
                "paper": doc.metadata.get("paper", ""),
                "title": doc.metadata.get("title", ""),
                "relevance": round(1 - score, 3),  # 낮은 L2 거리 = 높은 관련도
            })

        logger.debug(f"[RAG] {len(results)}개 청크 검색 완료")
        return results
