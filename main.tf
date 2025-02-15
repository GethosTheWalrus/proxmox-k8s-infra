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

# data "terraform_remote_state" "gitlab" {
#   backend = "http"
#   config = {
#     address = "http://localstack.home:4566/proxmox-k8s-terraform"
#     skip_cert_verification = true
#     insecure = true
#   }
# }