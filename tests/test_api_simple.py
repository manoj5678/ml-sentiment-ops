import requests
import json

BASE_URL = "http://localhost:8000"

def test_api():
    print("🧪 Testing Sentiment Analysis API...")
    
    # Test health
    response = requests.get(f"{BASE_URL}/health")
    assert response.status_code == 200
    print("✅ Health check passed")
    
    # Test prediction
    test_data = {"texts": ["I love this!", "This is terrible."]}
    response = requests.post(f"{BASE_URL}/predict", json=test_data)
    assert response.status_code == 200
    result = response.json()
    assert len(result["predictions"]) == 2
    print("✅ Prediction test passed")
    
    # Test metrics
    response = requests.get(f"{BASE_URL}/metrics")
    assert response.status_code == 200
    print("✅ Metrics test passed")
    
    print("\n🎉 All tests passed!")

if __name__ == "__main__":
    test_api()