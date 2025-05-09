terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

module "k8s_infra" {
  source = "./k8s-infra"
  
  # Pass through any variables needed from the root module
  username = var.username
  password = var.password
  # Add other variables as needed
}

module "temporal" {
  source = "./temporal"
  
  # Pass through any variables needed from the root module
  load_balancer_ip = "192.168.69.83"  # Using the first IP from your MetalLB pool
  depends_on = [module.k8s_infra]
} 