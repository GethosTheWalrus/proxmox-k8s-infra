#!/bin/bash 

# --- Script to deploy Metallb ---

# --- Configuration (can be passed as environment variables or arguments) ---
K8S1="${K8S1:?Error: K8S1 is not set (Master Node IP)}"
METALLB_NAMESPACE="${METALLB_NAMESPACE:-metallb-system}" # Default namespace
IP_RANGE="${IP_RANGE:?Error: IP_RANGE is not set}"

# --- Ensure required tools are installed (assuming alpine/k8s image already has them or CI's before_script handles it) ---
# apk --no-cache add openssh-client kubectl helm # Moved to CI's before_script

# --- Setup kubectl kubeconfig ---
mkdir -p ~/.kube
scp -i key -o StrictHostKeyChecking=no k8s@"$K8S1":~/.kube/config ~/.kube/config
export KUBECONFIG=~/.kube/config

# --- Helm Repository Setup ---
echo "--- Helm Repository Setup ---"
helm repo add metallb https://metallb.github.io/metallb
helm repo update

# --- Create Metallb Namespace ---
echo "--- Creating Metallb Namespace: ${METALLB_NAMESPACE} ---"
kubectl create namespace --dry-run=client -o yaml "$METALLB_NAMESPACE" | kubectl apply -f -

# --- Install/Upgrade Metallb Helm Chart ---
echo "--- Installing/Upgrading Metallb Helm Chart in namespace: ${METALLB_NAMESPACE} ---"
helm upgrade --install metallb metallb/metallb -n "$METALLB_NAMESPACE"

# --- Wait for webhook deployment to be ready ---
echo "--- Waiting for metallb-webhook service to be ready ---"
WEBHOOK_READY=false
for i in {1..12}; do # Retry loop
  kubectl get service -n "$METALLB_NAMESPACE" | grep metallb-webhook-service | wc -l
  WEBHOOK_STATUS=$?
  if [ "$WEBHOOK_STATUS" -eq 0 ]; then
    WEBHOOK_READY=true
    echo "metallb-webhook deployment is ready!"
    break
  else
    echo "metallb-webhook deployment not yet ready, retry attempt $i..."
    kubectl get pod -n "$METALLB_NAMESPACE" -l app=metallb,component=webhook # Check pod status during wait
    sleep 10
  fi
done

if [ "$WEBHOOK_READY" == false ]; then
  echo "ERROR: metallb-webhook deployment failed to become ready after multiple retries. Exiting."
  kubectl get deployment/metallb-webhook -n "$METALLB_NAMESPACE" -o yaml
  kubectl get pods -n "$METALLB_NAMESPACE" -l app=metallb,component=webhook -o yaml
  kubectl logs -n "$METALLB_NAMESPACE" -l app=metallb,component=webhook --all-containers
  exit 1
fi
echo "metallb-webhook deployment readiness confirmed."

# --- Apply IPAddressPool and L2Advertisement configurations ---
echo "--- Applying IPAddressPool and L2Advertisement configurations ---"
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: $METALLB_NAMESPACE
spec:
  addresses:
  - $IP_RANGE
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: $METALLB_NAMESPACE
EOF

echo "Metallb deployment script completed successfully!"