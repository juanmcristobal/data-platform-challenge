variable "backend_type" {
  description = "Object storage backend to provision. Use aws for Amazon S3 or minio for S3-compatible endpoints."
  type        = string

  validation {
    condition     = contains(["aws", "minio"], var.backend_type)
    error_message = "backend_type must be aws or minio."
  }
}

variable "buckets" {
  description = "Bucket definitions keyed by logical tier."
  type = map(object({
    attach_policy      = optional(bool, false)
    force_destroy      = optional(bool, false)
    name               = string
    policy_json        = optional(string)
    tags               = optional(map(string), {})
    versioning_enabled = optional(bool, true)
  }))
}

variable "default_tags" {
  description = "Tags applied to every managed bucket."
  type        = map(string)
  default     = {}
}

variable "enable_secure_transport_policy" {
  description = "When true, attach the standard deny-insecure-transport bucket policy in AWS mode."
  type        = bool
  default     = true
}

variable "enable_tls_policy" {
  description = "When true, attach the standard require-latest-TLS bucket policy in AWS mode."
  type        = bool
  default     = true
}

variable "manage_public_access_block" {
  description = "When true, manage S3 public access block controls in AWS mode."
  type        = bool
  default     = true
}

variable "manage_server_side_encryption" {
  description = "When true, enforce SSE-S3 on the buckets in AWS mode."
  type        = bool
  default     = true
}
