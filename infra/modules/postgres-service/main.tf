locals {
  internal_dns = "${local.service_name}.${var.namespace}.svc.cluster.local"
  service_name = "${var.release_name}-postgresql"

  schema_owners = {
    for _, schema_cfg in var.schemas :
    "${schema_cfg.database}.${schema_cfg.name}" => schema_cfg.owner
  }

  table_grant_entries = flatten([
    for _, table_cfg in var.tables : [
      for role_name, privileges in try(table_cfg.grants, {}) : {
        key = "${table_cfg.database}.${table_cfg.schema}.${role_name}.${join("_", sort(distinct(privileges)))}"

        database   = table_cfg.database
        owner      = coalesce(try(table_cfg.owner, null), lookup(local.schema_owners, "${table_cfg.database}.${table_cfg.schema}", null))
        privileges = sort(distinct(privileges))
        role       = role_name
        schema     = table_cfg.schema
      }
    ]
  ])

  table_grants_grouped = {
    for grant_cfg in local.table_grant_entries :
    grant_cfg.key => grant_cfg...
  }

  table_grants_by_key = {
    for key, grants in local.table_grants_grouped :
    key => grants[0]
  }

  connect_grants_grouped = {
    for _, grant_cfg in local.table_grants_by_key :
    "${grant_cfg.database}.${grant_cfg.role}" => grant_cfg...
  }

  connect_grants_by_key = {
    for key, grants in local.connect_grants_grouped :
    key => {
      database = grants[0].database
      role     = grants[0].role
    }
  }

  schema_grants_grouped = {
    for _, grant_cfg in local.table_grants_by_key :
    "${grant_cfg.database}.${grant_cfg.schema}.${grant_cfg.role}" => grant_cfg...
  }

  schema_grants_by_key = {
    for key, grants in local.schema_grants_grouped :
    key => {
      database = grants[0].database
      role     = grants[0].role
      schema   = grants[0].schema
    }
  }

  default_table_grants_by_key = {
    for key, grant_cfg in local.table_grants_by_key :
    key => grant_cfg if grant_cfg.owner != null
  }

  tables_sql = length(var.tables) == 0 ? "" : trimspace(templatefile("${path.module}/templates/tables.sql.tftpl", {
    schema_owners = local.schema_owners
    tables        = var.tables
  }))
}

resource "kubernetes_secret_v1" "postgres_auth" {
  metadata {
    name      = var.auth_secret_name
    namespace = var.namespace
    labels    = var.common_labels
  }

  data = {
    "password"          = var.bootstrap_owner_password
    "postgres-password" = var.postgresql_admin_password
  }

  type = "Opaque"
}

