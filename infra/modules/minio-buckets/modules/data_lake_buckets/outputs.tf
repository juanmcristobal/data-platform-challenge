output "bucket_arns" {
  description = "Bucket ARNs keyed by logical tier."
  value = var.backend_type == "aws" ? {
    for key, bucket in module.aws_bucket : key => bucket.s3_bucket_arn
    } : {
    for key, bucket in aws_s3_bucket.minio_bucket : key => bucket.arn
  }
}

output "bucket_ids" {
  description = "Bucket IDs keyed by logical tier."
  value = var.backend_type == "aws" ? {
    for key, bucket in module.aws_bucket : key => bucket.s3_bucket_id
    } : {
    for key, bucket in aws_s3_bucket.minio_bucket : key => bucket.id
  }
}

output "bucket_names" {
  description = "Bucket names keyed by logical tier."
  value = var.backend_type == "aws" ? {
    for key, bucket in module.aws_bucket : key => bucket.s3_bucket_id
    } : {
    for key, bucket in aws_s3_bucket.minio_bucket : key => bucket.bucket
  }
}
