#!/bin/bash

# Add OpenEBS Helm repository
helm repo add openebs https://openebs.github.io/charts
helm repo update

# Install OpenEBS with hostpath storage engine
helm install openebs openebs/openebs \
  --namespace openebs \
  --create-namespace \
  --set localprovisioner.hostpathClass.isDefaultClass=true \
  --set localprovisioner.enabled=true \
  --set ndm.enabled=true \
  --set ndmOperator.enabled=true

# Wait for namespace to be created
echo "Waiting for OpenEBS namespace..."
sleep 10

# Wait for pods to be created
echo "Waiting for OpenEBS pods to be created..."
sleep 30

# Show pod status and labels
echo "OpenEBS pods status and labels:"
kubectl get pods -n openebs --show-labels

# Show all labels in the namespace
echo "All labels in OpenEBS namespace:"
kubectl get all -n openebs --show-labels

# Wait for pods to be ready using the labels we see
echo "Waiting for OpenEBS pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=openebs -n openebs --timeout=300s || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=ndm -n openebs --timeout=300s || true

# Show final pod status
echo "Final OpenEBS pods status:"
kubectl get pods -n openebs 