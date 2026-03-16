output "pipeline_ids" {
  description = "Source, destination, and connection IDs keyed by pipeline key."
  value = {
    for key in keys(local.named_enabled_pipelines) : key => {
      source_id      = airbyte_source.postgres[key].source_id
      destination_id = airbyte_destination.s3[key].destination_id
      connection_id  = airbyte_connection.pipeline[key].connection_id
    }
  }
}

output "enabled_pipelines" {
  description = "Pipeline keys currently enabled."
  value       = keys(local.enabled_pipelines)
}

output "failed_validation_pipelines" {
  description = "Pipeline keys that fail local validation checks."
  value       = local.failed_validation_pipelines
}
