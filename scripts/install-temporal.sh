#!/bin/bash

# Add Temporal Helm repository
helm repo add temporal https://temporalio.github.io/helm-charts
helm repo update

# Create namespace if it doesn't exist
kubectl create namespace temporal --dry-run=client -o yaml | kubectl apply -f -

# Install Temporal with Helm
helm upgrade --install temporal temporal/temporal \
  --namespace temporal \
  --version 0.62.0 \
  --set server.replicaCount=3 \
  --set cassandra.enabled=true \
  --set cassandra.replicaCount=3 \
  --set ui.enabled=true \
  --set ui.replicaCount=2 \
  --set server.persistence.size=10Gi \
  --set server.persistence.storageClass=openebs-hostpath \
  --set cassandra.persistence.size=10Gi \
  --set cassandra.persistence.storageClass=openebs-hostpath \
  --set schema.setup.enabled=true \
  --set schema.update.enabled=true \
  --set schema.setup.timeout=600s \
  --set schema.update.timeout=600s \
  --set web.config.cors.origins="*" \
  --set web.config.auth.enabled=false \
  --set web.config.csrfKey="temporal-csrf-key" \
  --set web.config.cors.allowCredentials=true

# Wait for initial deployment
echo "Waiting for initial deployment..."
sleep 30

# Create separate LoadBalancer services for frontend (7233) and web UI (8080)
echo "Creating LoadBalancer service for Temporal frontend (port 7233)..."
cat > temporal-frontend-lb.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: temporal-frontend-lb
  namespace: temporal
  annotations:
    metallb.universe.tf/loadBalancerIPs: ${LOAD_BALANCER_IP}
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: temporal
    app.kubernetes.io/component: frontend
  ports:
  - name: frontend
    port: 7233
    targetPort: 7233
    protocol: TCP
  - name: membership
    port: 6933
    targetPort: 6933
    protocol: TCP
EOF

echo "Creating LoadBalancer service for Temporal Web UI (port 8080)..."
cat > temporal-web-lb.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: temporal-web-lb
  namespace: temporal
  annotations:
    metallb.universe.tf/loadBalancerIPs: ${WEB_UI_IP}
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/component: web
    app.kubernetes.io/instance: temporal
    app.kubernetes.io/name: temporal
  ports:
  - name: http
    port: 8080
    targetPort: http
    protocol: TCP
EOF

kubectl apply -f temporal-frontend-lb.yaml
kubectl apply -f temporal-web-lb.yaml

# Create a ConfigMap for Web UI configuration to properly handle CSRF
echo "Creating Web UI configuration..."
cat > temporal-web-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: temporal-web-config
  namespace: temporal
data:
  config.yaml: |
    server:
      port: 8080
    temporal:
      grpc-endpoint: temporal-frontend:7233
    cors:
      origins:
        - "*"
      allow-credentials: true
    auth:
      enabled: false
    csrf:
      key: temporal-csrf-key
      secure: false
      same-site: lax
EOF

kubectl apply -f temporal-web-config.yaml

# Patch the web deployment to use the configuration
echo "Patching Web UI deployment with CSRF configuration..."
kubectl patch deployment temporal-web -n temporal -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "temporal-web",
            "env": [
              {
                "name": "TEMPORAL_CSRF_COOKIE_INSECURE",
                "value": "true"
              },
              {
                "name": "TEMPORAL_PERMIT_WRITE_API",
                "value": "true"
              },
              {
                "name": "TEMPORAL_CORS_ORIGINS",
                "value": "*"
              }
            ],
            "volumeMounts": [
              {
                "name": "web-config",
                "mountPath": "/etc/temporal/config",
                "readOnly": true
              }
            ]
          }
        ],
        "volumes": [
          {
            "name": "web-config",
            "configMap": {
              "name": "temporal-web-config"
            }
          }
        ]
      }
    }
  }
}'

echo "Waiting for LoadBalancer services to get IP addresses..."
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].ip}'="${LOAD_BALANCER_IP}" service/temporal-frontend-lb -n temporal --timeout=300s || true
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].ip}'="${WEB_UI_IP}" service/temporal-web-lb -n temporal --timeout=300s || true

echo "Verifying LoadBalancer services..."
echo "Frontend service:"
kubectl get service temporal-frontend-lb -n temporal -o wide
echo "Web UI service:"
kubectl get service temporal-web-lb -n temporal -o wide

echo "Checking for Web UI pods..."
kubectl get pods -n temporal -l app.kubernetes.io/component=web

echo "Testing internal connectivity to Web UI..."
kubectl run test-web-connectivity --image=busybox --restart=Never -n temporal --rm -i --tty -- sh -c "nc -zv temporal-web.temporal.svc.cluster.local 8080 && echo 'Web UI internal connectivity OK'" || true

# Wait for schema setup to complete
echo "Waiting for schema setup to complete..."
kubectl wait --for=condition=complete job/temporal-schema-1 -n temporal --timeout=600s || true

# Wait for all pods to be ready
echo "Waiting for all pods to be ready..."

# Function to check if all pods are ready
check_pods_ready() {
  # Get all pods in the namespace
  local pods=$(kubectl get pods -n temporal -o jsonpath='{.items[*].metadata.name}')
  local all_ready=true

  for pod in $pods; do
    # Skip completed jobs
    if [[ $pod == temporal-schema* ]]; then
      continue
    fi
    
    # Check if pod is ready
    local ready=$(kubectl get pod $pod -n temporal -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    if [[ $ready != "True" ]]; then
      all_ready=false
      break
    fi
  done

  echo $all_ready
}

# Wait for pods to be ready with timeout
timeout=600
interval=10
elapsed=0

while [ $elapsed -lt $timeout ]; do
  if [[ $(check_pods_ready) == "true" ]]; then
    echo "All pods are ready!"
    break
  fi
  
  echo "Waiting for pods to be ready... ($elapsed/$timeout seconds)"
  sleep $interval
  elapsed=$((elapsed + interval))
done

if [ $elapsed -ge $timeout ]; then
  echo "Timeout waiting for pods to be ready"
  exit 1
fi

# Show final pod status
echo "Final pod status:"
kubectl get pods -n temporal 

# Register the default namespace in Temporal
echo "Registering default namespace in Temporal..."
kubectl exec -n temporal deployment/temporal-admintools -- tctl --namespace default namespace register || {
  echo "Failed to register namespace, trying alternative method..."
  kubectl exec -n temporal deployment/temporal-admintools -- tctl namespace register --namespace default --description "Default namespace" || true
}

# Verify namespace registration
echo "Verifying namespace registration..."
kubectl exec -n temporal deployment/temporal-admintools -- tctl namespace list || true

echo ""
echo "================================"
echo "Temporal installation complete!"
echo "Frontend: http://${LOAD_BALANCER_IP}:7233"
echo "Web UI: http://${WEB_UI_IP}:8080"
echo "CSRF token issues should now be resolved."
echo "================================"