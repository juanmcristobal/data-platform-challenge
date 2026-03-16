variable "aws_region" {
  description = "Dummy region required by the AWS provider schema."
  type        = string
  default     = "us-east-1"
}

variable "bucket_force_destroy" {
  description = "When true, allow Terraform to delete non-empty buckets."
  type        = bool
  default     = true
}

variable "bucket_names" {
  description = "List of bucket names to create in MinIO."
  type        = list(string)

  validation {
    condition     = length(var.bucket_names) > 0
    error_message = "bucket_names must contain at least one bucket name."
  }

  validation {
    condition     = length(distinct(var.bucket_names)) == length(var.bucket_names)
    error_message = "bucket_names must contain unique values."
  }
}

variable "bucket_policies" {
  description = "Optional JSON policy document per bucket name (S3 policy language compatible)."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for bucket_name in keys(var.bucket_policies) :
      contains(var.bucket_names, bucket_name)
    ])
    error_message = "Each key in bucket_policies must exist in bucket_names."
  }

  validation {
    condition = alltrue([
      for policy_json in values(var.bucket_policies) :
      can(jsondecode(policy_json))
    ])
    error_message = "Each value in bucket_policies must be valid JSON."
  }
}

variable "bucket_versioning_enabled" {
  description = "Enable S3 versioning for all created buckets."
  type        = bool
  default     = true
}

variable "default_tags" {
  description = "Tags applied to every managed bucket."
  type        = map(string)
  default     = {}
}

variable "minio_access_key" {
  description = "Access key used by the AWS provider against MinIO."
  type        = string
}

variable "minio_endpoint" {
  description = "S3-compatible endpoint URL for MinIO."
  type        = string
  default     = "http://127.0.0.1:9000"
}

variable "minio_region" {
  description = "Region value used by the AWS provider against MinIO."
  type        = string
  default     = "us-east-1"
}

variable "minio_secret_key" {
  description = "Secret key used by the AWS provider against MinIO."
  type        = string
  sensitive   = true
}
