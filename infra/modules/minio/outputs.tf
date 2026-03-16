output "namespace" {
  description = "Namespace where MinIO is deployed."
  value       = var.namespace
}

output "release_name" {
  description = "Helm release name for MinIO."
  value       = helm_release.minio.name
}

output "service_name" {
  description = "ClusterIP service name used to reach MinIO."
  value       = local.service_name
}
