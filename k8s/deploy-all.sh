#!/bin/bash

# Deploy all Kubernetes resources for the Proxmox K8s Infrastructure
# This script applies all the YAML manifests in the correct order

set -e

echo "🚀 Starting deployment of Proxmox K8s Infrastructure..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    echo "   Make sure your kubeconfig is properly configured"
    exit 1
fi

echo "✅ Connected to Kubernetes cluster"

# Apply manifests in order
echo "📦 Applying MetalLB configuration..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
kubectl apply -f k8s/01-metallb-namespace.yaml

echo "⏳ Waiting for MetalLB to be ready..."
kubectl wait --namespace metallb-system \
    --for=condition=ready pod \
    --selector=app=metallb \
    --timeout=300s

echo "🔧 Applying MetalLB IP pool configuration..."
kubectl apply -f k8s/02-metallb-config.yaml

echo "💾 Applying OpenEBS configuration..."
kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml
kubectl apply -f k8s/03-openebs-namespace.yaml
kubectl apply -f k8s/04-openebs-storage-class.yaml

echo "⏳ Waiting for OpenEBS to be ready..."
kubectl wait --namespace openebs \
    --for=condition=ready pod \
    --selector=app=openebs \
    --timeout=300s || echo "⚠️  Some OpenEBS pods may still be starting, continuing..."

echo "🌐 Deploying Nginx test application..."
kubectl apply -f k8s/05-nginx-deployment.yaml

echo "⏳ Waiting for Nginx to be ready..."
kubectl wait --for=condition=available deployment/nginx --timeout=300s

echo "🕐 Deploying Temporal..."
kubectl apply -f k8s/06-temporal-namespace.yaml

# Install Temporal via Helm (this should be done after OpenEBS is ready)
echo "📊 Installing Temporal via Helm..."
helm repo add temporal https://temporalio.github.io/helm-charts || true
helm repo update

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
    --set web.enabled=true \
    --set web.replicaCount=2 \
    --set web.service.type=ClusterIP \
    --set web.service.port=8080 \
    --set web.config.cors.cookieInsecure=true \
    --set web.config.cors.origins="*" \
    --set web.config.cors.allowCredentials=true

echo "⏳ Waiting for Temporal to be ready..."
kubectl wait --for=condition=available deployment/temporal-web -n temporal --timeout=600s

echo "🔗 Applying Temporal LoadBalancer services..."
kubectl apply -f k8s/07-temporal-loadbalancers.yaml

echo "🚧 Note: Worker deployments require Docker registry credentials."
echo "   Create the registry secret first:"
echo "   kubectl create secret docker-registry gitlab-registry-secret \\"
echo "     --docker-server=git.home:5050 \\"
echo "     --docker-username=<your-username> \\"
echo "     --docker-password=<your-access-token> \\"
echo "     --docker-email=<your-email> \\"
echo "     --namespace=temporal"
echo ""
echo "   Then deploy workers:"
echo "   kubectl apply -f k8s/08-python-worker.yaml"
echo "   kubectl apply -f k8s/09-typescript-worker.yaml"
echo "   kubectl apply -f k8s/10-go-worker.yaml"
echo "   kubectl apply -f k8s/11-csharp-worker.yaml"

echo ""
echo "🎉 Core infrastructure deployment complete!"
echo ""
echo "📊 Service Status:"
kubectl get services --all-namespaces | grep -E "(LoadBalancer|nginx|temporal)"
echo ""
echo "📋 Pod Status:"
kubectl get pods --all-namespaces | grep -E "(nginx|temporal|openebs|metallb)"
echo ""
echo "🔗 Access Information:"
echo "   Nginx: Check LoadBalancer IP in services above"
echo "   Temporal Frontend: http://192.168.69.98:7233 (adjust IP in LoadBalancer config)"
echo "   Temporal Web UI: http://192.168.69.97:8080 (adjust IP in LoadBalancer config)"
