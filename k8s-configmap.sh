#!/bin/bash
# fix-k8s-configmap.sh - Fix the ConfigMap generation issue

echo "🔧 Fixing Kustomize ConfigMap issue..."

# Option 1: Remove configmap.yaml from base (recommended)
if [ -f "k8s/base/configmap.yaml" ]; then
    echo "Moving base configmap.yaml to backup..."
    mv k8s/base/configmap.yaml k8s/base/configmap.yaml.backup
fi

# Update base kustomization.yaml
echo "Updating base kustomization.yaml..."
cat > k8s/base/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
  - hpa.yaml
  - ingress.yaml

commonLabels:
  app.kubernetes.io/name: sentiment-api
  app.kubernetes.io/component: backend
EOF

# Update dev overlay
echo "Updating dev overlay..."
cat > k8s/overlays/dev/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ml-apps-dev

resources:
  - ../../base

namePrefix: dev-

replicas:
  - name: sentiment-api
    count: 1

# Generate ConfigMap for dev
configMapGenerator:
  - name: sentiment-api-config
    literals:
      - log_level=debug
      - environment=development
      - api_timeout=30
      - max_batch_size=10

patchesJson6902:
  - target:
      group: apps
      version: v1
      kind: Deployment
      name: sentiment-api
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/memory
        value: "128Mi"
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/cpu
        value: "100m"
EOF

# Update prod overlay
echo "Updating prod overlay..."
cat > k8s/overlays/prod/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ml-apps-prod

resources:
  - ../../base

namePrefix: prod-

replicas:
  - name: sentiment-api
    count: 3

# Generate ConfigMap for prod
configMapGenerator:
  - name: sentiment-api-config
    literals:
      - log_level=info
      - environment=production
      - api_timeout=30
      - max_batch_size=10

patchesJson6902:
  - target:
      group: apps
      version: v1
      kind: Deployment
      name: sentiment-api
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/memory
        value: "256Mi"
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/cpu
        value: "250m"
EOF

echo "✅ Fixed! Now testing..."
echo ""

# Test the configuration
echo "Testing dev overlay:"
kubectl kustomize k8s/overlays/dev > /tmp/dev-manifest.yaml && echo "✅ Dev overlay is valid!" || echo "❌ Dev overlay has errors"

echo ""
echo "Testing prod overlay:"
kubectl kustomize k8s/overlays/prod > /tmp/prod-manifest.yaml && echo "✅ Prod overlay is valid!" || echo "❌ Prod overlay has errors"

echo ""
echo "📝 You can view the generated manifests:"
echo "  - Dev: /tmp/dev-manifest.yaml"
echo "  - Prod: /tmp/prod-manifest.yaml"