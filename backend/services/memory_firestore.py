"""
인메모리 Firestore 대체 클라이언트

Firebase 자격증명이 없거나 초기화에 실패해도 서비스(특히 데모 체험)가 동작하도록
firebase_service.py에서 사용하는 Firestore API 표면만 최소 구현한다.
서버 재시작 시 데이터는 초기화되며, 데모 콘텐츠는 demo_seed가 다시 채운다.
"""
from __future__ import annotations

import copy
import threading
import uuid
from typing import Any, Iterable

_lock = threading.RLock()


def _apply_transform(current: Any, value: Any) -> Any:
    """firestore.ArrayUnion / ArrayRemove / Increment 센티널을 해석."""
    name = type(value).__name__
    if name == "ArrayUnion":
        base = list(current or [])
        for v in getattr(value, "values", []):
            if v not in base:
                base.append(v)
        return base
    if name == "ArrayRemove":
        remove = list(getattr(value, "values", []))
        return [v for v in (current or []) if v not in remove]
    if name == "Increment":
        return (current or 0) + getattr(value, "value", 0)
    if name == "Sentinel" and "DELETE" in repr(value).upper():
        return _DELETE
    return copy.deepcopy(value)


_DELETE = object()


def _set_path(doc: dict, path: str, value: Any) -> None:
    keys = path.split(".")
    node = doc
    for k in keys[:-1]:
        node = node.setdefault(k, {})
    resolved = _apply_transform(node.get(keys[-1]), value)
    if resolved is _DELETE:
        node.pop(keys[-1], None)
    else:
        node[keys[-1]] = resolved


def _deep_merge(dst: dict, src: dict) -> None:
    for k, v in src.items():
        if isinstance(v, dict) and isinstance(dst.get(k), dict):
            _deep_merge(dst[k], v)
        else:
            resolved = _apply_transform(dst.get(k), v)
            if resolved is _DELETE:
                dst.pop(k, None)
            else:
                dst[k] = resolved


class _Snapshot:
    def __init__(self, ref: "_DocRef", data: dict | None):
        self.reference = ref
        self.id = ref.id
        self._data = data

    @property
    def exists(self) -> bool:
        return self._data is not None

    def to_dict(self) -> dict | None:
        return copy.deepcopy(self._data) if self._data is not None else None

    def get(self, field: str):
        node: Any = self._data or {}
        for k in field.split("."):
            if not isinstance(node, dict):
                return None
            node = node.get(k)
        return copy.deepcopy(node)


class _DocRef:
    def __init__(self, store: dict, path: tuple[str, ...]):
        self._store = store
        self._path = path
        self.id = path[-1]

    @property
    def path(self) -> str:
        return "/".join(self._path)

    def collection(self, name: str) -> "_CollectionRef":
        return _CollectionRef(self._store, self._path + (name,))

    def _col_path(self) -> tuple[str, ...]:
        return self._path[:-1]

    def get(self, *_, **__) -> _Snapshot:
        with _lock:
            data = self._store.get(self._col_path(), {}).get(self.id)
            return _Snapshot(self, copy.deepcopy(data) if data is not None else None)

    def set(self, data: dict, merge: bool = False) -> None:
        with _lock:
            col = self._store.setdefault(self._col_path(), {})
            if merge and self.id in col:
                _deep_merge(col[self.id], data)
            else:
                fresh: dict = {}
                _deep_merge(fresh, data)
                col[self.id] = fresh

    def update(self, data: dict) -> None:
        with _lock:
            col = self._store.setdefault(self._col_path(), {})
            if self.id not in col:
                raise KeyError(f"No document to update: {self.path}")
            for k, v in data.items():
                _set_path(col[self.id], k, v)

    def delete(self) -> None:
        with _lock:
            self._store.get(self._col_path(), {}).pop(self.id, None)


