mock_provider "helm" {}
mock_provider "kubernetes" {}

variables {
  airbyte_chart_version            = "1.9.2"
  connector_builder_server_enabled = false
  connector_rollout_worker_enabled = false
  cron_enabled                     = false
  keycloak_enabled                 = false
  metrics_enabled                  = false
  namespace                        = "airbyte"
  release_name                     = "sequra-airbyte"
  temporal_ui_enabled              = false
  webapp_enabled                   = false
  workspace_id                     = "test-workspace-id"
}

run "test_static_outputs" {
  command = plan
}
