mock_provider "aws" {}
mock_provider "aws" {
  alias = "minio"
}

variables {
  bucket_names     = ["data-lake-raw", "data-lake-processed", "data-lake-analytics"]
  minio_access_key = "minioadmin"
  minio_secret_key = "change-me-minio-password"
}

run "test_static_outputs" {
  command = plan
}
