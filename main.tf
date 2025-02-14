terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.71.0"
    }
  }
}

terraform {
  backend "http" {
  }
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