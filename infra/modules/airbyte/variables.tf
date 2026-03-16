variable "airbyte_chart_version" {
  description = "Airbyte OSS Helm chart version."
  type        = string
}

variable "connector_builder_server_enabled" {
  description = "Whether to enable the Airbyte connector-builder-server component."
  type        = bool
  default     = false
}

variable "connector_rollout_worker_enabled" {
  description = "Whether to enable the Airbyte connector-rollout-worker component."
  type        = bool
  default     = false
}

variable "cron_enabled" {
  description = "Whether to enable the Airbyte cron component."
  type        = bool
  default     = false
}

variable "keycloak_enabled" {
  description = "Whether to enable the Airbyte Keycloak component."
  type        = bool
  default     = false
}

variable "metrics_enabled" {
  description = "Whether to enable the Airbyte metrics component."
  type        = bool
  default     = false
}

variable "namespace" {
  description = "Namespace where Airbyte will be deployed."
  type        = string
}

variable "release_name" {
  description = "Helm release name for Airbyte."
  type        = string
}

variable "temporal_ui_enabled" {
  description = "Whether to enable the Airbyte temporal-ui component."
  type        = bool
  default     = false
}

variable "webapp_enabled" {
  description = "Whether to enable the Airbyte webapp component."
  type        = bool
  default     = false
}

variable "workspace_id" {
  description = "Airbyte workspace ID to be consumed by downstream pipeline roots."
  type        = string
}
