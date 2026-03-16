include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  detected_kind_network_cidrs_raw = trimspace(run_cmd(
    "--terragrunt-quiet",
    "bash",
    "-lc",
    "docker network inspect kind --format '{{range .IPAM.Config}}{{println .Subnet}}{{end}}' 2>/dev/null | grep -E '^[0-9]+\\.' || true"
  ))

  detected_kind_network_cidrs = [
    for cidr in split("\n", local.detected_kind_network_cidrs_raw) : trimspace(cidr)
    if trimspace(cidr) != ""
  ]

  detected_pod_cidrs_raw = trimspace(run_cmd(
    "--terragrunt-quiet",
    "bash",
    "-lc",
    "kubectl --context ${include.root.locals.kube_context} get nodes -o jsonpath='{range .items[*]}{.spec.podCIDR}{\"\\n\"}{end}' 2>/dev/null || true"
  ))

  detected_pod_cidrs = [
    for cidr in split("\n", local.detected_pod_cidrs_raw) : trimspace(cidr)
    if trimspace(cidr) != ""
  ]

  # In local kind + Cilium, provider traffic via NodePort can be SNATed from addresses
  # outside detected kind/docker ranges. Keep an explicit local-only admin escape hatch.
  detected_admin_cidrs = distinct(concat(local.detected_kind_network_cidrs, local.detected_pod_cidrs, ["0.0.0.0/0"]))
}

terraform {
  source = "../../modules/postgres-service"
}

dependency "namespaces" {
  config_path = "../01-namespaces"
}

dependencies {
  paths = ["../01-namespaces"]
}

inputs = {
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "sequra-platform"
  }
  namespace                 = dependency.namespaces.outputs.namespace_names["postgres"]
  postgresql_admin_password = "change-me-admin-password"

  allowed_client_namespaces = [
    dependency.namespaces.outputs.namespace_names["airbyte"],
    # Local provider traffic is observed through kube-system networking pods in kind.
    "kube-system",
  ]
  allowed_admin_cidrs = local.detected_admin_cidrs

  databases = {
    source = {
      name  = "airbyte_source_db"
      owner = "app_owner"
    }
  }

  users = {
    app_owner = {
      password = "change-me-owner-pass"
    }
    airbyte_reader = {
      password = "change-me-reader-pass"
    }
  }

  schemas = {
    source_public = {
      database = "airbyte_source_db"
      name     = "public"
      owner    = "app_owner"
    }
  }

  tables = {
    bank_customers = {
      database = "airbyte_source_db"
      schema   = "public"
      name     = "bank_customers"
      columns = [
        { name = "customer_id", type = "bigserial", nullable = false },
        { name = "full_name", type = "text", nullable = false },
        { name = "email", type = "text", nullable = false },
        { name = "country_code", type = "text", nullable = false },
        { name = "created_at", type = "timestamptz", nullable = false, default = "now()" },
      ]
      primary_key = ["customer_id"]
      indexes = [
        { name = "idx_bank_customers_email", columns = ["email"], unique = true },
      ]
      grants = {
        airbyte_reader = ["SELECT"]
      }
    }
    card_transactions = {
      database = "airbyte_source_db"
      schema   = "public"
      name     = "card_transactions"
      columns = [
        { name = "transaction_id", type = "bigserial", nullable = false },
        { name = "customer_id", type = "bigint", nullable = false },
        { name = "card_last4", type = "char(4)", nullable = false },
        { name = "amount", type = "numeric(12,2)", nullable = false },
        { name = "currency", type = "char(3)", nullable = false, default = "'EUR'" },
        { name = "merchant", type = "text", nullable = false },
        { name = "status", type = "text", nullable = false },
        { name = "occurred_at", type = "timestamptz", nullable = false },
      ]
      primary_key = ["transaction_id"]
      indexes = [
        { name = "idx_card_transactions_customer_id", columns = ["customer_id"], unique = false },
        { name = "idx_card_transactions_occurred_at", columns = ["occurred_at"], unique = false },
      ]
      grants = {
        airbyte_reader = ["SELECT"]
      }
    }
  }
}
