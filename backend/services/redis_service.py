"""
Redis 서비스: Semantic Caching + 세션 저장
Redis 미연결 시 인메모리 딕셔너리로 자동 폴백
"""
import json
import os
from typing import Any

try:
    import redis.asyncio as aioredis
    _redis_available = True
except ImportError:
    _redis_available = False

_memory_store: dict[str, str] = {}


class RedisService:
    def __init__(self):
        self._client = None

    async def _get_client(self):
        if not _redis_available:
            return None
        if self._client is None:
            try:
                self._client = aioredis.from_url(
                    os.getenv("REDIS_URL", "redis://localhost:6379"),
                    decode_responses=True,
                )
                await self._client.ping()
            except Exception:
                self._client = None
        return self._client

    async def get(self, key: str) -> Any | None:
        client = await self._get_client()
        if client:
            value = await client.get(key)
            return json.loads(value) if value else None
        return json.loads(_memory_store[key]) if key in _memory_store else None

    async def set(self, key: str, value: Any, ttl: int = 3600) -> None:
        client = await self._get_client()
        serialized = json.dumps(value, ensure_ascii=False)
        if client:
            await client.set(key, serialized, ex=ttl)
        else:
            _memory_store[key] = serialized

    async def delete(self, key: str) -> None:
        client = await self._get_client()
        if client:
            await client.delete(key)
        else:
            _memory_store.pop(key, None)

    async def delete_prefix(self, prefix: str) -> None:
        client = await self._get_client()
        if client:
            cursor = 0
            pattern = f"{prefix}*"
            while True:
                cursor, keys = await client.scan(cursor=cursor, match=pattern, count=100)
                if keys:
                    await client.delete(*keys)
                if cursor == 0:
                    break
            return

        for key in [k for k in _memory_store if k.startswith(prefix)]:
            _memory_store.pop(key, None)
