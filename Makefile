# Makefile - Windows Compatible Version
.PHONY: help build run test clean docker-build docker-run docker-stop

# Detect OS
ifeq ($(OS),Windows_NT)
    CURRENT_DIR := $(shell cd)
    PATH_SEP := \\
    DOCKER_PATH := /$(shell pwd | sed 's/^\///' | sed 's/://')
else
    CURRENT_DIR := $(PWD)
    PATH_SEP := /
    DOCKER_PATH := $(PWD)
endif

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install dependencies
	pip install -r requirements-docker.txt
	pip install -r requirements-test.txt

test: ## Run tests locally
	pytest tests/ -v --cov=src --cov-report=term-missing

test-docker: ## Run tests in Docker (Windows-compatible)
	docker run --rm -v "$(CURRENT_DIR):/app" -w /app sentiment-api:latest python -m pytest tests/ -v

test-docker-bash: ## Run tests in Docker using bash syntax
	docker run --rm -v "/$(shell pwd | sed 's/://' | tr '\\' '/'):/app" -w /app sentiment-api:latest python -m pytest tests/ -v

run: ## Run API locally
	python -m uvicorn src.api.main_simple:app --reload --host 0.0.0.0 --port 8000

docker-build: ## Build Docker image
	docker build -t sentiment-api:latest .

docker-run: docker-build ## Build and run with Docker
	docker run -d --name sentiment-api -p 8000:8000 sentiment-api:latest

docker-run-interactive: docker-build ## Run Docker interactively
	docker run -it --rm -p 8000:8000 sentiment-api:latest

docker-stop: ## Stop Docker container
	docker stop sentiment-api && docker rm sentiment-api || true

docker-compose-up: ## Run with docker-compose
	docker-compose up -d

docker-compose-down: ## Stop docker-compose
	docker-compose down

docker-logs: ## Show Docker logs
	docker logs -f sentiment-api

clean: ## Clean up files
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	rm -rf .coverage htmlcov .pytest_cache

check-api: ## Check if API is healthy
	@curl -s http://localhost:8000/health | python -m json.tool || echo "API is not running"

test-api: ## Test API endpoints
	@echo "Testing health endpoint..."
	@curl -s http://localhost:8000/health | python -m json.tool
	@echo "\nTesting prediction endpoint..."
	@curl -s -X POST http://localhost:8000/predict \
		-H "Content-Type: application/json" \
		-d "{\"texts\": [\"I love this!\", \"This is terrible\"]}" | python -m json.tool

# Windows-specific commands
test-windows: ## Run tests with Windows path
	docker run --rm -v "$(CURRENT_DIR):/app" sentiment-api:latest sh -c "cd /app && python -m pytest tests/ -v"

shell: ## Open shell in Docker container
	docker run --rm -it -v "$(CURRENT_DIR):/app" sentiment-api:latest /bin/bash

# Docker check
check-docker: ## Check if Docker is running
	@docker version > /dev/null 2>&1 && echo "✓ Docker is running" || echo "✗ Docker is not running. Please start Docker Desktop"