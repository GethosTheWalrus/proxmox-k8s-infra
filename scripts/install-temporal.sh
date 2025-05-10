#!/bin/bash

# Add Temporal Helm repository
helm repo add temporal https://temporalio.github.io/helm-charts
helm repo update

# Create namespace if it doesn't exist
kubectl create namespace temporal --dry-run=client -o yaml | kubectl apply -f -

# Install Temporal with Helm
helm upgrade --install temporal temporal/temporal \
  --namespace temporal \
  --version 0.62.0 \
  --set server.replicaCount=3 \
  --set server.service.type=LoadBalancer \
  --set "server.service.annotations.metallb\\.universe\\.tf/loadBalancerIPs=${LOAD_BALANCER_IP}" \
  --set cassandra.enabled=true \
  --set cassandra.replicaCount=3 \
  --set ui.enabled=true \
  --set ui.replicaCount=2 \
  --set server.persistence.size=10Gi \
  --set server.persistence.storageClass=standard \
  --set cassandra.persistence.size=10Gi \
  --set cassandra.persistence.storageClass=standard 