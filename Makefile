# Makefile - Complete MLOps Pipeline (Days 1-4)
# =============================================

# Variables
SHELL := /bin/bash
.DEFAULT_GOAL := help

# Colors for output
YELLOW := \033[1;33m
GREEN := \033[0;32m
RED := \033[0;31m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Docker variables
DOCKER_IMAGE := sentiment-api
DOCKER_TAG := latest
DOCKER_REGISTRY := ghcr.io/$(shell git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | tr '[:upper:]' '[:lower:]')

# Python variables
PYTHON := python3
PIP := $(PYTHON) -m pip
VENV := venv

# Kubernetes variables
NAMESPACE_DEV := ml-apps-dev
NAMESPACE_PROD := ml-apps-prod
CLUSTER_NAME := ml-ops-cluster

# Detect OS for commands
ifeq ($(OS),Windows_NT)
    ACTIVATE := $(VENV)\Scripts\activate
    RM := del /Q
    SEP := \\
else
    ACTIVATE := source $(VENV)/bin/activate
    RM := rm -f
    SEP := /
endif

.PHONY: help
help: ## Show this help message
	@echo "$(BLUE)MLOps Sentiment Analysis Pipeline$(NC)"
	@echo "==================================="
	@echo ""
	@echo "$(YELLOW)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

# ============================================
# Day 1: Local Development & API
# ============================================

.PHONY: setup
setup: ## Initial project setup
	@echo "$(YELLOW)Setting up project...$(NC)"
	$(PYTHON) -m venv $(VENV)
	$(ACTIVATE) && $(PIP) install --upgrade pip
	$(ACTIVATE) && $(PIP) install -r requirements-docker.txt
	$(ACTIVATE) && $(PIP) install -r requirements-test.txt
	@echo "$(GREEN)✓ Setup complete!$(NC)"

.PHONY: install
install: ## Install all dependencies
	@echo "$(YELLOW)Installing dependencies...$(NC)"
	$(ACTIVATE) && $(PIP) install -r requirements-docker.txt
	$(ACTIVATE) && $(PIP) install -r requirements-test.txt
	$(ACTIVATE) && $(PIP) install -r requirements-dev.txt 2>/dev/null || true
	@echo "$(GREEN)✓ Dependencies installed!$(NC)"

.PHONY: run
run: ## Run API locally
	@echo "$(YELLOW)Starting API server...$(NC)"
	@echo "$(GREEN)API: http://localhost:8000$(NC)"
	@echo "$(GREEN)Docs: http://localhost:8000/docs$(NC)"
	$(ACTIVATE) && $(PYTHON) -m uvicorn src.api.main_simple:app --reload --host 0.0.0.0 --port 8000

.PHONY: test
test: ## Run tests with coverage
	@echo "$(YELLOW)Running tests...$(NC)"
	$(ACTIVATE) && pytest tests/ -v --cov=src --cov-report=term-missing --cov-report=html
	@echo "$(GREEN)✓ Tests complete! Coverage report: htmlcov/index.html$(NC)"

.PHONY: test-api
test-api: ## Test API endpoints (requires running API)
	@echo "$(YELLOW)Testing API endpoints...$(NC)"
	@curl -s http://localhost:8000/health | jq . || echo "$(RED)API not running$(NC)"
	@echo ""
	@curl -s -X POST http://localhost:8000/predict \
		-H "Content-Type: application/json" \
		-d '{"texts": ["I love this!", "This is terrible"]}' | jq . || true

.PHONY: lint
lint: ## Run code linting
	@echo "$(YELLOW)Running linters...$(NC)"
	$(ACTIVATE) && black src/ tests/ --check || true
	$(ACTIVATE) && flake8 src/ tests/ --max-line-length=88 || true
	@echo "$(GREEN)✓ Linting complete!$(NC)"

.PHONY: format
format: ## Format code with black
	@echo "$(YELLOW)Formatting code...$(NC)"
	$(ACTIVATE) && black src/ tests/
	@echo "$(GREEN)✓ Code formatted!$(NC)"

# ============================================
# Day 2: Docker & Containerization
# ============================================

.PHONY: docker-build
docker-build: ## Build Docker image
	@echo "$(YELLOW)Building Docker image...$(NC)"
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .
	docker tag $(DOCKER_IMAGE):$(DOCKER_TAG) $(DOCKER_IMAGE):latest
	@echo "$(GREEN)✓ Docker image built: $(DOCKER_IMAGE):$(DOCKER_TAG)$(NC)"

.PHONY: docker-run
docker-run: docker-build ## Run Docker container
	@echo "$(YELLOW)Starting Docker container...$(NC)"
	docker run -d \
		--name $(DOCKER_IMAGE) \
		-p 8000:8000 \
		-e LOG_LEVEL=info \
		$(DOCKER_IMAGE):$(DOCKER_TAG)
	@echo "$(GREEN)✓ Container running at http://localhost:8000$(NC)"

.PHONY: docker-stop
docker-stop: ## Stop and remove Docker container
	@echo "$(YELLOW)Stopping Docker container...$(NC)"
	docker stop $(DOCKER_IMAGE) 2>/dev/null || true
	docker rm $(DOCKER_IMAGE) 2>/dev/null || true
	@echo "$(GREEN)✓ Container stopped$(NC)"

.PHONY: docker-logs
docker-logs: ## Show Docker container logs
	docker logs -f $(DOCKER_IMAGE)

.PHONY: docker-exec
docker-exec: ## Execute shell in Docker container
	docker exec -it $(DOCKER_IMAGE) /bin/bash

.PHONY: docker-push
docker-push: ## Push Docker image to registry
	@echo "$(YELLOW)Pushing to registry...$(NC)"
	docker tag $(DOCKER_IMAGE):$(DOCKER_TAG) $(DOCKER_REGISTRY)/$(DOCKER_IMAGE):$(DOCKER_TAG)
	docker push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE):$(DOCKER_TAG)
	@echo "$(GREEN)✓ Image pushed to $(DOCKER_REGISTRY)$(NC)"

.PHONY: docker-compose-up
docker-compose-up: ## Start services with docker-compose
	docker-compose up -d
	@echo "$(GREEN)✓ Services started$(NC)"

.PHONY: docker-compose-down
docker-compose-down: ## Stop services with docker-compose
	docker-compose down
	@echo "$(GREEN)✓ Services stopped$(NC)"

# ============================================
# Day 3: Kubernetes Orchestration
# ============================================

.PHONY: k8s-setup
k8s-setup: ## Setup local Kubernetes cluster
	@echo "$(YELLOW)Setting up Kubernetes...$(NC)"
	chmod +x scripts/setup-local-k8s.sh
	./scripts/setup-local-k8s.sh
	@echo "$(GREEN)✓ Kubernetes setup complete$(NC)"

.PHONY: k8s-deploy-dev
k8s-deploy-dev: docker-build ## Deploy to development environment
	@echo "$(YELLOW)Deploying to development...$(NC)"
	@if command -v kind > /dev/null 2>&1; then \
		kind load docker-image $(DOCKER_IMAGE):$(DOCKER_TAG) --name $(CLUSTER_NAME) 2>/dev/null || true; \
	fi
	kubectl apply -k k8s/overlays/dev
	kubectl wait --for=condition=available --timeout=300s deployment/dev-sentiment-api -n $(NAMESPACE_DEV) || true
	@echo "$(GREEN)✓ Deployed to development$(NC)"
	kubectl get pods -n $(NAMESPACE_DEV)

.PHONY: k8s-deploy-prod
k8s-deploy-prod: docker-build ## Deploy to production environment
	@echo "$(YELLOW)Deploying to production...$(NC)"
	kubectl apply -k k8s/overlays/prod
	kubectl wait --for=condition=available --timeout=300s deployment/prod-sentiment-api -n $(NAMESPACE_PROD)
	@echo "$(GREEN)✓ Deployed to production$(NC)"

.PHONY: k8s-delete-dev
k8s-delete-dev: ## Delete development deployment
	@echo "$(RED)Deleting development deployment...$(NC)"
	kubectl delete -k k8s/overlays/dev 2>/dev/null || true
	@echo "$(GREEN)✓ Development deployment deleted$(NC)"

.PHONY: k8s-delete-prod
k8s-delete-prod: ## Delete production deployment
	@echo "$(RED)Deleting production deployment...$(NC)"
	kubectl delete -k k8s/overlays/prod 2>/dev/null || true
	@echo "$(GREEN)✓ Production deployment deleted$(NC)"

.PHONY: k8s-logs
k8s-logs: ## Show pod logs from development
	@POD=$$(kubectl get pods -n $(NAMESPACE_DEV) -l app=sentiment-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -z "$$POD" ]; then \
		echo "$(RED)No pods found$(NC)"; \
	else \
		kubectl logs -n $(NAMESPACE_DEV) $$POD -f; \
	fi

.PHONY: k8s-forward
k8s-forward: ## Port forward to access service locally
	@echo "$(YELLOW)Port forwarding...$(NC)"
	@echo "$(GREEN)Access API at: http://localhost:8080$(NC)"
	kubectl port-forward -n $(NAMESPACE_DEV) svc/dev-sentiment-api 8080:80

.PHONY: k8s-exec
k8s-exec: ## Execute shell in Kubernetes pod
	@POD=$$(kubectl get pods -n $(NAMESPACE_DEV) -l app=sentiment-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -z "$$POD" ]; then \
		echo "$(RED)No pods found$(NC)"; \
	else \
		kubectl exec -it -n $(NAMESPACE_DEV) $$POD -- /bin/bash; \
	fi

.PHONY: k8s-describe
k8s-describe: ## Describe pods in development
	kubectl describe pods -n $(NAMESPACE_DEV) -l app=sentiment-api

.PHONY: k8s-events
k8s-events: ## Show Kubernetes events
	kubectl get events -n $(NAMESPACE_DEV) --sort-by='.lastTimestamp' | tail -20

.PHONY: k8s-status
k8s-status: ## Show Kubernetes deployment status
	@echo "$(YELLOW)=== Namespaces ===$(NC)"
	kubectl get namespaces | grep ml-apps || echo "No ml-apps namespaces"
	@echo ""
	@echo "$(YELLOW)=== Development Pods ===$(NC)"
	kubectl get pods -n $(NAMESPACE_DEV) 2>/dev/null || echo "No pods in development"
	@echo ""
	@echo "$(YELLOW)=== Services ===$(NC)"
	kubectl get svc -n $(NAMESPACE_DEV) 2>/dev/null || echo "No services"
	@echo ""
	@echo "$(YELLOW)=== HPA Status ===$(NC)"
	kubectl get hpa -n $(NAMESPACE_DEV) 2>/dev/null || echo "No HPA configured"

# ============================================
# Day 4: CI/CD & GitOps
# ============================================

.PHONY: argocd-setup
argocd-setup: ## Install and configure ArgoCD
	@echo "$(YELLOW)Setting up ArgoCD...$(NC)"
	chmod +x scripts/setup-argocd.sh
	./scripts/setup-argocd.sh
	@echo "$(GREEN)✓ ArgoCD setup complete$(NC)"

.PHONY: argocd-password
argocd-password: ## Get ArgoCD admin password
	@echo "$(YELLOW)ArgoCD admin password:$(NC)"
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
	@echo ""

.PHONY: argocd-ui
argocd-ui: ## Access ArgoCD UI (port-forward)
	@echo "$(YELLOW)ArgoCD UI:$(NC)"
	@echo "$(GREEN)URL: https://localhost:8443$(NC)"
	@echo "$(GREEN)Username: admin$(NC)"
	@echo "$(GREEN)Password: Run 'make argocd-password'$(NC)"
	kubectl port-forward svc/argocd-server -n argocd 8443:443

.PHONY: argocd-apps
argocd-apps: ## Deploy ArgoCD applications
	@echo "$(YELLOW)Deploying ArgoCD applications...$(NC)"
	kubectl apply -f argocd/applications/
	@echo "$(GREEN)✓ Applications deployed$(NC)"

.PHONY: monitoring-setup
monitoring-setup: ## Setup Prometheus and Grafana
	@echo "$(YELLOW)Setting up monitoring stack...$(NC)"
	kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f k8s/monitoring/
	@echo "$(GREEN)✓ Monitoring stack deployed$(NC)"

.PHONY: monitoring-prometheus
monitoring-prometheus: ## Access Prometheus UI
	@echo "$(YELLOW)Prometheus UI:$(NC)"
	@echo "$(GREEN)URL: http://localhost:9090$(NC)"
	kubectl port-forward -n monitoring svc/prometheus 9090:9090

.PHONY: monitoring-grafana
monitoring-grafana: ## Access Grafana UI
	@echo "$(YELLOW)Grafana UI:$(NC)"
	@echo "$(GREEN)URL: http://localhost:3000$(NC)"
	@echo "$(GREEN)Default: admin/admin$(NC)"
	kubectl port-forward -n monitoring svc/grafana 3000:3000

.PHONY: ci-local
ci-local: lint test docker-build ## Run CI pipeline locally
	@echo "$(GREEN)✓ Local CI pipeline passed!$(NC)"

.PHONY: github-secrets
github-secrets: ## Show required GitHub secrets
	@echo "$(YELLOW)Required GitHub Secrets:$(NC)"
	@echo "  DOCKER_USERNAME"
	@echo "  DOCKER_PASSWORD"
	@echo "  AWS_ACCESS_KEY_ID (if using AWS)"
	@echo "  AWS_SECRET_ACCESS_KEY (if using AWS)"
	@echo "  ARGOCD_SERVER"
	@echo "  ARGOCD_USERNAME"
	@echo "  ARGOCD_PASSWORD"

# ============================================
# Utility Commands
# ============================================

.PHONY: clean
clean: ## Clean up generated files and containers
	@echo "$(YELLOW)Cleaning up...$(NC)"
	$(RM) -rf $(VENV) __pycache__ .pytest_cache htmlcov .coverage
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	docker stop $(DOCKER_IMAGE) 2>/dev/null || true
	docker rm $(DOCKER_IMAGE) 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

.PHONY: check-tools
check-tools: ## Check required tools are installed
	@echo "$(YELLOW)Checking required tools...$(NC)"
	@command -v python3 >/dev/null 2>&1 && echo "$(GREEN)✓ Python3$(NC)" || echo "$(RED)✗ Python3$(NC)"
	@command -v docker >/dev/null 2>&1 && echo "$(GREEN)✓ Docker$(NC)" || echo "$(RED)✗ Docker$(NC)"
	@command -v kubectl >/dev/null 2>&1 && echo "$(GREEN)✓ kubectl$(NC)" || echo "$(RED)✗ kubectl$(NC)"
	@command -v kind >/dev/null 2>&1 && echo "$(GREEN)✓ kind$(NC)" || echo "$(RED)✗ kind (optional)$(NC)"
	@command -v argocd >/dev/null 2>&1 && echo "$(GREEN)✓ argocd CLI$(NC)" || echo "$(RED)✗ argocd CLI (optional)$(NC)"
	@command -v git >/dev/null 2>&1 && echo "$(GREEN)✓ Git$(NC)" || echo "$(RED)✗ Git$(NC)"

.PHONY: status
status: ## Show overall project status
	@echo "$(BLUE)=== MLOps Pipeline Status ===$(NC)"
	@echo ""
	@echo "$(YELLOW)Local Development:$(NC)"
	@ps aux | grep -v grep | grep "uvicorn.*main_simple" >/dev/null 2>&1 && echo "$(GREEN)✓ API running locally$(NC)" || echo "$(RED)✗ API not running$(NC)"
	@echo ""
	@echo "$(YELLOW)Docker:$(NC)"
	@docker ps | grep $(DOCKER_IMAGE) >/dev/null 2>&1 && echo "$(GREEN)✓ Container running$(NC)" || echo "$(RED)✗ Container not running$(NC)"
	@echo ""
	@echo "$(YELLOW)Kubernetes:$(NC)"
	@kubectl get nodes >/dev/null 2>&1 && echo "$(GREEN)✓ Cluster accessible$(NC)" || echo "$(RED)✗ Cluster not accessible$(NC)"
	@kubectl get pods -n $(NAMESPACE_DEV) 2>/dev/null | grep sentiment-api >/dev/null && echo "$(GREEN)✓ Pods running in dev$(NC)" || echo "$(RED)✗ No pods in dev$(NC)"
	@echo ""
	@echo "$(YELLOW)GitOps:$(NC)"
	@kubectl get pods -n argocd 2>/dev/null | grep argocd-server >/dev/null && echo "$(GREEN)✓ ArgoCD running$(NC)" || echo "$(RED)✗ ArgoCD not installed$(NC)"
	@echo ""
	@echo "$(YELLOW)Monitoring:$(NC)"
	@kubectl get pods -n monitoring 2>/dev/null | grep prometheus >/dev/null && echo "$(GREEN)✓ Prometheus running$(NC)" || echo "$(RED)✗ Prometheus not installed$(NC)"

# ============================================
# Quick Commands
# ============================================

.PHONY: quick-start
quick-start: setup run ## Quick start for development

.PHONY: quick-test
quick-test: docker-build k8s-deploy-dev k8s-forward ## Quick deploy and test

.PHONY: full-deploy
full-deploy: docker-build k8s-deploy-dev argocd-apps monitoring-setup ## Full deployment with GitOps

.PHONY: full-cleanup
full-cleanup: docker-stop k8s-delete-dev k8s-delete-prod clean ## Complete cleanup

# ============================================
# Day-specific Summary Commands
# ============================================

.PHONY: day1
day1: setup run test ## Day 1: Local API development

.PHONY: day2
day2: docker-build docker-run docker-logs ## Day 2: Docker containerization

.PHONY: day3
day3: k8s-setup k8s-deploy-dev k8s-forward ## Day 3: Kubernetes deployment

.PHONY: day4
day4: argocd-setup argocd-apps monitoring-setup ## Day 4: CI/CD and GitOps