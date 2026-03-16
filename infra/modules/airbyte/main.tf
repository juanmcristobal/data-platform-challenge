locals {
  service_name = "${var.release_name}-airbyte-server-svc"
}

resource "helm_release" "airbyte" {
  name              = var.release_name
  namespace         = var.namespace
  repository        = "https://airbytehq.github.io/helm-charts"
  chart             = "airbyte"
  version           = var.airbyte_chart_version
  create_namespace  = false
  dependency_update = true
  atomic            = true
  cleanup_on_fail   = true
  timeout           = 1200
  wait              = true

  values = [
    yamlencode({
      ingress = {
        enabled = false
      }
      global = {
        edition = "community"
        auth = {
          enabled = false
        }
        jobs = {
          resources = {
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "1Gi"
            }
          }
        }
      }
      webapp = {
        enabled = var.webapp_enabled
      }
      server = {
        enabled = true
        startupProbe = {
          enabled             = true
          httpGet             = { path = "/api/v1/health", port = "http" }
          initialDelaySeconds = 30
          periodSeconds       = 10
          timeoutSeconds      = 5
          failureThreshold    = 30
        }
        livenessProbe = {
          enabled             = true
          httpGet             = { path = "/api/v1/health", port = "http" }
          initialDelaySeconds = 180
          periodSeconds       = 10
          timeoutSeconds      = 10
          failureThreshold    = 6
        }
        readinessProbe = {
          enabled             = true
          httpGet             = { path = "/api/v1/health", port = "http" }
          initialDelaySeconds = 60
          periodSeconds       = 10
          timeoutSeconds      = 10
          failureThreshold    = 6
        }
        resources = {
          requests = {
            cpu    = "250m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
        }
      }
      worker = {
        enabled = true
        resources = {
          requests = {
            cpu    = "250m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
        }
      }
      workload-launcher = {
        enabled = true
        startupProbe = {
          enabled             = true
          httpGet             = { path = "/health/liveness", port = "heartbeat" }
          initialDelaySeconds = 20
          periodSeconds       = 10
          timeoutSeconds      = 2
          failureThreshold    = 30
        }
        livenessProbe = {
          enabled             = true
          httpGet             = { path = "/health/liveness", port = "heartbeat" }
          initialDelaySeconds = 180
          periodSeconds       = 10
          timeoutSeconds      = 2
          failureThreshold    = 6
        }
        readinessProbe = {
          enabled             = true
          httpGet             = { path = "/health/readiness", port = "heartbeat" }
          initialDelaySeconds = 45
          periodSeconds       = 10
          timeoutSeconds      = 2
          failureThreshold    = 6
        }
        resources = {
          requests = {
            cpu    = "150m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
      workload-api-server = {
        enabled = true
        startupProbe = {
          enabled             = true
          httpGet             = { path = "/health/liveness", port = 8085 }
          initialDelaySeconds = 20
          periodSeconds       = 10
          timeoutSeconds      = 10
          failureThreshold    = 30
        }
        livenessProbe = {
          enabled             = true
          httpGet             = { path = "/health/liveness", port = 8085 }
          initialDelaySeconds = 120
          periodSeconds       = 10
          timeoutSeconds      = 10
          failureThreshold    = 6
        }
        readinessProbe = {
          enabled             = true
          httpGet             = { path = "/health/liveness", port = 8085 }
          initialDelaySeconds = 45
          periodSeconds       = 10
          timeoutSeconds      = 10
          failureThreshold    = 6
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "250m"
            memory = "512Mi"
          }
        }
      }
      airbyte-bootloader = {
        enabled = true
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "250m"
            memory = "512Mi"
          }
        }
      }
      temporal = {
        enabled = true
        resources = {
          requests = {
            cpu    = "250m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
        }
      }
      temporal-ui = {
        enabled = var.temporal_ui_enabled
      }
      cron = {
        enabled = var.cron_enabled
      }
      connector-builder-server = {
        enabled = var.connector_builder_server_enabled
      }
      connector-rollout-worker = {
        enabled = var.connector_rollout_worker_enabled
      }
      metrics = {
        enabled = var.metrics_enabled
      }
      keycloak = {
        enabled = var.keycloak_enabled
      }
    })
  ]
}

# Discover the default workspace created by Airbyte using kubectl exec
data "external" "workspace_id" {
  depends_on = [helm_release.airbyte]

  program = [
    "bash",
    "-c",
    <<-EOT
      # Wait for Airbyte server to be ready
      for i in {1..60}; do
        WORKSPACE_JSON=$(
          kubectl exec -n ${var.namespace} \
            deployment/sequra-airbyte-server \
            -- curl -s http://localhost:8001/api/public/v1/workspaces 2>/dev/null
        )
        if [ -n "$WORKSPACE_JSON" ]; then
          break
        fi
        sleep 2
      done

      # Extract workspace ID
      WORKSPACE_ID=$(echo "$WORKSPACE_JSON" | jq -r '.data[0].workspaceId // empty')

      if [ -z "$WORKSPACE_ID" ]; then
        echo '{"workspace_id": ""}' >&2
        exit 1
      fi

      echo "{\"workspace_id\":\"$WORKSPACE_ID\"}"
    EOT
  ]
}
