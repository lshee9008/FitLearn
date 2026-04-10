import os
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv(".env.development")
genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))

try:
    for m in genai.list_models():
        if 'gemma' in m.name.lower():
            print(m.name)
except Exception as e:
    print(f"Error: {e}")
