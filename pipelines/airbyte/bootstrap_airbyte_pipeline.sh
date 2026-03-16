#!/usr/bin/env bash

set -euo pipefail

PORT_FORWARD_PORT="${PORT_FORWARD_PORT:-18080}"
AIRBYTE_BASE_URL="http://127.0.0.1:${PORT_FORWARD_PORT}"

required_vars=(
  AIRBYTE_CONNECTION_NAME
  AIRBYTE_DESTINATION_NAME
  AIRBYTE_NAMESPACE
  AIRBYTE_SERVER_SERVICE
  AIRBYTE_SOURCE_NAME
  AWS_ACCESS_KEY_ID
  AWS_REGION
  AWS_SECRET_ACCESS_KEY
  KUBE_CONTEXT
  POSTGRES_DATABASE
  POSTGRES_HOST
  POSTGRES_PASSWORD
  POSTGRES_PORT
  POSTGRES_SCHEMA
  POSTGRES_USER
  S3_BUCKET_NAME
  S3_BUCKET_PATH
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "missing required environment variable: ${var_name}" >&2
    exit 1
  fi
done

PORT_FORWARD_PID=""

cleanup() {
  if [[ -n "${PORT_FORWARD_PID}" ]] && kill -0 "${PORT_FORWARD_PID}" >/dev/null 2>&1; then
    kill "${PORT_FORWARD_PID}" >/dev/null 2>&1 || true
    wait "${PORT_FORWARD_PID}" 2>/dev/null || true
  fi
}

trap cleanup EXIT

kubectl --context "${KUBE_CONTEXT}" -n "${AIRBYTE_NAMESPACE}" port-forward "svc/${AIRBYTE_SERVER_SERVICE}" "${PORT_FORWARD_PORT}:8001" >/tmp/airbyte-port-forward.log 2>&1 &
PORT_FORWARD_PID=$!

for _ in {1..30}; do
  if curl -fsS "${AIRBYTE_BASE_URL}/api/public/v1/workspaces" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! curl -fsS "${AIRBYTE_BASE_URL}/api/public/v1/workspaces" >/dev/null 2>&1; then
  echo "airbyte API did not become ready in time" >&2
  exit 1
fi

workspace_id="$(
  curl -fsS "${AIRBYTE_BASE_URL}/api/public/v1/workspaces" | \
    python3 -c 'import json,sys; data=json.load(sys.stdin); print(data["data"][0]["workspaceId"])'
)"

postgres_definition_id="$(
  curl -fsS -X POST "${AIRBYTE_BASE_URL}/api/v1/source_definitions/list_latest" \
    -H 'Content-Type: application/json' \
    -d '{}' | \
    python3 -c 'import json,sys; data=json.load(sys.stdin); print(next(item["sourceDefinitionId"] for item in data["sourceDefinitions"] if item["name"]=="Postgres"))'
)"

s3_definition_id="$(
  curl -fsS -X POST "${AIRBYTE_BASE_URL}/api/v1/destination_definitions/list_latest" \
    -H 'Content-Type: application/json' \
    -d '{}' | \
    python3 -c 'import json,sys; data=json.load(sys.stdin); print(next(item["destinationDefinitionId"] for item in data["destinationDefinitions"] if item["name"]=="S3"))'
)"

source_id="$(
  curl -fsS -X POST "${AIRBYTE_BASE_URL}/api/v1/sources/list" \
    -H 'Content-Type: application/json' \
    -d "{\"workspaceId\":\"${workspace_id}\"}" | \
    python3 -c 'import json,os,sys; data=json.load(sys.stdin); target=os.environ["AIRBYTE_SOURCE_NAME"]; print(next((item["sourceId"] for item in data["sources"] if item["name"]==target), ""))'
)"

