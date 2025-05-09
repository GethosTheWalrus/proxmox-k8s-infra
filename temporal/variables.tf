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