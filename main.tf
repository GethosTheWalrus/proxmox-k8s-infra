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

data "terraform_remote_state" "example" {
  backend = "http"

  config = {
    address = var.example_remote_state_address
    username = var.example_username
    password = var.example_access_token
  }
}