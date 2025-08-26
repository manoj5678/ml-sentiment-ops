#!/bin/bash
# fix-monitoring-structure.sh - Create proper monitoring structure

echo "📁 Creating complete monitoring structure..."

# Create monitoring directory if it doesn't exist
mkdir -p k8s/monitoring

# Create namespace
cat > k8s/monitoring/namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    name: monitoring
    app.kubernetes.io/part-of: ml-platform
EOF

# Create service account
cat > k8s/monitoring/serviceaccount.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
EOF

# Create cluster role
cat > k8s/monitoring/clusterrole.yaml << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions", "apps"]
  resources:
  - deployments
  verbs: ["get", "list", "watch"]
EOF

# Create cluster role binding
cat > k8s/monitoring/clusterrolebinding.yaml << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
EOF

# Create Prometheus ConfigMap
cat > k8s/monitoring/prometheus-configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    scrape_configs:
      - job_name: 'sentiment-api-pods'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names:
                - ml-apps-dev
                - ml-apps-prod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: kubernetes_pod_name
EOF

# Create Prometheus Deployment
cat > k8s/monitoring/prometheus-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
  labels:
    app: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:v2.37.0
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus/'
          - '--web.enable-lifecycle'
        ports:
        - containerPort: 9090
          name: http
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: storage
          mountPath: /prometheus
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: storage
        emptyDir: {}
EOF

# Create Prometheus Service
cat > k8s/monitoring/prometheus-service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
  labels:
    app: prometheus
spec:
  type: ClusterIP
  ports:
  - port: 9090
    targetPort: 9090
    name: http
  selector:
    app: prometheus
EOF

# Create Grafana Deployment
cat > k8s/monitoring/grafana-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
  labels:
    app: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:9.1.0
        ports:
        - containerPort: 3000
          name: http
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "admin"
        - name: GF_INSTALL_PLUGINS
          value: "prometheus"
        volumeMounts:
        - name: storage
          mountPath: /var/lib/grafana
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
      volumes:
      - name: storage
        emptyDir: {}
EOF

# Create Grafana Service
cat > k8s/monitoring/grafana-service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
  labels:
    app: grafana
spec:
  type: ClusterIP
  ports:
  - port: 3000
    targetPort: 3000
    name: http
  selector:
    app: grafana
EOF

# Create Kustomization file
cat > k8s/monitoring/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: monitoring

resources:
  - namespace.yaml
  - serviceaccount.yaml
  - clusterrole.yaml
  - clusterrolebinding.yaml
  - prometheus-configmap.yaml
  - prometheus-deployment.yaml
  - prometheus-service.yaml
  - grafana-deployment.yaml
  - grafana-service.yaml

commonLabels:
  app.kubernetes.io/part-of: ml-platform-monitoring
EOF

echo "✅ Monitoring structure created!"
echo ""
echo "📂 Files created in k8s/monitoring/:"
ls -la k8s/monitoring/
echo ""
echo "🚀 Deploy monitoring stack with:"
echo "   kubectl apply -k k8s/monitoring/"
echo "   # or"
echo "   make monitoring-setup"















