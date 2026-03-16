mock_provider "helm" {}

variables {
  namespace     = "minio"
  release_name  = "sequra-minio"
  root_password = "change-me-minio-password"
}

run "test_static_outputs" {
  command = plan

  assert {
    condition     = output.namespace == "minio"
    error_message = "The MinIO module should expose the MinIO namespace."
  }

  assert {
    condition     = output.service_name == "sequra-minio"
    error_message = "The MinIO module should expose the expected service name."
  }
}