resource "helm_release" "postgres" {
  name             = var.release_name
  namespace        = var.namespace
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "postgresql"
  version          = var.postgres_chart_version
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  timeout          = 600
  wait             = true

  values = [
    yamlencode({
      architecture = "standalone"
      auth = {
        enablePostgresUser = true
        existingSecret     = kubernetes_secret_v1.postgres_auth.metadata[0].name
        username           = var.bootstrap_owner_user
        database           = var.bootstrap_database_name
        secretKeys = {
          adminPasswordKey = "postgres-password"
          userPasswordKey  = "password"
        }
      }
      primary = {
        service = {
          type = "NodePort"
          nodePorts = {
            postgresql = var.postgresql_admin_port
          }
        }
        networkPolicy = {
          enabled = false
        }
        persistence = {
          enabled = true
          size    = "8Gi"
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_secret_v1.postgres_auth]
}

resource "terraform_data" "postgresql_connectivity_precheck" {
  triggers_replace = {
    host = var.postgresql_admin_host
    port = tostring(var.postgresql_admin_port)
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -euo pipefail
      host="${var.postgresql_admin_host}"
      port="${var.postgresql_admin_port}"
      retries="${var.postgresql_connectivity_max_retries}"
      sleep_seconds="${var.postgresql_connectivity_retry_seconds}"

      for i in $(seq 1 "${var.postgresql_connectivity_max_retries}"); do
        if nc -z "${var.postgresql_admin_host}" "${var.postgresql_admin_port}" >/dev/null 2>&1; then
          exit 0
        fi
        sleep "${var.postgresql_connectivity_retry_seconds}"
      done

      echo "PostgreSQL precheck failed: cannot reach ${var.postgresql_admin_host}:${var.postgresql_admin_port} from local host." >&2
      echo "If kind config changed, recreate cluster: make destroy-kind && make kind-up" >&2
      exit 1
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [helm_release.postgres]
}

resource "postgresql_role" "users" {
  for_each = var.users

  name             = each.key
  login            = try(each.value.login, true)
  superuser        = try(each.value.superuser, false)
  create_database  = try(each.value.create_database, false)
  create_role      = try(each.value.create_role, false)
  replication      = try(each.value.replication, false)
  connection_limit = try(each.value.connection_limit, -1)
  password         = each.value.password

  depends_on = [terraform_data.postgresql_connectivity_precheck]
}

resource "postgresql_database" "databases" {
  for_each = var.databases

  name       = each.value.name
  owner      = each.value.owner
  template   = try(each.value.template, "template0")
  encoding   = try(each.value.encoding, "UTF8")
  lc_collate = try(each.value.lc_collate, "C")
  lc_ctype   = try(each.value.lc_ctype, "C")

  depends_on = [postgresql_role.users]
}

resource "postgresql_schema" "schemas" {
  for_each = var.schemas

  database = each.value.database
  name     = each.value.name
  owner    = each.value.owner

  depends_on = [postgresql_database.databases]
}

resource "postgresql_grant" "database_connect" {
  for_each = local.connect_grants_by_key

  database    = each.value.database
  role        = each.value.role
  object_type = "database"
  privileges  = ["CONNECT"]

  depends_on = [postgresql_database.databases]
}

resource "postgresql_grant" "schema_usage" {
  for_each = local.schema_grants_by_key

  database    = each.value.database
  role        = each.value.role
  schema      = each.value.schema
  object_type = "schema"
  privileges  = ["USAGE"]

  depends_on = [postgresql_schema.schemas]
}

resource "postgresql_grant" "table_privileges" {
  for_each = local.table_grants_by_key

  database    = each.value.database
  role        = each.value.role
  schema      = each.value.schema
  object_type = "table"
  privileges  = each.value.privileges

  depends_on = [
    postgresql_schema.schemas,
    kubernetes_job_v1.tables_apply,
  ]
}

resource "postgresql_default_privileges" "future_table_privileges" {
  for_each = local.default_table_grants_by_key

  database    = each.value.database
  owner       = each.value.owner
  role        = each.value.role
  schema      = each.value.schema
  object_type = "table"
  privileges  = each.value.privileges

  depends_on = [postgresql_schema.schemas]
}

resource "kubernetes_config_map_v1" "tables_sql" {
  count = length(var.tables) > 0 ? 1 : 0

  metadata {
    name      = "${var.release_name}-tables-sql-${substr(sha1(local.tables_sql), 0, 8)}"
    namespace = var.namespace
    labels    = var.common_labels
  }

  data = {
    "tables.sql" = local.tables_sql
  }

  depends_on = [postgresql_schema.schemas]
}

resource "kubernetes_job_v1" "tables_apply" {
  count = length(var.tables) > 0 ? 1 : 0

  metadata {
    name      = "${var.release_name}-tables-apply-${substr(sha1(local.tables_sql), 0, 8)}"
    namespace = var.namespace
    labels    = var.common_labels
  }

  wait_for_completion = true

  spec {
    ttl_seconds_after_finished = 300

    template {
      metadata {
        labels = var.common_labels
      }

      spec {
        restart_policy = "Never"

        container {
          name  = "psql"
          image = var.tables_job_image

          command = ["/bin/sh", "-ec"]
          args = [
            "psql \"host=${local.internal_dns} port=5432 user=${var.postgresql_admin_user} dbname=${var.postgresql_admin_database} sslmode=${var.postgresql_sslmode}\" -v ON_ERROR_STOP=1 -f /sql/tables.sql",
          ]

          env {
            name = "PGPASSWORD"

            value_from {
              secret_key_ref {
                key  = "postgres-password"
                name = var.auth_secret_name
              }
            }
          }

          volume_mount {
            mount_path = "/sql"
            name       = "tables-sql"
            read_only  = true
          }
        }

        volume {
          name = "tables-sql"

          config_map {
            name = kubernetes_config_map_v1.tables_sql[0].metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.postgres,
    kubernetes_config_map_v1.tables_sql,
  ]
}

resource "kubernetes_network_policy_v1" "postgres_default_deny_ingress" {
  metadata {
    name      = "postgres-default-deny-ingress"
    namespace = var.namespace
    labels    = var.common_labels
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name"      = "postgresql"
        "app.kubernetes.io/component" = "primary"
      }
    }

    policy_types = ["Ingress"]
  }

  depends_on = [
    helm_release.postgres,
    postgresql_role.users,
    postgresql_database.databases,
    postgresql_schema.schemas,
    postgresql_grant.database_connect,
    postgresql_grant.schema_usage,
    postgresql_grant.table_privileges,
    postgresql_default_privileges.future_table_privileges,
    kubernetes_job_v1.tables_apply,
  ]
}

resource "kubernetes_network_policy_v1" "postgres_allow_clients" {
  metadata {
    name      = "postgres-allow-clients"
    namespace = var.namespace
    labels    = var.common_labels
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name"      = "postgresql"
        "app.kubernetes.io/component" = "primary"
      }
    }

    dynamic "ingress" {
      for_each = toset(var.allowed_client_namespaces)

      content {
        from {
          namespace_selector {
            match_labels = {
              "kubernetes.io/metadata.name" = ingress.value
            }
          }
        }

        ports {
          port     = 5432
          protocol = "TCP"
        }
      }
    }

    dynamic "ingress" {
      for_each = toset(var.allowed_admin_cidrs)

      content {
        from {
          ip_block {
            cidr = ingress.value
          }
        }

        ports {
          port     = 5432
          protocol = "TCP"
        }
      }
    }

    policy_types = ["Ingress"]
  }

  depends_on = [
    helm_release.postgres,
    postgresql_role.users,
    postgresql_database.databases,
    postgresql_schema.schemas,
    postgresql_grant.database_connect,
    postgresql_grant.schema_usage,
    postgresql_grant.table_privileges,
    postgresql_default_privileges.future_table_privileges,
    kubernetes_job_v1.tables_apply,
  ]
}
