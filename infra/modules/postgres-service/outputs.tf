output "database_names" {
  description = "Managed PostgreSQL database names."
  value       = [for _, db_cfg in var.databases : db_cfg.name]
}

output "internal_dns" {
  description = "Internal DNS name for the PostgreSQL service."
  value       = local.internal_dns
}

output "namespace" {
  description = "Namespace where PostgreSQL is deployed."
  value       = var.namespace
}

output "release_name" {
  description = "Helm release name for PostgreSQL."
  value       = helm_release.postgres.name
}

output "service_name" {
  description = "Service name for PostgreSQL."
  value       = local.service_name
}

output "user_names" {
  description = "Managed PostgreSQL role names."
  value       = keys(var.users)
}
