locals {
  yaml_pipeline_files = var.pipeline_yaml_directory == null ? [] : sort(fileset(var.pipeline_yaml_directory, "*.yaml"))

  yaml_pipelines_raw = [
    for rel_path in local.yaml_pipeline_files : merge(
      yamldecode(file("${var.pipeline_yaml_directory}/${rel_path}")),
      { _file = rel_path }
    )
  ]

  yaml_pipeline_map = {
    for pipeline in local.yaml_pipelines_raw : pipeline.pipeline_key => {
      enabled       = try(pipeline.enabled, true)
      pipeline_name = try(pipeline.pipeline_name, null)
      source = {
        postgres = {
          host               = pipeline.source.postgres.host
          port               = try(pipeline.source.postgres.port, 5432)
          database           = pipeline.source.postgres.database
          schema             = pipeline.source.postgres.schema
          username           = pipeline.source.postgres.username
          password           = pipeline.source.postgres.password
          ssl_mode           = try(pipeline.source.postgres.ssl_mode, "disable")
          replication_method = try(pipeline.source.postgres.replication_method, "Standard")
        }
      }
      destination = {
        s3 = {
          endpoint   = pipeline.destination.s3.endpoint
          bucket     = pipeline.destination.s3.bucket
          path       = pipeline.destination.s3.path
          region     = pipeline.destination.s3.region
          access_key = pipeline.destination.s3.access_key
          secret_key = pipeline.destination.s3.secret_key
        }
      }
      connection = {
        status        = try(pipeline.connection.status, "active")
        schedule_cron = try(pipeline.connection.schedule_cron, "0 0 0/6 * * ?")
        streams = [
          for stream in pipeline.connection.streams : {
            name      = stream.name
            namespace = try(stream.namespace, null)
            sync_mode = try(stream.sync_mode, "full_refresh_overwrite")
          }
        ]
      }
    }
  }

  pipelines_merged = merge(var.pipelines, local.yaml_pipeline_map)

  yaml_pipeline_keys = [for pipeline in local.yaml_pipelines_raw : try(trimspace(pipeline.pipeline_key), "")]

  duplicate_yaml_pipeline_keys = distinct([
    for key in local.yaml_pipeline_keys : key
    if key != "" && length([for candidate in local.yaml_pipeline_keys : candidate if candidate == key]) > 1
  ])

  invalid_yaml_required_fields = flatten([
    for pipeline in local.yaml_pipelines_raw : compact([
      try(length(trimspace(pipeline.pipeline_key)) > 0, false) ? null : "${pipeline._file}: pipeline_key",
      try(length(trimspace(pipeline.source.postgres.host)) > 0, false) ? null : "${pipeline._file}: source.postgres.host",
      try(length(trimspace(pipeline.source.postgres.database)) > 0, false) ? null : "${pipeline._file}: source.postgres.database",
      try(length(trimspace(pipeline.source.postgres.schema)) > 0, false) ? null : "${pipeline._file}: source.postgres.schema",
      try(length(trimspace(pipeline.source.postgres.username)) > 0, false) ? null : "${pipeline._file}: source.postgres.username",
      try(length(trimspace(pipeline.source.postgres.password)) > 0, false) ? null : "${pipeline._file}: source.postgres.password",
      try(length(trimspace(pipeline.destination.s3.endpoint)) > 0, false) ? null : "${pipeline._file}: destination.s3.endpoint",
      try(length(trimspace(pipeline.destination.s3.bucket)) > 0, false) ? null : "${pipeline._file}: destination.s3.bucket",
      try(length(trimspace(pipeline.destination.s3.path)) > 0, false) ? null : "${pipeline._file}: destination.s3.path",
      try(length(trimspace(pipeline.destination.s3.region)) > 0, false) ? null : "${pipeline._file}: destination.s3.region",
      try(length(trimspace(pipeline.destination.s3.access_key)) > 0, false) ? null : "${pipeline._file}: destination.s3.access_key",
      try(length(trimspace(pipeline.destination.s3.secret_key)) > 0, false) ? null : "${pipeline._file}: destination.s3.secret_key",
      try(length(trimspace(pipeline.connection.schedule_cron)) > 0, false) ? null : "${pipeline._file}: connection.schedule_cron",
      try(length(pipeline.connection.streams) > 0, false) ? null : "${pipeline._file}: connection.streams",
    ])
  ])

  invalid_yaml_cron_files = [
    for pipeline in local.yaml_pipelines_raw : pipeline._file
    if !try(can(regex("^([0-9*/?,L#-]+\\s+){5,6}[0-9*/?,L#-]+$", pipeline.connection.schedule_cron)), false)
  ]

  enabled_pipelines = {
    for key, pipeline in local.pipelines_merged :
    key => pipeline
    if try(pipeline.enabled, true)
  }

  named_enabled_pipelines = {
    for key, pipeline in local.enabled_pipelines :
    key => merge(pipeline, { pipeline_name = coalesce(try(pipeline.pipeline_name, null), key) })
  }

  failed_validation_pipelines = [
    for key, pipeline in local.pipelines_merged : key
    if length(trimspace(pipeline.destination.s3.bucket)) == 0 ||
    length(trimspace(pipeline.destination.s3.path)) == 0 ||
    !can(regex("^([0-9*/?,L#-]+\\s+){5,6}[0-9*/?,L#-]+$", pipeline.connection.schedule_cron))
  ]
}

