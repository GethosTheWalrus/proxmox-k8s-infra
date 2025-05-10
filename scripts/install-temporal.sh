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
  --set server.service.type=LoadBalancer \
  --set "server.service.annotations.metallb\\.universe\\.tf/loadBalancerIPs=${LOAD_BALANCER_IP}" \
  --set cassandra.enabled=true \
  --set cassandra.replicaCount=3 \
  --set ui.enabled=true \
  --set ui.replicaCount=2 \
  --set server.persistence.size=10Gi \
  --set server.persistence.storageClass=openebs-hostpath \
  --set cassandra.persistence.size=10Gi \
  --set cassandra.persistence.storageClass=openebs-hostpath \
  --set server.services.frontend.type=LoadBalancer \
  --set "server.services.frontend.annotations.metallb\\.universe\\.tf/loadBalancerIPs=${LOAD_BALANCER_IP}" \
  --set web.service.type=LoadBalancer \
  --set "web.service.annotations.metallb\\.universe\\.tf/loadBalancerIPs=${LOAD_BALANCER_IP}" \
  --set schema.setup.enabled=true \
  --set schema.update.enabled=true \
  --set schema.setup.timeout=600s \
  --set schema.update.timeout=600s

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