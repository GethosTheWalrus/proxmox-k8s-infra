#!/bin/bash

# --- Script to deploy Metallb ---

# --- Configuration (can be passed as environment variables or arguments) ---
K8S1="${K8S1:?Error: K8S1 is not set (Master Node IP)}"
METALLB_NAMESPACE="${METALLB_NAMESPACE:-metallb-system}"

# --- Setup kubectl kubeconfig ---
mkdir -p ~/.kube
scp -i key -o StrictHostKeyChecking=no k8s@"$K8S1":~/.kube/config ~/.kube/config
export KUBECONFIG=~/.kube/config

# --- Deploy MetalLB ---
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml

echo "Waiting for MetalLB pods to become ready..."

# Wait for controller and speaker pods to be ready
kubectl wait --namespace $METALLB_NAMESPACE \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=300s

echo "Waiting for MetalLB webhook service to become available..."

# Wait for the webhook service to be ready
WEBHOOK_URL="https://metallb-webhook-service.$METALLB_NAMESPACE.svc:443/validate-metallb-io-v1beta1-ipaddresspool"

for i in {1..30}; do
  if curl -k --max-time 5 "$WEBHOOK_URL"; then
    echo "MetalLB webhook is ready!"
    break
  fi
  echo "Retrying webhook check ($i/30)..."
  sleep 10
done

# Apply MetalLB configuration once ready
kubectl apply -f metallb-config.yaml

echo "Metallb deployment script completed successfully!"
