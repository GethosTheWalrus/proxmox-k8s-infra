terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "temporal" {
  name       = "temporal"
  repository = "https://temporalio.github.io/helm-charts"
  chart      = "temporal"
  version    = "0.20.0"
  namespace  = var.temporal_namespace
  create_namespace = true

  repository_username = ""  # No authentication required
  repository_password = ""  # No authentication required

  set {
    name  = "server.replicaCount"
    value = var.temporal_server_replicas
  }

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "server.service.annotations.metallb\\.universe\\.tf/loadBalancerIPs"
    value = var.load_balancer_ip
  }

  set {
    name  = "cassandra.enabled"
    value = "true"
  }

  set {
    name  = "cassandra.replicaCount"
    value = var.cassandra_replicas
  }

  set {
    name  = "ui.enabled"
    value = var.temporal_ui_enabled
  }

  set {
    name  = "ui.replicaCount"
    value = var.temporal_ui_replicas
  }

  set {
    name  = "server.persistence.size"
    value = var.temporal_server_storage_size
  }

  set {
    name  = "server.persistence.storageClass"
    value = var.temporal_storage_class
  }

  set {
    name  = "cassandra.persistence.size"
    value = var.cassandra_storage_size
  }

  set {
    name  = "cassandra.persistence.storageClass"
    value = var.cassandra_storage_class
  }
} 