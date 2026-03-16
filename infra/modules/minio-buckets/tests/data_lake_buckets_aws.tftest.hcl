mock_provider "aws" {}
mock_provider "aws" {
  alias = "minio"
}

variables {
  bucket_names     = ["data-lake-raw", "data-lake-processed", "data-lake-analytics"]
  minio_access_key = "unused-in-aws-mode"
  minio_secret_key = "unused-in-aws-mode"
}

override_module {
  target = module.data_lake_buckets

  outputs = {
    bucket_arns = {
      "data-lake-raw"       = "arn:aws:s3:::sequra-prod-data-lake-raw"
      "data-lake-processed" = "arn:aws:s3:::sequra-prod-data-lake-processed"
      "data-lake-analytics" = "arn:aws:s3:::sequra-prod-data-lake-analytics"
    }
    bucket_ids = {
      "data-lake-raw"       = "sequra-prod-data-lake-raw"
      "data-lake-processed" = "sequra-prod-data-lake-processed"
      "data-lake-analytics" = "sequra-prod-data-lake-analytics"
    }
    bucket_names = {
      "data-lake-raw"       = "sequra-prod-data-lake-raw"
      "data-lake-processed" = "sequra-prod-data-lake-processed"
      "data-lake-analytics" = "sequra-prod-data-lake-analytics"
    }
  }
}

run "test_aws_mode_bucket_outputs" {
  command = plan

  assert {
    condition     = output.bucket_arns["data-lake-raw"] == "arn:aws:s3:::sequra-prod-data-lake-raw"
    error_message = "Expected data-lake-raw ARN from the AWS path."
  }

  assert {
    condition     = output.bucket_names["data-lake-processed"] == "sequra-prod-data-lake-processed"
    error_message = "Expected data-lake-processed name from the AWS path."
  }

  assert {
    condition     = length(output.bucket_arns) == 3
    error_message = "Expected 3 buckets in AWS mode."
  }
}
