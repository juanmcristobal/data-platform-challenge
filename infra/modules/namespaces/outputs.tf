output "namespace_labels" {
  description = "Labels applied to each namespace, keyed by logical service name."
  value = {
    for logical_name, namespace in kubernetes_namespace_v1.this :
    logical_name => namespace.metadata[0].labels
  }
}

output "namespace_names" {
  description = "Namespace names keyed by logical service name."
  value = {
    for logical_name, namespace in kubernetes_namespace_v1.this :
    logical_name => namespace.metadata[0].name
  }
}

output "namespaces" {
  description = "Namespace metadata keyed by logical service name."
  value = {
    for logical_name, namespace in kubernetes_namespace_v1.this :
    logical_name => {
      labels = namespace.metadata[0].labels
      name   = namespace.metadata[0].name
    }
  }
}
