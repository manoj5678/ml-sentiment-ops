import subprocess
import sys

print("🚀 Starting Sentiment Analysis API (Simple Version)...")
print("📚 API docs will be available at: http://localhost:8000/docs")
print("Press Ctrl+C to stop\n")

subprocess.run([sys.executable, "-m", "uvicorn", "src.api.main_simple:app", "--reload"])
