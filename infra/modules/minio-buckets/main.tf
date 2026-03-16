locals {
  bucket_definitions = {
    for bucket_name in sort(var.bucket_names) : bucket_name => {
      name               = bucket_name
      force_destroy      = var.bucket_force_destroy
      versioning_enabled = var.bucket_versioning_enabled
      attach_policy      = lookup(var.bucket_policies, bucket_name, null) != null
      policy_json        = lookup(var.bucket_policies, bucket_name, null)
    }
  }
}

module "data_lake_buckets" {
  source = "./modules/data_lake_buckets"

  providers = {
    aws = aws.minio
  }

  backend_type                   = "minio"
  buckets                        = local.bucket_definitions
  default_tags                   = var.default_tags
  enable_secure_transport_policy = false
  enable_tls_policy              = false
  manage_public_access_block     = false
  manage_server_side_encryption  = false
}
