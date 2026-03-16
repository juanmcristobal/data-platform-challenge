include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../modules/minio"
}

dependency "namespaces" {
  config_path = "../01-namespaces"
}

dependencies {
  paths = ["../01-namespaces"]
}

inputs = {
  chart_url        = "https://charts.bitnami.com/bitnami/minio-17.0.21.tgz"
  namespace        = try(dependency.namespaces.outputs.namespace_names["minio"], "minio")
  persistence_size = "20Gi"
  release_name     = "sequra-minio"
  service_node_port = 30900
  root_password    = "change-me-minio-password"
  root_user        = "minioadmin"
}
