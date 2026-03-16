variable "common_labels" {
  description = "Labels shared across resources."
  type        = map(string)
  default     = {}
}

variable "namespaces" {
  description = "Namespaces keyed by logical service name."
  type = map(object({
    labels = optional(map(string), {})
    name   = string
  }))

  validation {
    condition     = length(var.namespaces) > 0
    error_message = "namespaces must contain at least one namespace definition."
  }

  validation {
    condition = length(distinct([
      for namespace in values(var.namespaces) : namespace.name
    ])) == length(var.namespaces)
    error_message = "Each namespace name must be unique."
  }
}
