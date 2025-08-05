import time
from contextlib import contextmanager

# Simple counters
prediction_count = {"success": 0, "error": 0}
request_count = 0
total_duration = 0

def track_prediction_request(batch_size: int, status: str = "success"):
    global prediction_count
    prediction_count[status] += batch_size

@contextmanager
def track_prediction_duration():
    global total_duration, request_count
    start_time = time.time()
    request_count += 1
    try:
        yield
    finally:
        duration = time.time() - start_time
        total_duration += duration

def get_metrics() -> str:
    """Return mock Prometheus metrics"""
    avg_duration = total_duration / max(request_count, 1)
    return f"""# HELP sentiment_predictions_total Total predictions
# TYPE sentiment_predictions_total counter
sentiment_predictions_total{{status="success"}} {prediction_count['success']}
sentiment_predictions_total{{status="error"}} {prediction_count['error']}
# HELP sentiment_avg_duration_seconds Average prediction duration
# TYPE sentiment_avg_duration_seconds gauge
sentiment_avg_duration_seconds {avg_duration:.3f}
"""