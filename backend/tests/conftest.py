import os
import sys
from pathlib import Path

# 테스트는 외부 서비스 없이 인메모리 저장소로 실행한다
os.environ["FIREBASE_CREDENTIALS"] = ""
os.environ.setdefault("GEMINI_API_KEY", "")
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
