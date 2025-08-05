# src/api/main_simple.py
"""Simple version that works without ML libraries - Fixed version"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, ConfigDict
from typing import List
from fastapi.responses import Response
import time
import random
import logging
import os

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Sentiment Analysis API", 
    version="1.0.0",
    description="Simple mock version for development"
)

# Add CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

class TextRequest(BaseModel):
    texts: List[str] = Field(..., min_items=1, max_items=10)

class HealthResponse(BaseModel):
    # Fix Pydantic warnings by using different field names
    status: str
    is_model_loaded: bool
    version: str
    
    # Disable protected namespace warning
    model_config = ConfigDict(protected_namespaces=())

@app.get("/")
def root():
    return {
        "message": "Sentiment Analysis API",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "predict": "/predict",
            "metrics": "/metrics",
            "docs": "/docs"
        }
    }

@app.get("/health", response_model=HealthResponse)
def health():
    return HealthResponse(
        status="healthy",
        is_model_loaded=True,
        version="mock-model-v1"
    )

@app.post("/predict")
def predict(request: TextRequest):
    start_time = time.time()
    logger.info(f"Received prediction request for {len(request.texts)} texts")
    
    predictions = []
    for text in request.texts:
        # Simple rule-based sentiment
        text_lower = text.lower()
        if any(word in text_lower for word in ['love', 'great', 'awesome', 'excellent', 'amazing', 'wonderful']):
            sentiment = "POSITIVE"
            confidence = random.uniform(0.85, 0.99)
        elif any(word in text_lower for word in ['hate', 'terrible', 'awful', 'horrible', 'worst', 'bad']):
            sentiment = "NEGATIVE"
            confidence = random.uniform(0.85, 0.99)
        else:
            sentiment = random.choice(["POSITIVE", "NEGATIVE"])
            confidence = random.uniform(0.50, 0.75)
        
        predictions.append({
            "text": text[:100] + "..." if len(text) > 100 else text,
            "sentiment": sentiment,
            "confidence": round(confidence, 4),
            "model_version": "mock-model-v1"
        })
    
    processing_time = time.time() - start_time
    logger.info(f"Processed {len(predictions)} predictions in {processing_time:.3f}s")
    
    return {
        "predictions": predictions,
        "count": len(predictions),
        "processing_time": round(processing_time, 3)
    }

@app.get("/metrics", response_class=Response)
def metrics():
    # Mock Prometheus metrics
    metrics_data = """# HELP sentiment_predictions_total Total predictions made
# TYPE sentiment_predictions_total counter
sentiment_predictions_total{status="success"} 42
sentiment_predictions_total{status="error"} 0

# HELP sentiment_prediction_duration_seconds Prediction duration
# TYPE sentiment_prediction_duration_seconds histogram
sentiment_prediction_duration_seconds_bucket{le="0.1"} 35
sentiment_prediction_duration_seconds_bucket{le="0.5"} 40
sentiment_prediction_duration_seconds_bucket{le="1.0"} 42
sentiment_prediction_duration_seconds_count 42
sentiment_prediction_duration_seconds_sum 8.5

# HELP sentiment_active_requests Current active requests
# TYPE sentiment_active_requests gauge
sentiment_active_requests 0
"""
    return Response(content=metrics_data, media_type="text/plain")

# Don't run uvicorn here if imported as module
if __name__ == "__main__":
    import uvicorn
    # Use string import for proper reloading
    uvicorn.run("src.api.main_simple:app", host="0.0.0.0", port=8000, reload=True)