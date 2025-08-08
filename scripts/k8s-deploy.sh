#!/bin/bash
# k8s-deploy.sh - Deploy to Kubernetes

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Default values
ENVIRONMENT=${1:-dev}
DOCKER_REGISTRY=${DOCKER_REGISTRY:-"docker.io/yourusername"}
IMAGE_TAG=${2:-latest}

echo -e "${GREEN}🚀 Deploying Sentiment API to Kubernetes${NC}"
echo -e "Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "Image tag: ${YELLOW}$IMAGE_TAG${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi

# Check cluster connection
echo -e "\n${YELLOW}Checking cluster connection...${NC}"
kubectl cluster-info || {
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    exit 1
}

# Build and push Docker image (if using remote registry)
if [ "$DOCKER_REGISTRY" != "local" ]; then
    echo -e "\n${YELLOW}Building and pushing Docker image...${NC}"
    docker build -t sentiment-api:$IMAGE_TAG .
    docker tag sentiment-api:$IMAGE_TAG $DOCKER_REGISTRY/sentiment-api:$IMAGE_TAG
    docker push $DOCKER_REGISTRY/sentiment-api:$IMAGE_TAG
else
    # For local development with kind/minikube
    echo -e "\n${YELLOW}Using local Docker image...${NC}"
    # For kind: kind load docker-image sentiment-api:$IMAGE_TAG
    # For minikube: eval $(minikube docker-env) && docker build -t sentiment-api:$IMAGE_TAG .
fi

# Apply Kubernetes manifests using Kustomize
echo -e "\n${YELLOW}Applying Kubernetes manifests...${NC}"
cd k8s/overlays/$ENVIRONMENT

# Dry run first
kubectl kustomize . | kubectl apply --dry-run=client -f - || {
    echo -e "${RED}❌ Dry run failed${NC}"
    exit 1
}

# Apply for real
kubectl kustomize . | kubectl apply -f -

# Wait for deployment
echo -e "\n${YELLOW}Waiting for deployment to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s \
    deployment/${ENVIRONMENT}-sentiment-api \
    -n ml-apps-${ENVIRONMENT}

# Check pod status
echo -e "\n${GREEN}✅ Deployment complete!${NC}"
echo -e "\n${YELLOW}Pod status:${NC}"
kubectl get pods -n ml-apps-${ENVIRONMENT} -l app=sentiment-api

# Get service info
echo -e "\n${YELLOW}Service info:${NC}"
kubectl get svc -n ml-apps-${ENVIRONMENT} ${ENVIRONMENT}-sentiment-api

# Show ingress info
echo -e "\n${YELLOW}Ingress info:${NC}"
kubectl get ingress -n ml-apps-${ENVIRONMENT}

# Show HPA status
echo -e "\n${YELLOW}HPA status:${NC}"
kubectl get hpa -n ml-apps-${ENVIRONMENT}

echo -e "\n${GREEN}🎉 Deployment successful!${NC}"