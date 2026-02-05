#!/bin/bash
# Script to completely reinstall Temporal to fix broken state

echo "=== Completely reinstalling Temporal ==="
echo ""

echo "Step 1: Deleting current Temporal deployment..."
helm uninstall temporal -n temporal 2>&1 || true

echo ""
echo "Step 2: Waiting for pods to terminate..."
sleep 10

echo ""
echo "Step 3: Cleaning up any remaining resources..."
kubectl delete deployment --all -n temporal 2>&1 || true
kubectl delete pod --all -n temporal 2>&1 || true
kubectl delete job --all -n temporal 2>&1 || true

echo ""
echo "Step 4: Waiting for cleanup..."
sleep 5

echo ""
echo "Step 5: Running fresh Temporal deployment..."
./deploy-all.sh temporal-install

echo ""
echo "Step 6: Waiting for services to become ready..."
echo "Waiting for frontend pods..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=frontend -n temporal --timeout=300s 2>&1 || echo "Frontend pods may still be starting..."

echo ""
echo "Waiting for web pods..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=web -n temporal --timeout=300s 2>&1 || echo "Web pods may still be starting..."

echo ""
echo "=== Reinstall complete ==="
echo ""
echo "Checking pod status:"
kubectl get pods -n temporal

echo ""
echo "Testing web UI:"
curl -sI http://192.168.69.97:8080/ | head -15

echo ""
echo "Testing API:"
curl -s http://192.168.69.97:8080/api/v1/namespaces 2>&1 | head -10
