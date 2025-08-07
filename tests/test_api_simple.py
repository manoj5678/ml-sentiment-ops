# tests/test_api.py
"""Comprehensive test suite for Sentiment Analysis API"""
import pytest
from fastapi.testclient import TestClient
import sys
import os
import json

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.api.main_simple import app

# Create test client
client = TestClient(app)


class TestHealthEndpoints:
    """Test health and status endpoints"""
    
    def test_root_endpoint(self):
        """Test root endpoint returns API information"""
        response = client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert data["message"] == "Sentiment Analysis API"
        assert "endpoints" in data
        assert all(endpoint in data["endpoints"] for endpoint in ["health", "predict", "metrics", "docs"])
    
    def test_health_endpoint(self):
        """Test health check endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["is_model_loaded"] is True
        assert "version" in data


class TestPredictionEndpoint:
    """Test prediction functionality"""
    
    def test_single_prediction(self):
        """Test prediction with single text"""
        response = client.post(
            "/predict",
            json={"texts": ["I love this product!"]}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["count"] == 1
        assert len(data["predictions"]) == 1
        assert data["predictions"][0]["sentiment"] in ["POSITIVE", "NEGATIVE"]
        assert 0 <= data["predictions"][0]["confidence"] <= 1
    
    def test_multiple_predictions(self):
        """Test prediction with multiple texts"""
        texts = [
            "This is amazing!",
            "I hate this",
            "It's okay I guess"
        ]
        response = client.post("/predict", json={"texts": texts})
        assert response.status_code == 200
        data = response.json()
        assert data["count"] == 3
        assert len(data["predictions"]) == 3
    
    def test_positive_sentiment_detection(self):
        """Test that positive words return positive sentiment"""
        positive_texts = [
            "I love this!",
            "This is great!",
            "Awesome product!",
            "Excellent service!"
        ]
        response = client.post("/predict", json={"texts": positive_texts})
        data = response.json()
        
        # At least 3 out of 4 should be detected as positive
        positive_count = sum(1 for p in data["predictions"] if p["sentiment"] == "POSITIVE")
        assert positive_count >= 3
    
    def test_negative_sentiment_detection(self):
        """Test that negative words return negative sentiment"""
        negative_texts = [
            "I hate this",
            "Terrible experience",
            "Awful product",
            "Worst service ever"
        ]
        response = client.post("/predict", json={"texts": negative_texts})
        data = response.json()
        
        # At least 3 out of 4 should be detected as negative
        negative_count = sum(1 for p in data["predictions"] if p["sentiment"] == "NEGATIVE")
        assert negative_count >= 3
    
    def test_empty_text_list(self):
        """Test that empty text list returns validation error"""
        response = client.post("/predict", json={"texts": []})
        assert response.status_code == 422
    
    def test_too_many_texts(self):
        """Test that too many texts returns validation error"""
        texts = ["sample text"] * 11  # Max is 10
        response = client.post("/predict", json={"texts": texts})
        assert response.status_code == 422
    
    def test_invalid_input_type(self):
        """Test that invalid input type returns error"""
        response = client.post("/predict", json={"texts": "not a list"})
        assert response.status_code == 422
    
    def test_missing_texts_field(self):
        """Test that missing texts field returns error"""
        response = client.post("/predict", json={})
        assert response.status_code == 422
    
    def test_response_structure(self):
        """Test that response has correct structure"""
        response = client.post(
            "/predict",
            json={"texts": ["Test text"]}
        )
        data = response.json()
        
        # Check response structure
        assert "predictions" in data
        assert "count" in data
        assert "processing_time" in data
        
        # Check prediction structure
        prediction = data["predictions"][0]
        assert "text" in prediction
        assert "sentiment" in prediction
        assert "confidence" in prediction
        assert "model_version" in prediction


class TestMetricsEndpoint:
    """Test metrics endpoint"""
    
    def test_metrics_endpoint(self):
        """Test that metrics endpoint returns Prometheus format"""
        response = client.get("/metrics")
        assert response.status_code == 200
        assert response.headers["content-type"] == "text/plain; charset=utf-8"
        
        # Check for Prometheus metrics format
        content = response.text
        assert "# HELP" in content
        assert "# TYPE" in content
        assert "sentiment_predictions_total" in content


class TestEdgeCases:
    """Test edge cases and error handling"""
    
    def test_long_text_truncation(self):
        """Test that long texts are truncated in response"""
        long_text = "This is a very long text. " * 50
        response = client.post("/predict", json={"texts": [long_text]})
        data = response.json()
        
        returned_text = data["predictions"][0]["text"]
        assert len(returned_text) == 103  # 100 chars + "..."
        assert returned_text.endswith("...")
    
    def test_special_characters(self):
        """Test handling of special characters"""
        special_texts = [
            "Great! 😊",
            "Not good 😞",
            "¡Excelente!",
            "C'est terrible"
        ]
        response = client.post("/predict", json={"texts": special_texts})
        assert response.status_code == 200
        data = response.json()
        assert len(data["predictions"]) == 4
    
    def test_concurrent_requests(self):
        """Test API handles concurrent requests"""
        import concurrent.futures
        
        def make_request():
            return client.post("/predict", json={"texts": ["Test"]})
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(make_request) for _ in range(10)]
            results = [f.result() for f in concurrent.futures.as_completed(futures)]
        
        assert all(r.status_code == 200 for r in results)


# Performance tests
class TestPerformance:
    """Test API performance"""
    
    def test_response_time(self):
        """Test that API responds within acceptable time"""
        import time
        
        start = time.time()
        response = client.post("/predict", json={"texts": ["Test"] * 5})
        duration = time.time() - start
        
        assert response.status_code == 200
        assert duration < 1.0  # Should respond within 1 second
    
    def test_processing_time_in_response(self):
        """Test that processing time is included and reasonable"""
        response = client.post("/predict", json={"texts": ["Test"] * 5})
        data = response.json()
        
        assert "processing_time" in data
        assert isinstance(data["processing_time"], float)
        assert data["processing_time"] < 0.5  # Should process within 500ms