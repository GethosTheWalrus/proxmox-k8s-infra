#!/bin/bash
# This script fixes the secure cookie issue for Temporal Web UI over HTTP

echo "Upgrading Temporal deployment to fix secure cookie issue..."

helm upgrade temporal temporal/temporal \
  --namespace temporal \
  --reuse-values \
  --set web.config.auth.enabled=false

echo ""
echo "Waiting for web pods to restart..."
kubectl rollout status deployment/temporal-web -n temporal --timeout=300s

echo ""
echo "Temporal Web UI has been updated!"
echo "Access it at: http://192.168.69.97:8080"
echo ""
echo "The secure cookie issue should now be resolved."