check "at_least_one_pipeline_definition" {
  assert {
    condition     = length(local.pipelines_merged) > 0
    error_message = "No pipelines defined. Add YAML files to pipeline_yaml_directory or pass var.pipelines."
  }
}

check "yaml_pipeline_keys_are_unique_and_not_empty" {
  assert {
    condition     = length(local.yaml_pipeline_keys) == length(distinct(local.yaml_pipeline_keys)) && length([for key in local.yaml_pipeline_keys : key if length(key) == 0]) == 0
    error_message = "YAML pipeline_key must be non-empty and unique. Duplicate keys: ${join(", ", local.duplicate_yaml_pipeline_keys)}"
  }
}

check "yaml_required_fields_present" {
  assert {
    condition     = length(local.invalid_yaml_required_fields) == 0
    error_message = "YAML missing/empty required fields: ${join(", ", local.invalid_yaml_required_fields)}"
  }
}

check "yaml_schedule_cron_format_valid" {
  assert {
    condition     = length(local.invalid_yaml_cron_files) == 0
    error_message = "YAML invalid Quartz cron in files: ${join(", ", local.invalid_yaml_cron_files)}"
  }
}

data "airbyte_connector_configuration" "source_postgres" {
  for_each       = local.named_enabled_pipelines
  connector_name = "source-postgres"

  configuration = {
    host     = each.value.source.postgres.host
    port     = each.value.source.postgres.port
    database = each.value.source.postgres.database
    schemas  = [each.value.source.postgres.schema]
    ssl_mode = {
      mode = each.value.source.postgres.ssl_mode
    }
    replication_method = {
      method = each.value.source.postgres.replication_method
    }
    tunnel_method = {
      tunnel_method = "NO_TUNNEL"
    }
  }

  configuration_secrets = {
    username = each.value.source.postgres.username
    password = each.value.source.postgres.password
  }
}

resource "airbyte_source" "postgres" {
  for_each = local.named_enabled_pipelines

  name          = "${each.value.pipeline_name}-source-postgres"
  workspace_id  = var.airbyte_workspace_id
  definition_id = data.airbyte_connector_configuration.source_postgres[each.key].definition_id
  configuration = data.airbyte_connector_configuration.source_postgres[each.key].configuration_json
}

data "airbyte_connector_configuration" "destination_s3" {
  for_each       = local.named_enabled_pipelines
  connector_name = "destination-s3"

  configuration = {
    s3_bucket_name   = each.value.destination.s3.bucket
    s3_bucket_path   = each.value.destination.s3.path
    s3_bucket_region = each.value.destination.s3.region
    s3_endpoint      = each.value.destination.s3.endpoint
    format = {
      format_type = "JSONL"
    }
    file_name_pattern = "{date}"
    s3_path_format    = "$${NAMESPACE}/$${STREAM_NAME}/$${YEAR}_$${MONTH}_$${DAY}_$${EPOCH}"
  }

  configuration_secrets = {
    access_key_id     = each.value.destination.s3.access_key
    secret_access_key = each.value.destination.s3.secret_key
  }
}

resource "airbyte_destination" "s3" {
  for_each = local.named_enabled_pipelines

  name          = "${each.value.pipeline_name}-destination-s3"
  workspace_id  = var.airbyte_workspace_id
  definition_id = data.airbyte_connector_configuration.destination_s3[each.key].definition_id
  configuration = data.airbyte_connector_configuration.destination_s3[each.key].configuration_json
}

resource "airbyte_connection" "pipeline" {
  for_each = local.named_enabled_pipelines

  name           = "${each.value.pipeline_name}-connection"
  source_id      = airbyte_source.postgres[each.key].source_id
  destination_id = airbyte_destination.s3[each.key].destination_id
  status         = each.value.connection.status

  schedule = {
    schedule_type   = "cron"
    cron_expression = "${trimspace(each.value.connection.schedule_cron)} UTC"
  }

  configurations = length(each.value.connection.streams) > 0 ? {
    streams = [
      for stream in each.value.connection.streams : merge(
        {
          name      = stream.name
          sync_mode = stream.sync_mode
        },
        try(stream.namespace, null) != null ? { namespace = stream.namespace } : {}
      )
    ]
  } : null

}
