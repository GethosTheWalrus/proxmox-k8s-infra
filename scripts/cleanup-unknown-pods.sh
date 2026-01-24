#!/bin/bash
#
# Script to clean up pods stuck in Unknown state after a cluster restart
# Run this after a Proxmox host reboot to quickly recover Temporal services
#

set -e

echo "Checking for pods in Unknown state across all namespaces..."

# Find all pods in Unknown state
UNKNOWN_PODS=$(kubectl get pods -A --field-selector status.phase=Unknown -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name)"' || echo "")

if [ -z "$UNKNOWN_PODS" ]; then
    echo "✓ No pods in Unknown state found"
    exit 0
fi

echo "Found pods in Unknown state:"
echo "$UNKNOWN_PODS"
echo ""
echo "Force deleting these pods to allow Kubernetes to recreate them..."

# Delete each unknown pod
echo "$UNKNOWN_PODS" | while IFS=/ read -r namespace pod; do
    if [ -n "$namespace" ] && [ -n "$pod" ]; then
        echo "Deleting $namespace/$pod..."
        kubectl delete pod "$pod" -n "$namespace" --force --grace-period=0 2>&1 | grep -v "Warning: Immediate deletion"
    fi
done

echo ""
echo "✓ Cleanup complete. Waiting for pods to restart..."
sleep 5

echo ""
echo "Current status of Temporal pods:"
kubectl get pods -n temporal

echo ""
echo "To monitor pod recovery, run: kubectl get pods -n temporal -w"
