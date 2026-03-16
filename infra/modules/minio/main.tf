locals {
  service_name = var.release_name
}

resource "helm_release" "minio" {
  name              = var.release_name
  namespace         = var.namespace
  chart             = var.chart_url
  create_namespace  = false
  dependency_update = false
  atomic            = true
  cleanup_on_fail   = true
  timeout           = 600
  wait              = true

  values = [
    yamlencode({
      global = {
        imageRegistry = "public.ecr.aws"
        security = {
          allowInsecureImages = true
        }
      }
      auth = {
        rootUser     = var.root_user
        rootPassword = var.root_password
      }
      defaultBuckets = ""
      mode           = "standalone"
      persistence = {
        enabled = true
        size    = var.persistence_size
      }
      service = {
        type = "NodePort"
        nodePorts = {
          api = var.service_node_port
        }
      }
    })
  ]
}
