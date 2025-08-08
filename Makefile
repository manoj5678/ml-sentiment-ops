# Makefile - Complete version with all commands
.PHONY: help build run test clean docker-build docker-run docker-stop k8s-setup k8s-deploy-dev k8s-deploy-prod k8s-test k8s-delete-dev k8s-logs k8s-forward

# Default target
.DEFAULT_GOAL := help

# Colors for output
YELLOW := \033[1;33m
GREEN := \033[0;32m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Python/Local Development
install: ## Install dependencies
	pip install -r requirements-docker.txt
	pip install -r requirements-test.txt

test: ## Run tests locally
	pytest tests/ -v --cov=src --cov-report=term-missing

run: ## Run API locally
	python -m uvicorn src.api.main_simple:app --reload --host 0.0.0.0 --port 8000

# Docker commands
docker-build: ## Build Docker image
	@echo "$(YELLOW)Building Docker image...$(NC)"
	docker build -t sentiment-api:latest .

docker-run: docker-build ## Build and run with Docker
	@echo "$(YELLOW)Starting Docker container...$(NC)"
	docker run -d --name sentiment-api -p 8000:8000 sentiment-api:latest

docker-stop: ## Stop Docker container
	@echo "$(YELLOW)Stopping Docker container...$(NC)"
	docker stop sentiment-api 2>/dev/null || true
	docker rm sentiment-api 2>/dev/null || true

docker-logs: ## Show Docker container logs
	docker logs -f sentiment-api

docker-test: ## Run tests in Docker
	docker run --rm sentiment-api:latest python -m pytest tests/ -v

docker-compose-up: ## Run with docker-compose
	docker-compose up -d

docker-compose-down: ## Stop docker-compose
	docker-compose down

# Kubernetes commands
k8s-setup: ## Setup local Kubernetes with Kind
	@echo "$(YELLOW)Setting up Kind cluster...$(NC)"
	chmod +x scripts/setup-local-k8s.sh
	./scripts/setup-local-k8s.sh

k8s-deploy-dev: docker-build ## Deploy to development environment
	@echo "$(GREEN)Deploying to Development environment...$(NC)"
	@# Load image into Kind if using local cluster
	@if command -v kind > /dev/null 2>&1; then \
		echo "$(YELLOW)Loading image into Kind cluster...$(NC)"; \
		kind load docker-image sentiment-api:latest --name ml-ops-cluster 2>/dev/null || \
		kind load docker-image sentiment-api:latest 2>/dev/null || true; \
	fi
	@# Apply Kubernetes manifests
	kubectl apply -k k8s/overlays/dev
	@# Wait for deployment to be ready
	@echo "$(YELLOW)Waiting for deployment to be ready...$(NC)"
	kubectl wait --for=condition=available --timeout=300s deployment/dev-sentiment-api -n ml-apps-dev || \
	kubectl wait --for=condition=available --timeout=300s deployment/sentiment-api -n ml-apps-dev || true
	@echo "$(GREEN)✅ Deployment complete!$(NC)"
	@kubectl get pods -n ml-apps-dev

k8s-deploy-prod: docker-build ## Deploy to production environment
	@echo "$(GREEN)Deploying to Production environment...$(NC)"
	kubectl apply -k k8s/overlays/prod
	kubectl wait --for=condition=available --timeout=300s deployment/prod-sentiment-api -n ml-apps-prod
	@echo "$(GREEN)✅ Production deployment complete!$(NC)"

k8s-test: ## Test Kubernetes deployment
	@echo "$(YELLOW)Testing Kubernetes deployment...$(NC)"
	@if [ -f scripts/k8s-test.sh ]; then \
		chmod +x scripts/k8s-test.sh; \
		./scripts/k8s-test.sh dev; \
	else \
		echo "$(YELLOW)Running basic tests...$(NC)"; \
		kubectl get pods -n ml-apps-dev; \
		echo ""; \
		echo "$(YELLOW)Testing health endpoint through port-forward...$(NC)"; \
		echo "Run 'make k8s-forward' in another terminal, then:"; \
		echo "curl http://localhost:8080/health"; \
	fi

k8s-delete-dev: ## Delete development deployment
	@echo "$(RED)Deleting development deployment...$(NC)"
	kubectl delete -k k8s/overlays/dev 2>/dev/null || true

k8s-delete-prod: ## Delete production deployment
	@echo "$(RED)Deleting production deployment...$(NC)"
	kubectl delete -k k8s/overlays/prod 2>/dev/null || true

k8s-logs: ## Show pod logs from development
	@echo "$(YELLOW)Showing logs from development pods...$(NC)"
	@POD=$$(kubectl get pods -n ml-apps-dev -l app=sentiment-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -z "$$POD" ]; then \
		echo "$(RED)No pods found. Is the deployment running?$(NC)"; \
		echo "Run 'make k8s-deploy-dev' first"; \
	else \
		echo "$(GREEN)Logs from pod: $$POD$(NC)"; \
		kubectl logs -n ml-apps-dev $$POD -f; \
	fi

k8s-forward: ## Port forward to access the service locally
	@echo "$(YELLOW)Setting up port forwarding...$(NC)"
	@echo "$(GREEN)After port-forward starts, access the API at: http://localhost:8080$(NC)"
	@echo "$(GREEN)Health check: http://localhost:8080/health$(NC)"
	@echo "$(GREEN)API docs: http://localhost:8080/docs$(NC)"
	@echo "Press Ctrl+C to stop"
	@kubectl port-forward -n ml-apps-dev svc/dev-sentiment-api 8080:80 || \
	kubectl port-forward -n ml-apps-dev svc/sentiment-api 8080:80

k8s-describe: ## Describe pods in development
	@echo "$(YELLOW)Describing pods...$(NC)"
	kubectl describe pods -n ml-apps-dev -l app=sentiment-api

k8s-exec: ## Execute shell in pod
	@POD=$$(kubectl get pods -n ml-apps-dev -l app=sentiment-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -z "$$POD" ]; then \
		echo "$(RED)No pods found$(NC)"; \
	else \
		echo "$(GREEN)Connecting to pod: $$POD$(NC)"; \
		kubectl exec -it -n ml-apps-dev $$POD -- /bin/bash; \
	fi

k8s-events: ## Show Kubernetes events
	@echo "$(YELLOW)Recent events in ml-apps-dev namespace:$(NC)"
	kubectl get events -n ml-apps-dev --sort-by='.lastTimestamp' | tail -20

k8s-resources: ## Show resource usage
	@echo "$(YELLOW)Resource usage:$(NC)"
	kubectl top nodes 2>/dev/null || echo "Metrics server not installed"
	kubectl top pods -n ml-apps-dev 2>/dev/null || true

k8s-all-status: ## Show all resources in dev namespace
	@echo "$(YELLOW)All resources in ml-apps-dev:$(NC)"
	kubectl get all -n ml-apps-dev

k8s-validate: ## Validate Kubernetes manifests
	@echo "$(YELLOW)Validating Kubernetes manifests...$(NC)"
	kubectl kustomize k8s/overlays/dev > /tmp/dev-manifest.yaml
	kubectl kustomize k8s/overlays/prod > /tmp/prod-manifest.yaml
	@echo "$(GREEN)✅ Manifests are valid!$(NC)"

# Quick commands
quick-test: docker-build k8s-deploy-dev k8s-test ## Quick build, deploy and test

clean: ## Clean up all resources
	@echo "$(RED)Cleaning up...$(NC)"
	make docker-stop
	make k8s-delete-dev
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	rm -rf .coverage htmlcov .pytest_cache

# Utility commands
check-tools: ## Check if required tools are installed
	@echo "$(YELLOW)Checking required tools...$(NC)"
	@command -v docker >/dev/null 2>&1 && echo "$(GREEN)✓ Docker$(NC)" || echo "$(RED)✗ Docker$(NC)"
	@command -v kubectl >/dev/null 2>&1 && echo "$(GREEN)✓ kubectl$(NC)" || echo "$(RED)✗ kubectl$(NC)"
	@command -v kind >/dev/null 2>&1 && echo "$(GREEN)✓ kind$(NC)" || echo "$(RED)✗ kind (optional)$(NC)"
	@command -v python >/dev/null 2>&1 && echo "$(GREEN)✓ Python$(NC)" || echo "$(RED)✗ Python$(NC)"

status: ## Show current status of all components
	@echo "$(YELLOW)=== Docker Status ===$(NC)"
	@docker ps -a | grep sentiment-api || echo "No Docker containers running"
	@echo ""
	@echo "$(YELLOW)=== Kubernetes Status ===$(NC)"
	@kubectl get pods -n ml-apps-dev 2>/dev/null || echo "No Kubernetes pods in ml-apps-dev"
	@echo ""
	@echo "$(YELLOW)=== Services ===$(NC)"
	@kubectl get svc -n ml-apps-dev 2>/dev/null || echo "No services in ml-apps-dev"