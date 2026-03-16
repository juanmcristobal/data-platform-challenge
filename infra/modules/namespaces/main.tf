locals {
  namespace_definitions = {
    for logical_name, namespace in var.namespaces :
    logical_name => {
      labels = merge(
        var.common_labels,
        {
          "app.kubernetes.io/component" = logical_name
          "app.kubernetes.io/name"      = namespace.name
        },
        namespace.labels
      )
      name = namespace.name
    }
  }
}

resource "kubernetes_namespace_v1" "this" {
  for_each = local.namespace_definitions

  metadata {
    name   = each.value.name
    labels = each.value.labels
  }
}
