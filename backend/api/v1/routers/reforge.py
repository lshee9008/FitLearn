import json
import logging
from fastapi import APIRouter, Request, File, Form, UploadFile
from fastapi.responses import StreamingResponse
from slowapi.util import get_remote_address
from slowapi import Limiter

from models.lecture import ReforgeRequest
from services.reforge_service import ReforgeService


logger = logging.getLogger(__name__)
router = APIRouter(tags=["reforge"])
limiter = Limiter(key_func=get_remote_address)
reforge_svc = ReforgeService()

@router.post("/reforge")
@limiter.limit("5/minute")
async def reforge_lecture(request: Request, body: ReforgeRequest):
    """교안을 5차원 성향 및 과목 수준에 맞게 재해석 (SSE 스트리밍)"""
    
    async def event_generator():
        async for chunk in reforge_svc.reforge_stream(
            content=body.lecture_content,
            lecture_id=body.lecture_id,
            user_id=body.user_id
        ):
            if chunk == "DONE":
                yield "data: [DONE]\n\n"
            else:
                yield f"data: {json.dumps(chunk, ensure_ascii=False)}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
    )


@router.post("/reforge/demo")
async def demo_reforge(
    request: Request,
    learning_type: str = Form("읽기형"),
    content: str = Form(""),
    lecture_id: str = Form(""),
    room_id: str = Form(""),
    file: UploadFile = File(None),
):
    """테스트 페이지용 데모 재가공 스트리밍 (SSE)"""
    
    file_bytes = await file.read() if file else None
    file_name = file.filename if file else ""

    async def event_generator():
        async for chunk in reforge_svc.reforge_stream(
            learning_type=learning_type,
            content=content,
            room_id=room_id,
            lecture_id=lecture_id,
            file_content=file_bytes,
            file_name=file_name
        ):
            if chunk == "DONE":
                yield "data: [DONE]\n\n"
            else:
                yield f"data: {json.dumps(chunk, ensure_ascii=False)}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
    )
