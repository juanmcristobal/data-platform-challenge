# Pipelines

This directory is reserved for ingestion pipeline definitions and related utilities.

It is intentionally separate from `infra/services/`, which only contains base infrastructure and installable platform components.

Current contents:

- `airbyte/`
  - Terraform/Terragrunt pipeline-as-code root for Airbyte source/destination/connection

Entrypoint:

- `terragrunt --working-dir=pipelines/airbyte <init|plan|apply|destroy>`
