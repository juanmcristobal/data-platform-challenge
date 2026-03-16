include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}//pipelines/modules/airbyte-pipelines"
}

dependencies {
  paths = [
    "../../infra/services/02-airbyte",
    "../../infra/services/03-postgres",
    "../../infra/services/04-minio",
    "../../infra/services/05-minio-buckets",
  ]
}

dependency "airbyte" {
  config_path = "../../infra/services/02-airbyte"
}

inputs = {
  airbyte_api_url      = "http://127.0.0.1:18080/api/public/v1/"
  airbyte_workspace_id = try(dependency.airbyte.outputs.workspace_id, "1ff4a75c-fdc4-42ac-ac21-b39c2dc2805b")
  pipeline_yaml_directory = "${get_terragrunt_dir()}/pipelines"

  # Optional for OSS without auth; for secured setups set real values.
  airbyte_client_id     = null
  airbyte_client_secret = null
}
