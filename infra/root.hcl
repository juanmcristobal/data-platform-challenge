locals {
  kube_context          = get_env("TG_KUBE_CONTEXT", "kind-sequra-platform")
  relative_service_path = path_relative_to_include()
  service_name          = basename(local.relative_service_path)
  uses_helm_provider    = contains(["02-airbyte", "03-postgres", "04-minio"], local.service_name)
  uses_postgresql_provider = local.service_name == "03-postgres"
  uses_aws_provider        = local.service_name == "05-minio-buckets"
  uses_kube_provider = contains(
    [
      "01-namespaces",
      "02-airbyte",
      "03-postgres",
      "04-minio",
      "05-minio-buckets",
    ],
    local.service_name
  )
}

generate "providers" {
  path      = "providers.generated.tf"
  if_exists = "overwrite_terragrunt"
  contents = join(
    "\n\n",
    compact([
      local.uses_kube_provider ? <<-EOT
      provider "kubernetes" {
        config_path    = pathexpand("~/.kube/config")
        config_context = "${local.kube_context}"
      }
      EOT
      : "",
      local.uses_helm_provider ? <<-EOT
      provider "helm" {
        kubernetes {
          config_path    = pathexpand("~/.kube/config")
          config_context = "${local.kube_context}"
        }
      }
      EOT
      : "",
      local.uses_postgresql_provider ? <<-EOT
      provider "postgresql" {
        host            = var.postgresql_admin_host
        port            = var.postgresql_admin_port
        username        = var.postgresql_admin_user
        password        = var.postgresql_admin_password
        database        = var.postgresql_admin_database
        sslmode         = var.postgresql_sslmode
        connect_timeout = var.postgresql_connect_timeout
      }
      EOT
      : "",
      local.uses_aws_provider ? <<-EOT
      provider "aws" {
        region                      = var.aws_region
        access_key                  = "mock-access-key"
        secret_key                  = "mock-secret-key"
        skip_credentials_validation = true
        skip_metadata_api_check     = true
        skip_region_validation      = true
        skip_requesting_account_id  = true
      }

      provider "aws" {
        alias = "minio"

        access_key                  = var.minio_access_key
        region                      = var.minio_region
        s3_use_path_style           = true
        secret_key                  = var.minio_secret_key
        skip_credentials_validation = true
        skip_metadata_api_check     = true
        skip_region_validation      = true
        skip_requesting_account_id  = true

        endpoints {
          s3 = var.minio_endpoint
        }
      }
      EOT
      : "",
    ])
  )
}
