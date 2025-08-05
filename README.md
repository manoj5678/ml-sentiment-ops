# ML Sentiment Analysis CI/CD Pipeline

Production-ready MLOps pipeline for sentiment analysis with automated deployment, monitoring, and A/B testing.

## 🚀 Quick Start

1. **Clone the repository**
```bash
git clone https://github.com/YOUR_USERNAME/ml-sentiment-ops.git
cd ml-sentiment-ops
```

2. **Run setup script**
```bash
chmod +x setup.sh
./setup.sh
```

3. **Activate virtual environment**
```bash
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

4. **Run the API locally**
```bash
python -m src.api.main
```

5. **Run tests**
```bash
pytest tests/ -v
```

## 🏗️ Project Structure

```
ml-sentiment-ops/
├── src/
│   ├── api/          # FastAPI application
│   ├── model/        # ML model wrapper
│   └── monitoring/   # Metrics collection
├── tests/            # Unit and integration tests
├── docker/           # Docker configuration
├── docs/             # Documentation
└── .github/          # GitHub Actions workflows
```

## 📊 Current Progress

- [x] Project structure setup
- [x] Basic sentiment API
- [ ] Docker containerization
- [ ] Kubernetes deployment
- [ ] CI/CD pipeline
- [ ] Monitoring setup

## 🛠️ Tech Stack

- **API**: FastAPI
- **ML**: Hugging Face Transformers
- **Monitoring**: Prometheus
- **Container**: Docker
- **Orchestration**: Kubernetes
- **CI/CD**: GitHub Actions