if [[ -z "${source_id}" ]]; then
  source_payload="$(cat <<JSON
{
  "name": "${AIRBYTE_SOURCE_NAME}",
  "workspaceId": "${workspace_id}",
  "sourceDefinitionId": "${postgres_definition_id}",
  "connectionConfiguration": {
    "host": "${POSTGRES_HOST}",
    "port": ${POSTGRES_PORT},
    "database": "${POSTGRES_DATABASE}",
    "schemas": ["${POSTGRES_SCHEMA}"],
    "username": "${POSTGRES_USER}",
    "password": "${POSTGRES_PASSWORD}",
    "ssl_mode": {"mode": "disable"},
    "replication_method": {"method": "Standard"},
    "tunnel_method": {"tunnel_method": "NO_TUNNEL"}
  }
}
JSON
)"
  source_id="$(
    curl -fsS -X POST "${AIRBYTE_BASE_URL}/api/v1/sources/create" \
      -H 'Content-Type: application/json' \
      -d "${source_payload}" | \
      python3 -c 'import json,sys; data=json.load(sys.stdin); print(data["sourceId"])'
  )"
fi

destination_id="$(
  curl -fsS -X POST "${AIRBYTE_BASE_URL}/api/v1/destinations/list" \
    -H 'Content-Type: application/json' \
    -d "{\"workspaceId\":\"${workspace_id}\"}" | \
    python3 -c 'import json,os,sys; data=json.load(sys.stdin); target=os.environ["AIRBYTE_DESTINATION_NAME"]; print(next((item["destinationId"] for item in data["destinations"] if item["name"]==target), ""))'
)"

if [[ -z "${destination_id}" ]]; then
  destination_payload="$(cat <<JSON
{
  "name": "${AIRBYTE_DESTINATION_NAME}",
  "workspaceId": "${workspace_id}",
  "destinationDefinitionId": "${s3_definition_id}",
  "connectionConfiguration": {
    "s3_bucket_name": "${S3_BUCKET_NAME}",
    "s3_bucket_path": "${S3_BUCKET_PATH}",
    "s3_bucket_region": "${AWS_REGION}",
    "access_key_id": "${AWS_ACCESS_KEY_ID}",
    "secret_access_key": "${AWS_SECRET_ACCESS_KEY}",
    "format": {"format_type": "JSONL"},
    "s3_path_format": "\${NAMESPACE}/\${STREAM_NAME}/\${YEAR}_\${MONTH}_\${DAY}_\${EPOCH}",
    "file_name_pattern": "{date}",
    "s3_endpoint": ""
  }
}
JSON
)"
  destination_id="$(
    curl -fsS -X POST "${AIRBYTE_BASE_URL}/api/v1/destinations/create" \
      -H 'Content-Type: application/json' \
      -d "${destination_payload}" | \
      python3 -c 'import json,sys; data=json.load(sys.stdin); print(data["destinationId"])'
  )"
fi

catalog="$(
  curl -fsS -X POST "${AIRBYTE_BASE_URL}/api/v1/sources/discover_schema" \
    -H 'Content-Type: application/json' \
    -d "{\"sourceId\":\"${source_id}\"}" | \
    python3 -c 'import json,sys; data=json.load(sys.stdin); print(json.dumps(data["catalog"]))'
)"

connection_id="$(
  curl -fsS -X POST "${AIRBYTE_BASE_URL}/api/v1/connections/list" \
    -H 'Content-Type: application/json' \
    -d "{\"workspaceId\":\"${workspace_id}\"}" | \
    python3 -c 'import json,os,sys; data=json.load(sys.stdin); target=os.environ["AIRBYTE_CONNECTION_NAME"]; print(next((item["connectionId"] for item in data["connections"] if item["name"]==target), ""))'
)"

if [[ -z "${connection_id}" ]]; then
  connection_payload="$(cat <<JSON
{
  "name": "${AIRBYTE_CONNECTION_NAME}",
  "sourceId": "${source_id}",
  "destinationId": "${destination_id}",
  "syncCatalog": ${catalog},
  "status": "active",
  "scheduleType": "manual"
}
JSON
)"
  curl -fsS -X POST "${AIRBYTE_BASE_URL}/api/v1/connections/create" \
    -H 'Content-Type: application/json' \
    -d "${connection_payload}" >/dev/null
fi

printf '%s\n' \
  "Airbyte workspace: ${workspace_id}" \
  "Source: ${AIRBYTE_SOURCE_NAME}" \
  "Destination: ${AIRBYTE_DESTINATION_NAME}" \
  "Connection: ${AIRBYTE_CONNECTION_NAME}"
