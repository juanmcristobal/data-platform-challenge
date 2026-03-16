mock_provider "kubernetes" {}

variables {
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "sequra-platform"
  }
  namespaces = {
    airbyte = {
      name = "airbyte"
    }
    postgres = {
      labels = {
        "sequra.io/data-role" = "source"
      }
      name = "data-source"
    }
  }
}

run "test_namespace_outputs" {
  command = plan

  assert {
    condition     = output.namespace_names["airbyte"] == "airbyte"
    error_message = "The module should expose namespace names keyed by logical name."
  }

  assert {
    condition     = output.namespace_names["postgres"] == "data-source"
    error_message = "The module should expose the PostgreSQL namespace in namespace_names."
  }

  assert {
    condition     = output.namespaces["postgres"].labels["sequra.io/data-role"] == "source"
    error_message = "The generic namespaces output should preserve per-namespace labels."
  }
}
