mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "postgresql" {}

variables {
  namespace                 = "data-source"
  postgresql_admin_password = "test-admin-password"
  users = {
    app_owner = {
      password = "owner-pass"
    }
    airbyte_reader = {
      password = "reader-pass"
    }
  }
}

run "test_static_outputs" {
  command = plan

  assert {
    condition     = output.namespace == "data-source"
    error_message = "The PostgreSQL module should expose the PostgreSQL namespace."
  }

  assert {
    condition     = output.release_name == "sequra-postgres"
    error_message = "The PostgreSQL module should expose the PostgreSQL release name."
  }

  assert {
    condition     = contains(output.user_names, "airbyte_reader")
    error_message = "The PostgreSQL module should expose managed role names."
  }
}
