#!/bin/bash
#
# Switch Temporal to use PgBouncer instead of direct PostgreSQL connection
# This script updates the Temporal configuration and restarts the services
#

set -e

echo "=== Switching Temporal to PgBouncer ==="
echo ""

# Step 1: Deploy PgBouncer
echo "Step 1: Deploying PgBouncer..."
kubectl apply -f k8s/07-pgbouncer.yaml

echo "Waiting for PgBouncer to be ready..."
kubectl wait --for=condition=ready pod -l app=pgbouncer -n temporal --timeout=60s

echo "✓ PgBouncer is running"
echo ""

# Step 2: Update Temporal ConfigMap
echo "Step 2: Updating Temporal configuration..."

# Backup current config
kubectl get configmap temporal-config -n temporal -o yaml > /tmp/temporal-config-backup-$(date +%Y%m%d_%H%M%S).yaml
echo "✓ Backed up current config to /tmp/"

# Patch the ConfigMap to use PgBouncer
kubectl get configmap temporal-config -n temporal -o yaml | \
  sed 's/connectAddr: "192.168.69.11:5432"/connectAddr: "pgbouncer.temporal.svc.cluster.local:5432"/g' | \
  kubectl apply -f -

echo "✓ Updated ConfigMap to use PgBouncer"
echo ""

# Step 3: Restart Temporal services
echo "Step 3: Restarting Temporal services to pick up new configuration..."

kubectl rollout restart deployment temporal-frontend -n temporal
kubectl rollout restart deployment temporal-history -n temporal
kubectl rollout restart deployment temporal-matching -n temporal
kubectl rollout restart deployment temporal-worker -n temporal
kubectl rollout restart deployment temporal-admintools -n temporal

echo "✓ Initiated rolling restart"
echo ""

# Step 4: Wait for deployments to be ready
echo "Step 4: Waiting for services to be ready (this may take 1-2 minutes)..."

kubectl rollout status deployment temporal-frontend -n temporal --timeout=120s
kubectl rollout status deployment temporal-history -n temporal --timeout=120s
kubectl rollout status deployment temporal-matching -n temporal --timeout=120s
kubectl rollout status deployment temporal-worker -n temporal --timeout=120s

echo ""
echo "✓ All services are ready!"
echo ""

# Step 5: Verify
echo "Step 5: Verifying the switch..."
echo ""
echo "Current pod status:"
kubectl get pods -n temporal
echo ""

echo "Checking database connections..."
sleep 5
./scripts/check-postgres-from-cluster.sh

echo ""
echo "=== Migration Complete ==="
echo ""
echo "Temporal is now using PgBouncer for database connections."
echo "You should see a significant reduction in idle database connections."
echo ""
echo "To revert to direct connection:"
echo "  kubectl apply -f /tmp/temporal-config-backup-*.yaml"
echo "  kubectl rollout restart deployment -n temporal"
