import os
from dotenv import load_dotenv
import google.generativeai as genai

# .env 파일에서 환경변수 로드
load_dotenv()

api_key = os.environ.get("GEMINI_API_KEY")
if not api_key:
    keys = os.environ.get("GEMINI_API_KEYS")
    if keys:
        api_key = keys.split(",")[0].strip()
if not api_key:
    raise RuntimeError("환경변수 GEMINI_API_KEY 또는 GEMINI_API_KEYS를 설정하세요.")

genai.configure(api_key=api_key)

print("[사용 가능한 Gemini 모델 목록]")
for model in genai.list_models():
    print(model) 