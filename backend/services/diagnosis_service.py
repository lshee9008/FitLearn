"""
진단 오케스트레이터
RAG 검색 → Gemini 분석 (25문항+글쓰기+응답시간+학습이력) → 후처리 → Redis 캐싱
"""
import hashlib
import logging


from .rag_pipeline.retriever import Retriever
from .rag_pipeline.analyzer import RAGAnalyzer
from .rag_pipeline.postprocessor import postprocess
from .redis_service import RedisService

logger = logging.getLogger(__name__)

_retriever = Retriever(k=5)
_analyzer = RAGAnalyzer()
_redis = RedisService()

CACHE_TTL = 60 * 60 * 24  # 24시간


def _cache_key(answers: list[dict]) -> str:
    sorted_answers = sorted(answers, key=lambda a: a["question_id"])
    pattern = "|".join(
        f"{a['question_id']}:{a['answer']}" for a in sorted_answers
    )
    return f"diagnosis:{hashlib.md5(pattern.encode()).hexdigest()}"


class DiagnosisService:
    async def analyze(
        self,
        user_id: str,
        answers: list[dict],
        writing_response: str = "",
        response_times: list[int] = None,
        learning_history: dict = None,
    ) -> dict:
        """
        전체 진단 파이프라인:
        1. Redis 캐시 확인
        2. FAISS 논문 검색
        3. Gemini RAG 분석 (25문항+글쓰기+응답시간+학습이력)
        4. 후처리 (정규화 + 유형 분류)
        5. Redis 저장
        """
        if response_times is None:
            response_times = []
        if learning_history is None:
            learning_history = {}

        cache_key = _cache_key(answers)

        cached = await _redis.get(cache_key)
        if cached:
            logger.info(f"[DiagnosisService] 캐시 히트 user={user_id}")
            return cached

        logger.info(f"[DiagnosisService] RAG 검색 시작 user={user_id}")
        retrieved = await _retriever.retrieve(answers)
        logger.info(f"[DiagnosisService] {len(retrieved)}개 논문 청크 검색됨")

        logger.info("[DiagnosisService] Gemini 분석 시작")
        raw_result = await _analyzer.analyze(
            answers, retrieved,
            writing_response=writing_response,
            response_times=response_times,
            learning_history=learning_history,
        )

        result = postprocess(raw_result, retrieved)
        logger.info(
            f"[DiagnosisService] 분석 완료 user={user_id} "
            f"style={result.get('learning_style')} "
            f"confidence={result.get('confidence_score')}%"
        )

        await _redis.set(cache_key, result, ttl=CACHE_TTL)
        return result
