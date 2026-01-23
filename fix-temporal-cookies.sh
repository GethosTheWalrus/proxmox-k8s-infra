#!/bin/bash
# This script fixes the secure cookie issue for Temporal Web UI over HTTP 

echo "Upgrading Temporal deployment to fix secure cookie issue..."

# The Temporal UI sets cookies as secure by default
# We need to explicitly disable this for HTTP access
helm upgrade temporal temporal/temporal \
  --namespace temporal \
  --reuse-values \
  --set web.additionalEnv[0].name=TEMPORAL_CSRF_COOKIE_INSECURE \
  --set web.additionalEnv[0].value=true

echo ""
echo "Waiting for web pods to restart..."
kubectl rollout status deployment/temporal-web -n temporal --timeout=300s

echo ""
echo "Temporal Web UI has been updated!"
echo "Access it at: http://192.168.69.97:8080"
echo ""
echo "The secure cookie issue should now be resolved."
