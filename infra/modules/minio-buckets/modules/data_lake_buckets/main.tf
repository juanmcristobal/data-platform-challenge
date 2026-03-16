terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

module "aws_bucket" {
  for_each = var.backend_type == "aws" ? var.buckets : {}

  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"

  attach_deny_insecure_transport_policy = var.enable_secure_transport_policy
  attach_policy                         = try(each.value.attach_policy, false)
  attach_require_latest_tls_policy      = var.enable_tls_policy
  block_public_acls                     = var.manage_public_access_block
  block_public_policy                   = var.manage_public_access_block
  bucket                                = each.value.name
  control_object_ownership              = true
  force_destroy                         = try(each.value.force_destroy, false)
  ignore_public_acls                    = var.manage_public_access_block
  object_ownership                      = "BucketOwnerEnforced"
  policy                                = try(each.value.policy_json, null)
  restrict_public_buckets               = var.manage_public_access_block

  versioning = {
    enabled = try(each.value.versioning_enabled, true)
  }

  tags = merge(var.default_tags, try(each.value.tags, {}))
}

resource "aws_s3_bucket" "minio_bucket" {
  for_each = var.backend_type == "minio" ? var.buckets : {}

  bucket        = each.value.name
  force_destroy = try(each.value.force_destroy, false)
  tags          = merge(var.default_tags, try(each.value.tags, {}))
}

resource "aws_s3_bucket_policy" "minio_bucket" {
  for_each = var.backend_type == "minio" ? {
    for key, bucket in var.buckets : key => bucket
    if try(bucket.attach_policy, false) && try(bucket.policy_json, null) != null
  } : {}

  bucket = aws_s3_bucket.minio_bucket[each.key].id
  policy = each.value.policy_json
}

resource "aws_s3_bucket_server_side_encryption_configuration" "aws_bucket" {
  for_each = var.backend_type == "aws" && var.manage_server_side_encryption ? var.buckets : {}

  bucket = module.aws_bucket[each.key].s3_bucket_id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "minio_bucket" {
  for_each = var.backend_type == "minio" ? {
    for key, bucket in var.buckets : key => bucket
    if try(bucket.versioning_enabled, true)
  } : {}

  bucket = aws_s3_bucket.minio_bucket[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}
