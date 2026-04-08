from pydantic import BaseModel
from enum import Enum


class UserRole(str, Enum):
    STUDENT = "student"
    PROFESSOR = "professor"


class RegisterRequest(BaseModel):
    user_id: str
    name: str
    role: UserRole
    email: str = ""


class UserProfile(BaseModel):
    user_id: str
    name: str
    role: UserRole
    email: str = ""
