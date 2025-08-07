#!/bin/bash
# docker-run.sh - Scripts for Docker operations

# Build the Docker image
echo "🔨 Building Docker image..."
docker build -t sentiment-api:latest .

# Run tests in Docker
echo "🧪 Running tests in Docker..."
docker run --rm sentiment-api:latest pytest tests/ -v

# Run the container
echo "🚀 Starting container..."
docker run -d \
  --name sentiment-api \
  -p 8000:8000 \
  --restart unless-stopped \
  sentiment-api:latest

# Show logs
echo "📋 Container logs:"
docker logs -f sentiment-api