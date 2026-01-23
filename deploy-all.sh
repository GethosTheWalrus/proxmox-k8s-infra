#!/bin/bash
set -e

COMPONENT=$1

echo "Starting deployment at $(date)"

deploy_metallb_install() {
  echo "Deploying MetalLB with Helm..."
  helm repo add metallb https://metallb.github.io/metallb
  helm repo update
  helm upgrade --install metallb metallb/metallb \
    --namespace metallb-system \
    --create-namespace \
    --set controller.resources.limits.memory=256Mi \
    --set speaker.resources.limits.memory=256Mi
}

deploy_metallb_verify() {
  echo "Verifying MetalLB..."
  kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app.kubernetes.io/name=metallb --timeout=300s
  kubectl apply -f k8s/01-metallb-config.yaml
}

deploy_openebs_install() {
  echo "Deploying OpenEBS with Helm..."
  helm repo add openebs https://openebs.github.io/charts
  helm repo update
  helm upgrade --install openebs openebs/openebs \
    --namespace openebs \
    --create-namespace \
    --set localprovisioner.hostpathClass.isDefaultClass=true \
    --set localprovisioner.enabled=true \
    --set ndm.enabled=true \
    --set ndmOperator.enabled=true \
    --set localprovisioner.hostpathClass.basePath=/var/openebs/local \
    --set localprovisioner.resources.limits.memory=1Gi \
    --set ndm.resources.limits.memory=512Mi
}

deploy_openebs_verify() {
  echo "Verifying OpenEBS..."
  kubectl wait --for=condition=ready pod -l app=openebs -n openebs --timeout=300s
}

deploy_temporal_install() {
  echo "Deploying Temporal with Helm..."
  
  # Create namespace and apply the PostgreSQL secret first
  kubectl create namespace temporal --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f k8s/04-temporal-secret.yaml
  
  helm repo add temporal https://temporalio.github.io/helm-charts
  helm repo update
  helm upgrade --install temporal temporal/temporal \
    --namespace temporal \
    --create-namespace \
    --version 0.72.0 \
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
    --set server.config.persistence.default.sql.maxConns=10 \
    --set server.config.persistence.visibility.driver=sql \
    --set server.config.persistence.visibility.sql.driver=postgres12 \
    --set server.config.persistence.visibility.sql.host=192.168.69.11 \
    --set server.config.persistence.visibility.sql.port=5432 \
    --set server.config.persistence.visibility.sql.database=temporal_visibility \
    --set server.config.persistence.visibility.sql.user=postgres \
    --set server.config.persistence.visibility.sql.maxConns=10 \
    --set server.config.persistence.visibility.sql.existingSecret=temporal-postgresql \
    --set server.resources.requests.cpu=100m \
    --set server.resources.requests.memory=1Gi \
    --set server.resources.limits.memory=2Gi \
    --set admintools.resources.limits.memory=512Mi \
    --set ui.enabled=false \
    --set schema.setup.enabled=true \
    --set schema.update.enabled=true \
    --set schema.setup.timeout=600s \
    --set schema.update.timeout=600s \
    --set web.enabled=true \
    --set web.replicaCount=2 \
    --set web.resources.requests.memory=256Mi \
    --set web.resources.limits.memory=512Mi \
    --set web.service.type=ClusterIP \
    --set web.service.port=8080 \
    --set web.config.cors.cookieInsecure=true \
    --set web.config.cors.origins="*" \
    --set web.config.cors.allowCredentials=true \
    --set web.config.auth.enabled=false \
    --set elasticsearch.enabled=false

  kubectl apply -f k8s/05-temporal-config.yaml
}

deploy_temporal_verify() {
  echo "Verifying Temporal..."
  # Wait for core Temporal services (excluding jobs and other components)
  kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=temporal,app.kubernetes.io/component=frontend \
    -n temporal --timeout=600s
  kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=temporal,app.kubernetes.io/component=history \
    -n temporal --timeout=600s
  kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=temporal,app.kubernetes.io/component=matching \
    -n temporal --timeout=600s
  echo "All Temporal core services are ready"
}

deploy_dashboard_install() {
  echo "Deploying Kubernetes Dashboard..."
  helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
  helm repo update
  helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
    --create-namespace \
    --namespace kubernetes-dashboard \
    --set kong.proxy.http.enabled=true \
    --set kong.proxy.type=LoadBalancer \
    --set resources.limits.memory=256Mi \
    --set metricsScraper.resources.limits.memory=256Mi
  
  # Create admin user for dashboard access
  kubectl apply -f k8s/06-dashboard-admin.yaml
}

deploy_dashboard_verify() {
  echo "Verifying Kubernetes Dashboard..."
  kubectl wait --namespace kubernetes-dashboard --for=condition=ready pod --selector=app.kubernetes.io/name=kubernetes-dashboard-web --timeout=300s
  echo "Kubernetes Dashboard is ready"
  echo ""
  echo "To get admin token, run:"
  echo "kubectl -n kubernetes-dashboard create token admin-user"
}

if [ "$COMPONENT" == "metallb-install" ]; then
  deploy_metallb_install
elif [ "$COMPONENT" == "metallb-verify" ]; then
  deploy_metallb_verify
elif [ "$COMPONENT" == "openebs-install" ]; then
  deploy_openebs_install
elif [ "$COMPONENT" == "openebs-verify" ]; then
  deploy_openebs_verify
elif [ "$COMPONENT" == "temporal-install" ]; then
  deploy_temporal_install
elif [ "$COMPONENT" == "temporal-verify" ]; then
  deploy_temporal_verify
elif [ "$COMPONENT" == "dashboard-install" ]; then
  deploy_dashboard_install
elif [ "$COMPONENT" == "dashboard-verify" ]; then
  deploy_dashboard_verify
else
  echo "No specific component selected, deploying all..."
  deploy_metallb_install
  deploy_metallb_verify
  deploy_openebs_install
  deploy_openebs_verify
  deploy_temporal_install
  deploy_temporal_verify
  deploy_dashboard_install
  deploy_dashboard_verify
fi

echo "Deployment complete at $(date)!"
