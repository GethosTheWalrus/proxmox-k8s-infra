#!/bin/bash

# Add OpenEBS Helm repository
helm repo add openebs https://openebs.github.io/charts
helm repo update

# Install OpenEBS
helm install openebs openebs/openebs \
  --namespace openebs \
  --create-namespace \
  --set localprovisioner.hostpathClass.isDefaultClass=true

# Wait for OpenEBS pods to be ready
kubectl wait --for=condition=ready pod -l app=openebs-localpv-provisioner -n openebs --timeout=300s 