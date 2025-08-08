#!/bin/bash
# setup-local-k8s.sh - Setup local Kubernetes with Kind

set -e

echo "🎯 Setting up local Kubernetes cluster with Kind"

# Check if kind is installed
if ! command -v kind &> /dev/null; then
    echo "📦 Installing Kind..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "📦 Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

# Create cluster
echo "🔨 Creating Kind cluster..."
kind create cluster --config kind-config.yaml

# Install NGINX Ingress Controller
echo "📦 Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress to be ready
echo "⏳ Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Install metrics server (for HPA)
echo "📦 Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch metrics server for local development
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Load Docker image into Kind
echo "🐳 Loading Docker image into Kind cluster..."
docker build -t sentiment-api:latest .
kind load docker-image sentiment-api:latest --name ml-ops-cluster

echo "✅ Local Kubernetes cluster ready!"
echo ""
echo "📝 Next steps:"
echo "1. Deploy the application: ./k8s-deploy.sh dev"
echo "2. Add to /etc/hosts: 127.0.0.1 sentiment-api-dev.local"
echo "3. Access the API: http://sentiment-api-dev.local"