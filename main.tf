terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.71.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://proxmox1.home:8006/"
  insecure = true

  ssh {
    agent = true
    username = "root"
  }
}