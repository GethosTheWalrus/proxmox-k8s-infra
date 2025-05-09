terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "2.9.14"
    }
  }
  backend "http" {}
}

provider "proxmox" {
  endpoint = "https://proxmox1.home:8006/"
  username = var.username
  password = var.password
  insecure = true

  ssh {
    agent = true
    username = "root"
  }
}

module "k8s_infra" {
  source = "./k8s-infra"
  
  username              = var.username
  password              = var.password
  cpu_cores            = var.cpu_cores
  cpu_type             = var.cpu_type
  dedicated_memory     = var.dedicated_memory
  disk_size            = var.disk_size
  datastore_id         = var.datastore_id
  os_image             = var.os_image
  pve_node             = var.pve_node
  os_user              = var.os_user
  os_password          = var.os_password
  os_image_datastore_id = var.os_image_datastore_id
}

module "temporal" {
  source = "./temporal"
  
  temporal_namespace         = var.temporal_namespace
  temporal_server_replicas   = var.temporal_server_replicas
  temporal_server_storage_size = var.temporal_server_storage_size
  cassandra_storage_size     = var.cassandra_storage_size
  load_balancer_ip          = var.load_balancer_ip
  cassandra_replicas        = var.cassandra_replicas
  cassandra_storage_class   = var.cassandra_storage_class
  temporal_storage_class    = var.temporal_storage_class
  temporal_ui_enabled       = var.temporal_ui_enabled
  temporal_ui_replicas      = var.temporal_ui_replicas
} 