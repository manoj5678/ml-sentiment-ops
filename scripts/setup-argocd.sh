#!/bin/bash
# scripts/setup-argocd.sh - Install and configure ArgoCD (Fixed version)

set -e

echo "🚀 Setting up ArgoCD for GitOps"
echo "==============================="

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install it first."
    exit 1
fi

# Create namespace
echo "📦 Creating ArgoCD namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo "📦 Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD to be ready..."
echo "This may take a few minutes..."

# Wait for deployments with timeout
DEPLOYMENTS="argocd-server argocd-repo-server argocd-redis argocd-applicationset-controller argocd-notifications-controller"
for deployment in $DEPLOYMENTS; do
    echo "Waiting for $deployment..."
    kubectl wait --for=condition=available --timeout=300s deployment/$deployment -n argocd || {
        echo "⚠️  Warning: $deployment is taking longer than expected"
    }
done

# Get initial admin password
echo ""
echo "🔑 Getting ArgoCD admin password..."
# Wait for secret to be created
for i in {1..30}; do
    if kubectl -n argocd get secret argocd-initial-admin-secret &>/dev/null; then
        break
    fi
    echo "Waiting for admin secret to be created..."
    sleep 2
done

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
if [ -z "$ARGOCD_PASSWORD" ]; then
    echo "⚠️  Warning: Could not retrieve admin password. The secret might not be created yet."
    echo "Try running: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
else
    echo "==========================================="
    echo "ArgoCD Admin Credentials:"
    echo "Username: admin"
    echo "Password: $ARGOCD_PASSWORD"
    echo "==========================================="
    echo "⚠️  Save this password! You'll need it to login."
fi

# Check if ingress controller exists before creating ingress
echo ""
echo "📌 Checking for Ingress controller..."
if kubectl get ingressclass 2>/dev/null | grep -q nginx; then
    echo "✅ NGINX Ingress Controller found, creating ArgoCD Ingress..."
    
    # Create ArgoCD Ingress with error handling
    cat << 'EOF' | kubectl apply -f - || echo "⚠️  Failed to create Ingress. You can create it later."
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  rules:
  - host: argocd.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
EOF
else
    echo "⚠️  No Ingress Controller found. Skipping Ingress creation."
    echo "   You can access ArgoCD using port-forward instead."
fi

# Create NodePort service as alternative access method
echo ""
echo "📌 Creating NodePort service for alternative access..."
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-nodeport
  namespace: argocd
spec:
  type: NodePort
  ports:
  - port: 443
    nodePort: 30443
    targetPort: 8080
    protocol: TCP
    name: https
  selector:
    app.kubernetes.io/name: argocd-server
EOF

# Install ArgoCD CLI
echo ""
echo "📦 Installing ArgoCD CLI..."
ARGOCD_VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
echo "Latest ArgoCD version: $ARGOCD_VERSION"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    ARCH="amd64"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="darwin"
    ARCH="amd64"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    OS="windows"
    ARCH="amd64"
else
    echo "⚠️  Unsupported OS. Please install ArgoCD CLI manually."
    OS="unsupported"
fi

if [ "$OS" != "unsupported" ]; then
    DOWNLOAD_URL="https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-${OS}-${ARCH}"
    if [ "$OS" == "windows" ]; then
        DOWNLOAD_URL="${DOWNLOAD_URL}.exe"
    fi
    
    echo "Downloading from: $DOWNLOAD_URL"
    curl -sSL -o /tmp/argocd $DOWNLOAD_URL || {
        echo "⚠️  Failed to download ArgoCD CLI. You can install it manually later."
    }
    
    if [ -f /tmp/argocd ]; then
        chmod +x /tmp/argocd
        sudo mv /tmp/argocd /usr/local/bin/argocd 2>/dev/null || {
            mkdir -p ~/bin
            mv /tmp/argocd ~/bin/argocd
            echo "✅ ArgoCD CLI installed in ~/bin/"
            echo "   Add ~/bin to your PATH if needed: export PATH=\$PATH:~/bin"
        }
    fi
fi

# Get cluster info
echo ""
echo "📊 Cluster Information:"
kubectl cluster-info

echo ""
echo "✅ ArgoCD setup complete!"
echo ""
echo "📋 Access Methods:"
echo ""
echo "Option 1 - Port Forward (Recommended):"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Access: https://localhost:8080"
echo ""

# Check if NodePort is accessible
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
if [ ! -z "$NODE_IP" ]; then
    echo "Option 2 - NodePort:"
    echo "  Access: https://$NODE_IP:30443"
    echo ""
fi

if kubectl get ingress argocd-server-ingress -n argocd &>/dev/null; then
    echo "Option 3 - Ingress (if configured):"
    echo "  Add to /etc/hosts: 127.0.0.1 argocd.local"
    echo "  Access: https://argocd.local"
    echo ""
fi

echo "📋 Login Credentials:"
echo "  Username: admin"
if [ ! -z "$ARGOCD_PASSWORD" ]; then
    echo "  Password: $ARGOCD_PASSWORD"
else
    echo "  Password: Run this command to get it:"
    echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
fi

echo ""
echo "📋 Next Steps:"
echo "1. Access ArgoCD using one of the methods above"
echo "2. Login with the admin credentials"
echo "3. Apply ArgoCD applications:"
echo "   kubectl apply -f argocd/applications/"
echo ""
echo "⚠️  If you encountered errors, check:"
echo "   kubectl get pods -n argocd"
echo "   kubectl describe pod <pod-name> -n argocd"