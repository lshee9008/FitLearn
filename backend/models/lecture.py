from pydantic import BaseModel


class ReforgeRequest(BaseModel):
    user_id: str
    lecture_id: str
    lecture_content: str


class ReforgeResult(BaseModel):
    learning_type: str
    content: str
