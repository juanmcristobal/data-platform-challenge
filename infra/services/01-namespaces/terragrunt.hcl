include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../modules/namespaces"
}

inputs = {
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "sequra-platform"
  }
  namespaces = {
    airbyte = {
      name = "airbyte"
    }
    minio = {
      name = "minio"
    }
    postgres = {
      name = "data-source"
    }
  }
}
