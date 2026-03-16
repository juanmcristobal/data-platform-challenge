locals {
  airbyte_service_path = path_relative_to_include()
  service_name         = basename(local.airbyte_service_path)
}

generate "providers" {
  path      = "providers.generated.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<-EOT
  provider "airbyte" {
    server_url    = var.airbyte_api_url
    client_id     = var.airbyte_client_id
    client_secret = var.airbyte_client_secret
  }
  EOT
}
