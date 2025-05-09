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
  namespace  = var.temporal_namespace
  create_namespace = true

  set {
    name  = "server.replicaCount"
    value = "3"
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
    value = "3"
  }

  set {
    name  = "ui.enabled"
    value = "true"
  }
} 