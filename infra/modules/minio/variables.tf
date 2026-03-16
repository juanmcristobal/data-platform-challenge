variable "chart_url" {
  description = "Direct URL to the MinIO Helm chart package."
  type        = string
  default     = "https://charts.bitnami.com/bitnami/minio-17.0.21.tgz"
}

variable "namespace" {
  description = "Namespace where MinIO will be deployed."
  type        = string
}

variable "persistence_size" {
  description = "Persistent volume size for MinIO data."
  type        = string
  default     = "20Gi"
}

variable "release_name" {
  description = "Helm release name for MinIO."
  type        = string
  default     = "sequra-minio"
}

variable "service_node_port" {
  description = "NodePort used to expose MinIO API for local S3-compatible clients."
  type        = number
  default     = 30900
}

variable "root_password" {
  description = "Root password for MinIO."
  type        = string
  sensitive   = true
}

variable "root_user" {
  description = "Root user for MinIO."
  type        = string
  default     = "minioadmin"
}
