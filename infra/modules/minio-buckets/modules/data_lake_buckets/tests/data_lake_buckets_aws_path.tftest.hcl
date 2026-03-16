mock_provider "aws" {}

variables {
  backend_type = "aws"
  buckets = {
    raw = {
      name               = "sequra-prod-data-lake-raw"
      force_destroy      = false
      versioning_enabled = true
    }
    processed = {
      name               = "sequra-prod-data-lake-processed"
      force_destroy      = false
      versioning_enabled = true
    }
    analytics = {
      name               = "sequra-prod-data-lake-analytics"
      force_destroy      = false
      versioning_enabled = true
    }
  }
  enable_secure_transport_policy = true
  enable_tls_policy              = true
  manage_public_access_block     = true
  manage_server_side_encryption  = true
}

run "test_aws_path_plans_successfully" {
  command = plan

  assert {
    condition     = length(output.bucket_arns) == 3
    error_message = "AWS path should produce 3 buckets."
  }

  assert {
    condition     = length(output.bucket_names) == 3
    error_message = "AWS path should expose 3 bucket names."
  }
}

run "test_minio_path_plans_successfully" {
  command = plan

  variables {
    backend_type                   = "minio"
    enable_secure_transport_policy = false
    enable_tls_policy              = false
    manage_public_access_block     = false
    manage_server_side_encryption  = false
  }

  assert {
    condition     = length(output.bucket_arns) == 3
    error_message = "MinIO path should produce 3 buckets."
  }
}
