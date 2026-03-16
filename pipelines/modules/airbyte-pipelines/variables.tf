variable "airbyte_api_url" {
  description = "Airbyte API URL, for example http://127.0.0.1:8080/api/public/v1/."
  type        = string
}

variable "airbyte_workspace_id" {
  description = "Airbyte workspace ID where pipeline resources are created."
  type        = string
}

variable "airbyte_client_id" {
  description = "Optional OAuth client_id for Airbyte API."
  type        = string
  default     = null
  sensitive   = true
}

variable "airbyte_client_secret" {
  description = "Optional OAuth client_secret for Airbyte API."
  type        = string
  default     = null
  sensitive   = true
}

variable "pipeline_yaml_directory" {
  description = "Optional absolute directory path containing one YAML file per pipeline."
  type        = string
  default     = null
}

variable "pipelines" {
  description = "Map of pipeline definitions."
  type = map(object({
    enabled       = optional(bool, true)
    pipeline_name = optional(string)
    source = object({
      postgres = object({
        host               = string
        port               = optional(number, 5432)
        database           = string
        schema             = string
        username           = string
        password           = string
        ssl_mode           = optional(string, "disable")
        replication_method = optional(string, "Standard")
      })
    })
    destination = object({
      s3 = object({
        endpoint   = string
        bucket     = string
        path       = string
        region     = string
        access_key = string
        secret_key = string
      })
    })
    connection = object({
      status        = optional(string, "active")
      schedule_cron = optional(string, "0 0 0/6 * * ?")
      streams = list(object({
        name      = string
        namespace = optional(string)
        sync_mode = optional(string, "full_refresh_overwrite")
      }))
    })
  }))
  default = {}

  validation {
    condition = alltrue([
      for _, pipeline in var.pipelines :
      length(trimspace(pipeline.destination.s3.bucket)) > 0 &&
      length(trimspace(pipeline.destination.s3.path)) > 0
    ])
    error_message = "Each pipeline must define non-empty destination.s3.bucket and destination.s3.path."
  }

  validation {
    condition = alltrue([
      for _, pipeline in var.pipelines :
      can(regex("^([0-9*/?,L#-]+\\s+){5,6}[0-9*/?,L#-]+$", pipeline.connection.schedule_cron))
    ])
    error_message = "Each pipeline.connection.schedule_cron must use Quartz cron syntax (6 or 7 fields)."
  }

  validation {
    condition = alltrue(flatten([
      for _, pipeline in var.pipelines : [
        for stream in pipeline.connection.streams :
        contains(
          [
            "full_refresh_overwrite",
            "full_refresh_overwrite_deduped",
            "full_refresh_append",
            "full_refresh_update",
            "full_refresh_soft_delete",
            "incremental_append",
            "incremental_deduped_history",
            "incremental_update",
            "incremental_soft_delete",
          ],
          stream.sync_mode
        )
      ]
    ]))
    error_message = "Each stream.sync_mode must be supported by Airbyte."
  }
}
