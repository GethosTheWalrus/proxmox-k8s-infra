#!/bin/bash 

# --- Script to deploy Metallb ---

# --- Configuration (can be passed as environment variables or arguments) ---
K8S1="${K8S1:?Error: K8S1 is not set (Master Node IP)}"
METALLB_NAMESPACE="${METALLB_NAMESPACE:-metallb-system}"

# --- Setup kubectl kubeconfig ---
mkdir -p ~/.kube
scp -i key -o StrictHostKeyChecking=no k8s@"$K8S1":~/.kube/config ~/.kube/config
export KUBECONFIG=~/.kube/config

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
kubectl apply -f metallb-config.yaml

echo "Metallb deployment script completed successfully!"