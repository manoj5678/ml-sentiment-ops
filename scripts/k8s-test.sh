#!/bin/bash
# k8s-test.sh - Test Kubernetes deployment

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ENVIRONMENT=${1:-dev}
NAMESPACE=ml-apps-${ENVIRONMENT}

echo -e "${GREEN}🧪 Testing Sentiment API in Kubernetes${NC}"
echo -e "Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "Namespace: ${YELLOW}$NAMESPACE${NC}"

# Get pod name
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=sentiment-api -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD_NAME" ]; then
    echo -e "${RED}❌ No pods found${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Testing pod: $POD_NAME${NC}"

# Test 1: Check pod logs
echo -e "\n${YELLOW}1. Checking pod logs...${NC}"
kubectl logs -n $NAMESPACE $POD_NAME --tail=20

# Test 2: Test health endpoint from inside cluster
echo -e "\n${YELLOW}2. Testing health endpoint...${NC}"
kubectl exec -n $NAMESPACE $POD_NAME -- curl -s http://localhost:8000/health | jq . || echo "Failed"

# Test 3: Test through service
echo -e "\n${YELLOW}3. Testing through service...${NC}"
kubectl run -n $NAMESPACE test-curl --image=curlimages/curl --rm -it --restart=Never -- \
    curl -s http://${ENVIRONMENT}-sentiment-api/health | jq . || echo "Failed"

# Test 4: Test prediction endpoint
echo -e "\n${YELLOW}4. Testing prediction endpoint...${NC}"
kubectl run -n $NAMESPACE test-prediction --image=curlimages/curl --rm -it --restart=Never -- \
    curl -s -X POST http://${ENVIRONMENT}-sentiment-api/predict \
    -H "Content-Type: application/json" \
    -d '{"texts": ["I love Kubernetes!", "This deployment is amazing"]}' | jq . || echo "Failed"

# Test 5: Port forward for local testing
echo -e "\n${YELLOW}5. Setting up port forward for local testing...${NC}"
echo "Run this in another terminal:"
echo -e "${GREEN}kubectl port-forward -n $NAMESPACE svc/${ENVIRONMENT}-sentiment-api 8080:80${NC}"
echo ""
echo "Then test with:"
echo -e "${GREEN}curl http://localhost:8080/health${NC}"
echo -e "${GREEN}curl -X POST http://localhost:8080/predict -H 'Content-Type: application/json' -d '{\"texts\": [\"Test\"]}'${NC}"

# Test 6: Check resource usage
echo -e "\n${YELLOW}6. Resource usage:${NC}"
kubectl top pod -n $NAMESPACE -l app=sentiment-api || echo "Metrics server not installed"

# Test 7: Check HPA metrics
echo -e "\n${YELLOW}7. HPA metrics:${NC}"
kubectl get hpa -n $NAMESPACE

echo -e "\n${GREEN}✅ Tests complete!${NC}"