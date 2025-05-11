# Proxmox Kubernetes Infrastructure

This repository contains Terraform configurations and scripts to deploy a Kubernetes cluster on Proxmox VE, with integrated storage solutions and monitoring capabilities. For a detailed walkthrough of the setup process, see [this article](https://miketoscano.com/blog/?post=gitlab-terraform-proxmox-k8s).

## Features

- Automated Kubernetes cluster deployment on Proxmox VE
- OpenEBS storage integration for persistent volumes
- MetalLB for load balancing
- Temporal workflow engine deployment
- Monitoring stack with Prometheus and Grafana

## Getting Started

### Prerequisites

- Proxmox VE cluster
- Terraform 1.0.0 or later
- kubectl
- GitLab CI/CD (for automated deployment)

### Configuration

#### GitLab CI/CD Variables (Web UI)

These variables must be configured in your GitLab project settings (Settings > CI/CD > Variables):

- `GITLABACCESSTOKEN`: Access token for your GitLab user
- `GITLABUSERNAME`: Name of your GitLab user
- `PVEUSER`: Proxmox user for API authentication
- `PVEPASSWORD`: Proxmox password

#### Terraform Variables (terraform.tfvars)

Create a `terraform.tfvars` file in the root directory with these variables:

```hcl
# Proxmox Configuration - change as appropriate
pve_node     = "your-proxmox-node"
pve_storage  = "your-storage-name"
pve_template = "your-template-id"
pve_bridge   = "vmbr0"
pve_gateway  = "192.168.69.1"
pve_dns      = "192.168.69.1"
pve_domain   = "home"

# Kubernetes Node Configuration - change as appropriate
k8s_cpus          = 2
k8s_memory        = 4096
k8s_worker_cpus   = 4
k8s_worker_memory = 8192
k8s_disk_size     = 32
k8s_version       = "1.29.2"

# Kubernetes Network Configuration - change as appropriate
k8s_pod_cidr         = "10.244.0.0/16"
k8s_service_cidr     = "10.96.0.0/12"
k8s_dns_domain       = "cluster.local"
k8s_load_balancer_ip = "192.168.69.80"
k8s_load_balancer_range = "192.168.69.80-192.168.69.83"

# Node IP Addresses - change as appropriate
k8s1 = "192.168.69.81"  # Control Plane
k8s2 = "192.168.69.82"  # Worker 1
k8s3 = "192.168.69.83"  # Worker 2
k8s4 = "192.168.69.84"  # Worker 3
```

### Deployment

1. Configure the required variables in your GitLab project settings
2. Create and configure your `terraform.tfvars` file
3. Push your changes to the main branch or create a merge request
4. The pipeline will automatically:
   - Deploy the Kubernetes cluster
   - Configure MetalLB
   - Deploy a sample NGINX server
   - Configure OpenEBS storage
   - Deploy Temporal with monitoring
```
