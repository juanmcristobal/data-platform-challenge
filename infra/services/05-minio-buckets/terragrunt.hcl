include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../modules/minio-buckets"
}

inputs = {
  bucket_names = [
    "data-lake-raw",
    "data-lake-processed",
    "data-lake-analytics",
  ]

  bucket_policies = {
    "data-lake-raw" = <<-JSON
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Sid": "DenyDeleteOnRawLayer",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:DeleteObject",
            "Resource": "arn:aws:s3:::data-lake-raw/*"
          }
        ]
      }
    JSON
  }

  aws_region        = "us-east-1"
  minio_access_key  = "minioadmin"
  minio_secret_key  = "change-me-minio-password"
  minio_region      = "us-east-1"
  minio_endpoint    = "http://127.0.0.1:30900"
  default_tags = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "sequra-platform"
  }
}
