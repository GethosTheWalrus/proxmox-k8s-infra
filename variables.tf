variable "username" {
  description = "Proxmox VE username"
  type        = string
}

variable "password" {
  description = "Proxmox VE password"
  type        = string
  sensitive   = true
}

variable "cpu_cores" {
  description = "Number of CPU cores for each VM"
  type        = number
  default     = 2
}

variable "cpu_type" {
  description = "CPU type for the VMs"
  type        = string
  default     = "x86-64-v2-AES"
}

variable "dedicated_memory" {
  description = "Amount of memory (in MB) for each VM"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Disk size (in GB) for each VM"
  type        = number
  default     = 20
}

variable "datastore_id" {
  description = "Proxmox datastore ID for VM storage"
  type        = string
  default     = "big-nas"
}

variable "os_image" {
  description = "URL of the OS image to use"
  type        = string
  default     = "https://cloud-images.ubuntu.com/oracular/current/oracular-server-cloudimg-amd64.img"
}

variable "pve_node" {
  description = "Proxmox node to deploy VMs on"
  type        = string
  default     = "proxmox1"
}

variable "os_user" {
  description = "Default OS user for the VMs"
  type        = string
  default     = "k8s"
}

variable "os_password" {
  description = "Default OS password for the VMs"
  type        = string
  default     = "s8k"
  sensitive   = true
}

variable "os_image_datastore_id" {
  description = "Proxmox datastore ID for OS image storage"
  type        = string
  default     = "local"
}

# Temporal Module Variables
variable "temporal_namespace" {
  description = "Kubernetes namespace for Temporal"
  type        = string
  default     = "temporal"
}

variable "temporal_server_replicas" {
  description = "Number of Temporal server replicas"
  type        = number
  default     = 3
}

variable "temporal_server_storage_size" {
  description = "Storage size for Temporal server"
  type        = string
  default     = "10Gi"
}

variable "cassandra_storage_size" {
  description = "Storage size for Cassandra"
  type        = string
  default     = "10Gi"
}

variable "load_balancer_ip" {
  description = "IP address for the Temporal server LoadBalancer"
  type        = string
  default     = "192.168.69.98"
}

variable "cassandra_replicas" {
  description = "Number of Cassandra replicas"
  type        = number
  default     = 3
}

variable "cassandra_storage_class" {
  description = "Storage class for Cassandra persistence"
  type        = string
  default     = "standard"
}

variable "temporal_storage_class" {
  description = "Storage class for Temporal persistence"
  type        = string
  default     = "standard"
}

variable "temporal_ui_enabled" {
  description = "Whether to enable Temporal UI"
  type        = bool
  default     = true
}

variable "temporal_ui_replicas" {
  description = "Number of Temporal UI replicas"
  type        = number
  default     = 2
} 