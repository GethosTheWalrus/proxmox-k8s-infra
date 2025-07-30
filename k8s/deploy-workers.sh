#!/bin/bash

# Deploy Temporal Workers
# Run this after creating the registry secret and after the core infrastructure is deployed

set -e

echo "🔧 Deploying Temporal Workers..."

# Check if the registry secret exists
if ! kubectl get secret gitlab-registry-secret -n temporal &> /dev/null; then
    echo "❌ Registry secret not found!"
    echo "   Create it first with:"
    echo "   kubectl create secret docker-registry gitlab-registry-secret \\"
    echo "     --docker-server=git.home:5050 \\"
    echo "     --docker-username=<your-username> \\"
    echo "     --docker-password=<your-access-token> \\"
    echo "     --docker-email=<your-email> \\"
    echo "     --namespace=temporal"
    exit 1
fi

echo "✅ Registry secret found"

# Deploy workers
echo "🐍 Deploying Python worker..."
kubectl apply -f k8s/08-python-worker.yaml

echo "📜 Deploying TypeScript worker..."
kubectl apply -f k8s/09-typescript-worker.yaml

echo "🐹 Deploying Go worker..."
kubectl apply -f k8s/10-go-worker.yaml

echo "🟦 Deploying C# worker..."
kubectl apply -f k8s/11-csharp-worker.yaml

echo "⏳ Waiting for workers to be ready..."
kubectl wait --for=condition=available deployment/python-worker -n temporal --timeout=300s || echo "⚠️  Python worker may still be starting"
kubectl wait --for=condition=available deployment/typescript-worker -n temporal --timeout=300s || echo "⚠️  TypeScript worker may still be starting"
kubectl wait --for=condition=available deployment/go-worker -n temporal --timeout=300s || echo "⚠️  Go worker may still be starting"
kubectl wait --for=condition=available deployment/csharp-worker -n temporal --timeout=300s || echo "⚠️  C# worker may still be starting"

echo ""
echo "🎉 Worker deployment complete!"
echo ""
echo "📋 Worker Pod Status:"
kubectl get pods -n temporal -l component=worker
echo ""
echo "🔍 Worker Deployments:"
kubectl get deployments -n temporal -l component=worker
