terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.71.0"
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