class _Query:
    def __init__(self, store: dict, path: tuple[str, ...]):
        self._store = store
        self._path = path
        self._filters: list[tuple[str, str, Any]] = []
        self._orders: list[tuple[str, bool]] = []
        self._limit: int | None = None

    def _clone(self) -> "_Query":
        q = _Query(self._store, self._path)
        q._filters = list(self._filters)
        q._orders = list(self._orders)
        q._limit = self._limit
        return q

    def where(self, field: str = None, op: str = None, value: Any = None, *, filter=None) -> "_Query":
        if filter is not None:  # FieldFilter
            field, op, value = filter.field_path, filter.op_string, filter.value
        q = self._clone()
        q._filters.append((field, op, value))
        return q

    def order_by(self, field: str, direction: str = "ASCENDING") -> "_Query":
        q = self._clone()
        q._orders.append((field, str(direction).upper().startswith("DESC")))
        return q

    def limit(self, n: int) -> "_Query":
        q = self._clone()
        q._limit = n
        return q

    @staticmethod
    def _match(data: dict, field: str, op: str, value: Any) -> bool:
        cur = data.get(field)
        if op == "==":
            return cur == value
        if op == "!=":
            return cur != value
        if op == "array_contains":
            return isinstance(cur, list) and value in cur
        if op == "in":
            return cur in (value or [])
        if op == "array_contains_any":
            return isinstance(cur, list) and any(v in cur for v in value or [])
        try:
            return {"<": cur < value, "<=": cur <= value, ">": cur > value, ">=": cur >= value}[op]
        except Exception:
            return False

    def stream(self, *_, **__) -> Iterable[_Snapshot]:
        with _lock:
            items = list(self._store.get(self._path, {}).items())
        docs = [
            (doc_id, data) for doc_id, data in items
            if all(self._match(data, f, o, v) for f, o, v in self._filters)
        ]
        for field, desc in reversed(self._orders):
            docs.sort(key=lambda kv: (kv[1].get(field) is None, str(kv[1].get(field))), reverse=desc)
        if self._limit is not None:
            docs = docs[: self._limit]
        return [
            _Snapshot(_DocRef(self._store, self._path + (doc_id,)), copy.deepcopy(data))
            for doc_id, data in docs
        ]

    def get(self, *_, **__):
        return list(self.stream())


class _CollectionRef(_Query):
    def document(self, doc_id: str | None = None) -> _DocRef:
        return _DocRef(self._store, self._path + (doc_id or uuid.uuid4().hex[:20],))

    def add(self, data: dict):
        ref = self.document()
        ref.set(data)
        return None, ref

    def list_documents(self):
        with _lock:
            return [_DocRef(self._store, self._path + (i,)) for i in self._store.get(self._path, {})]


class _Batch:
    def __init__(self):
        self._ops: list = []

    def set(self, ref: _DocRef, data: dict, merge: bool = False):
        self._ops.append(lambda: ref.set(data, merge=merge))

    def update(self, ref: _DocRef, data: dict):
        self._ops.append(lambda: ref.update(data))

    def delete(self, ref: _DocRef):
        self._ops.append(ref.delete)

    def commit(self):
        with _lock:
            for op in self._ops:
                op()
        self._ops.clear()


class MemoryFirestore:
    """firestore.client() 대체 — 프로세스 메모리에 데이터를 보관."""

    is_memory = True

    def __init__(self):
        self._store: dict[tuple[str, ...], dict[str, dict]] = {}

    def collection(self, name: str) -> _CollectionRef:
        return _CollectionRef(self._store, (name,))

    def document(self, path: str) -> _DocRef:
        return _DocRef(self._store, tuple(path.split("/")))

    def batch(self) -> _Batch:
        return _Batch()

    def get_all(self, refs: Iterable[_DocRef]):
        return [ref.get() for ref in refs]


_instance: MemoryFirestore | None = None


def get_memory_db() -> MemoryFirestore:
    global _instance
    if _instance is None:
        _instance = MemoryFirestore()
    return _instance
