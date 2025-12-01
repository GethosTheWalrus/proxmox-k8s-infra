#!/bin/bash
set -e

echo "Deploying MetalLB with Helm..."
helm repo add metallb https://metallb.github.io/metallb
helm repo update
helm upgrade --install metallb metallb/metallb \
  --namespace metallb-system \
  --create-namespace

kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app.kubernetes.io/name=metallb --timeout=300s
kubectl apply -f k8s/01-metallb-config.yaml

echo "Deploying OpenEBS with Helm..."
helm repo add openebs https://openebs.github.io/charts
helm repo update
helm upgrade --install openebs openebs/openebs \
  --namespace openebs \
  --create-namespace \
  --set localprovisioner.hostpathClass.isDefaultClass=true \
  --set localprovisioner.enabled=true \
  --set ndm.enabled=true \
  --set ndmOperator.enabled=true

kubectl wait --for=condition=ready pod -l app=openebs -n openebs --timeout=300s || true
kubectl apply -f k8s/02-openebs-config.yaml

echo "Deploying Temporal with Helm..."
helm repo add temporal https://temporalio.github.io/helm-charts
helm repo update
helm upgrade --install temporal temporal/temporal \
  --namespace temporal \
  --create-namespace \
  --version 0.62.0 \
  --set server.replicaCount=3 \
  --set cassandra.enabled=false \
  --set postgresql.enabled=false \
  --set prometheus.enabled=false \
  --set grafana.enabled=false \
  --set server.config.persistence.default.driver=sql \
  --set server.config.persistence.default.sql.driver=postgres12 \
  --set server.config.persistence.default.sql.host=192.168.69.11 \
  --set server.config.persistence.default.sql.port=5432 \
  --set server.config.persistence.default.sql.database=temporal \
  --set server.config.persistence.default.sql.user=postgres \
  --set server.config.persistence.default.sql.existingSecret=temporal-postgresql \
  --set server.config.persistence.visibility.driver=sql \
  --set server.config.persistence.visibility.sql.driver=postgres12 \
  --set server.config.persistence.visibility.sql.host=192.168.69.11 \
  --set server.config.persistence.visibility.sql.port=5432 \
  --set server.config.persistence.visibility.sql.database=temporal_visibility \
  --set server.config.persistence.visibility.sql.user=postgres \
  --set server.config.persistence.visibility.sql.existingSecret=temporal-postgresql \
  --set ui.enabled=true \
  --set ui.replicaCount=2 \
  --set schema.setup.enabled=true \
  --set schema.update.enabled=true \
  --set schema.setup.timeout=600s \
  --set schema.update.timeout=600s \
  --set web.enabled=true \
  --set web.replicaCount=2 \
  --set web.service.type=ClusterIP \
  --set web.service.port=8080 \
  --set web.image.tag="latest" \
  --set web.config.cors.cookieInsecure=true \
  --set web.config.cors.origins="*" \
  --set web.config.cors.allowCredentials=true \
  --set elasticsearch.enabled=false

kubectl apply -f k8s/05-temporal-config.yaml

echo "Waiting for Temporal pods..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=temporal -n temporal --timeout=600s || true

echo "Deployment complete!"
