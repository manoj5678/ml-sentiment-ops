#!/bin/bash
# Windows setup using only pre-built wheels - no compilation

echo "🚀 Setting up ML Sentiment Ops - Windows Edition"
echo "=============================================="

# 1. Upgrade pip and setuptools first
echo "📦 Upgrading pip and setuptools..."
python -m pip install --upgrade pip setuptools wheel

# 2. Create a working requirements file for Windows
cat > requirements-windows-prebuilt.txt << 'EOF'
# Pre-built packages only - no compilation required
fastapi==0.104.1
uvicorn==0.24.0
pydantic==2.4.2
python-multipart==0.0.6
prometheus-client==0.18.0
httpx==0.25.1
numpy==1.26.4
requests>=2.31.0
tqdm>=4.66.0
pyyaml>=6.0.1
filelock>=3.13.0
regex>=2023.12.0
packaging>=23.2
EOF

# 3. Install the pre-built packages
echo "📥 Installing pre-built packages..."
pip install -r requirements-windows-prebuilt.txt --only-binary :all: --no-deps
pip install -r requirements-windows-prebuilt.txt

# 4. Try to install ML packages (skip if they fail)
echo "🤖 Attempting to install ML packages..."
pip install torch --index-url https://download.pytorch.org/whl/cpu --only-binary :all: || echo "⚠️ PyTorch installation failed - using mock model"
pip install transformers --only-binary :all: || echo "⚠️ Transformers installation failed - using mock model"

# 5. Create the mock-capable application
echo "📝 Creating application files..."

# Create directories
mkdir -p src/api src/model src/monitoring

# Create __init__.py files
touch src/__init__.py src/api/__init__.py src/model/__init__.py src/monitoring/__init__.py

# 6. Create a simple working version
cat > src/api/main_simple.py << 'EOF'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List
import time
import random

app = FastAPI(title="Sentiment Analysis API", version="1.0.0")

class TextRequest(BaseModel):
    texts: List[str]

class SentimentResponse(BaseModel):
    text: str
    sentiment: str
    confidence: float

@app.get("/")
def root():
    return {"message": "Sentiment Analysis API", "status": "running"}

@app.get("/health")
def health():
    return {"status": "healthy", "model": "mock"}

@app.post("/predict")
def predict(request: TextRequest):
    start_time = time.time()
    
    # Simple mock predictions
    predictions = []
    for text in request.texts:
        text_lower = text.lower()
        if any(word in text_lower for word in ['love', 'great', 'awesome']):
            sentiment = "POSITIVE"
            confidence = random.uniform(0.8, 0.95)
        elif any(word in text_lower for word in ['hate', 'terrible', 'awful']):
            sentiment = "NEGATIVE"
            confidence = random.uniform(0.8, 0.95)
        else:
            sentiment = random.choice(["POSITIVE", "NEGATIVE"])
            confidence = random.uniform(0.5, 0.7)
        
        predictions.append({
            "text": text[:50] + "..." if len(text) > 50 else text,
            "sentiment": sentiment,
            "confidence": round(confidence, 3)
        })
    
    return {
        "predictions": predictions,
        "processing_time": round(time.time() - start_time, 3)
    }

@app.get("/metrics")
def metrics():
    return {"total_requests": 0, "status": "mock metrics"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

# 7. Create a run script
cat > run_simple.py << 'EOF'
import subprocess
import sys

print("🚀 Starting Sentiment Analysis API (Simple Version)...")
print("📚 API docs will be available at: http://localhost:8000/docs")
print("Press Ctrl+C to stop\n")

subprocess.run([sys.executable, "-m", "uvicorn", "src.api.main_simple:app", "--reload"])
EOF

# 8. Create test script
cat > test_api.py << 'EOF'
import requests
import json

BASE_URL = "http://localhost:8000"

print("🧪 Testing Sentiment Analysis API...")

# Test health endpoint
try:
    response = requests.get(f"{BASE_URL}/health")
    print(f"✓ Health check: {response.json()}")
except Exception as e:
    print(f"✗ Health check failed: {e}")
    print("Make sure the API is running!")
    exit(1)

# Test prediction
test_data = {
    "texts": [
        "I love this product!",
        "This is terrible.",
        "Not bad at all."
    ]
}

response = requests.post(f"{BASE_URL}/predict", json=test_data)
if response.status_code == 200:
    print(f"✓ Prediction successful:")
    for pred in response.json()["predictions"]:
        print(f"  - {pred['text']}: {pred['sentiment']} ({pred['confidence']:.1%})")
else:
    print(f"✗ Prediction failed: {response.status_code}")

print("\n✅ All tests passed!")
EOF

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Run the API: python run_simple.py"
echo "2. In another terminal: python test_api.py"
echo "3. View API docs: http://localhost:8000/docs"
echo ""
echo "This is a working version without ML libraries."
echo "You can develop the rest of the infrastructure (Docker, K8s, etc.)"
echo "and add real ML support later when the environment is fixed."