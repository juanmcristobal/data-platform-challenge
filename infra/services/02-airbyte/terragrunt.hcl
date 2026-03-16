include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  namespace    = "airbyte"
  release_name = "sequra-airbyte"
}

terraform {
  source = "../../modules/airbyte"

  after_hook "cleanup_airbyte_hook_resources" {
    commands = ["destroy"]
    execute = [
      "bash",
      "-lc",
      <<-EOT
        kubectl --context ${include.root.locals.kube_context} -n ${local.namespace} delete \
          pod,service,statefulset,configmap,secret,serviceaccount,role,rolebinding \
          -l app.kubernetes.io/instance=${local.release_name} \
          --ignore-not-found >/dev/null || true
        kubectl --context ${include.root.locals.kube_context} -n ${local.namespace} wait \
          --for=delete pod \
          -l app.kubernetes.io/instance=${local.release_name} \
          --timeout=60s >/dev/null 2>&1 || true
        kubectl --context ${include.root.locals.kube_context} -n ${local.namespace} delete pod \
          -l app.kubernetes.io/instance=${local.release_name} \
          --force --grace-period=0 \
          --ignore-not-found >/dev/null 2>&1 || true
        kubectl --context ${include.root.locals.kube_context} -n ${local.namespace} delete pvc \
          -l app.kubernetes.io/instance=${local.release_name} \
          --ignore-not-found >/dev/null || true
        kubectl --context ${include.root.locals.kube_context} -n ${local.namespace} delete secret airbyte-auth-secrets \
          --ignore-not-found >/dev/null || true
      EOT
    ]
    run_on_error = true
  }
}

dependency "namespaces" {
  config_path = "../01-namespaces"
}

dependencies {
  paths = ["../01-namespaces"]
}

inputs = {
  airbyte_chart_version            = "1.9.2"
  connector_builder_server_enabled = false
  connector_rollout_worker_enabled = false
  cron_enabled                     = true
  keycloak_enabled                 = false
  metrics_enabled                  = false
  namespace                        = dependency.namespaces.outputs.namespace_names["airbyte"]
  release_name                     = local.release_name
  temporal_ui_enabled              = false
  webapp_enabled                   = false
  workspace_id                     = "8215ead5-4103-4e4b-aae5-9a86fccdcc3e" # Fallback, se usa el descubierto dinámicamente si está disponible
}
