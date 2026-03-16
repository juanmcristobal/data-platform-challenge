output "namespace" {
  description = "Namespace where Airbyte is deployed."
  value       = var.namespace
}

output "release_name" {
  description = "Helm release name for Airbyte."
  value       = helm_release.airbyte.name
}

output "service_name" {
  description = "ClusterIP service name used to reach the Airbyte UI."
  value       = local.service_name
}

output "workspace_id" {
  description = "Airbyte workspace ID to be used by pipeline-as-code roots."
  value       = try(data.external.workspace_id.result.workspace_id, var.workspace_id)
}
