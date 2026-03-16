variable "allowed_client_namespaces" {
  description = "Namespaces allowed to reach PostgreSQL on TCP/5432."
  type        = list(string)
  default     = ["airbyte"]
}

variable "allowed_admin_cidrs" {
  description = "CIDRs allowed to reach PostgreSQL on TCP/5432 for local admin/provider access."
  type        = list(string)
  default     = []
}

variable "auth_secret_name" {
  description = "Kubernetes Secret name that stores PostgreSQL bootstrap credentials."
  type        = string
  default     = "sequra-postgres-auth"
}

variable "common_labels" {
  description = "Labels shared across resources."
  type        = map(string)
  default     = {}
}

variable "bootstrap_database_name" {
  description = "Database created by Helm for bootstrap operations."
  type        = string
  default     = "bootstrap_db"
}

variable "bootstrap_owner_password" {
  description = "Password for the bootstrap owner created by Helm."
  type        = string
  sensitive   = true
  default     = "change-me-bootstrap-owner"
}

variable "bootstrap_owner_user" {
  description = "Owner user created by Helm for bootstrap operations."
  type        = string
  default     = "bootstrap_owner"
}

variable "databases" {
  description = "Databases to manage in PostgreSQL."
  type = map(object({
    name       = string
    owner      = string
    encoding   = optional(string, "UTF8")
    lc_collate = optional(string, "C")
    lc_ctype   = optional(string, "C")
    template   = optional(string, "template0")
  }))
  default = {
    source = {
      name  = "airbyte_source_db"
      owner = "app_owner"
    }
  }
}

variable "namespace" {
  description = "Namespace where PostgreSQL will be deployed."
  type        = string
}

variable "postgres_chart_version" {
  description = "Bitnami PostgreSQL chart version."
  type        = string
  default     = "18.5.6"
}

variable "postgresql_admin_database" {
  description = "Database used by Terraform PostgreSQL provider connection."
  type        = string
  default     = "postgres"
}

variable "postgresql_admin_host" {
  description = "Host used by Terraform PostgreSQL provider connection."
  type        = string
  default     = "127.0.0.1"
}

variable "postgresql_admin_password" {
  description = "Password used by Terraform PostgreSQL provider connection."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.postgresql_admin_password)) > 0
    error_message = "postgresql_admin_password must be set."
  }
}

variable "postgresql_admin_port" {
  description = "Port used by Terraform PostgreSQL provider connection."
  type        = number
  default     = 30432
}

variable "postgresql_admin_user" {
  description = "User used by Terraform PostgreSQL provider connection."
  type        = string
  default     = "postgres"
}

variable "postgresql_connect_timeout" {
  description = "Timeout in seconds for PostgreSQL provider connections."
  type        = number
  default     = 15
}

variable "postgresql_connectivity_max_retries" {
  description = "Max retries for the local connectivity precheck before PostgreSQL provider resources are applied."
  type        = number
  default     = 20
}

variable "postgresql_connectivity_retry_seconds" {
  description = "Seconds to wait between local connectivity precheck retries."
  type        = number
  default     = 2
}

variable "postgresql_sslmode" {
  description = "SSL mode for PostgreSQL provider connections."
  type        = string
  default     = "disable"
}

variable "release_name" {
  description = "Helm release name for PostgreSQL."
  type        = string
  default     = "sequra-postgres"
}

variable "schemas" {
  description = "Schemas to manage in PostgreSQL."
  type = map(object({
    database = string
    name     = string
    owner    = string
  }))
  default = {
    source_public = {
      database = "airbyte_source_db"
      name     = "public"
      owner    = "app_owner"
    }
  }
}

variable "tables" {
  description = "Tables to create/manage from HCL."
  type = map(object({
    database = string
    schema   = string
    name     = string
    owner    = optional(string)
    columns = list(object({
      name     = string
      type     = string
      nullable = optional(bool, true)
      default  = optional(string)
    }))
    primary_key = optional(list(string), [])
    indexes = optional(list(object({
      name    = string
      columns = list(string)
      unique  = optional(bool, false)
    })), [])
    grants = optional(map(list(string)), {})
  }))
  default = {
    bank_customers = {
      database = "airbyte_source_db"
      schema   = "public"
      name     = "bank_customers"
      columns = [
        {
          name     = "customer_id"
          type     = "bigserial"
          nullable = false
        },
        {
          name     = "full_name"
          type     = "text"
          nullable = false
        },
        {
          name     = "email"
          type     = "text"
          nullable = false
        },
        {
          name     = "country_code"
          type     = "text"
          nullable = false
        },
        {
          name     = "created_at"
          type     = "timestamptz"
          nullable = false
          default  = "now()"
        }
      ]
      primary_key = ["customer_id"]
      indexes = [
        {
          name    = "idx_bank_customers_email"
          columns = ["email"]
          unique  = true
        }
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
        {
          name     = "transaction_id"
          type     = "bigserial"
          nullable = false
        },
        {
          name     = "customer_id"
          type     = "bigint"
          nullable = false
        },
        {
          name     = "card_last4"
          type     = "char(4)"
          nullable = false
        },
        {
          name     = "amount"
          type     = "numeric(12,2)"
          nullable = false
        },
        {
          name     = "currency"
          type     = "char(3)"
          nullable = false
          default  = "'EUR'"
        },
        {
          name     = "merchant"
          type     = "text"
          nullable = false
        },
        {
          name     = "status"
          type     = "text"
          nullable = false
        },
        {
          name     = "occurred_at"
          type     = "timestamptz"
          nullable = false
        }
      ]
      primary_key = ["transaction_id"]
      indexes = [
        {
          name    = "idx_card_transactions_customer_id"
          columns = ["customer_id"]
        },
        {
          name    = "idx_card_transactions_occurred_at"
          columns = ["occurred_at"]
        }
      ]
      grants = {
        airbyte_reader = ["SELECT"]
      }
    }
  }
}

variable "tables_job_image" {
  description = "Container image used by the internal SQL job that creates/updates tables."
  type        = string
  default     = "postgres:16"
}

variable "users" {
  description = "Roles/users to manage in PostgreSQL."
  type = map(object({
    password         = string
    login            = optional(bool, true)
    superuser        = optional(bool, false)
    create_database  = optional(bool, false)
    create_role      = optional(bool, false)
    replication      = optional(bool, false)
    connection_limit = optional(number, -1)
  }))
  default = {
    app_owner = {
      password = "change-me-owner"
      login    = true
    }
    airbyte_reader = {
      password = "change-me-reader"
      login    = true
    }
  }
}
