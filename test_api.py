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
