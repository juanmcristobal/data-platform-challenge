# SeQura Data Platform - Installation Guide

Complete step-by-step guide for deploying and validating the data platform architecture.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Environment Setup](#2-environment-setup)
3. [Cluster Deployment](#3-cluster-deployment)
4. [Services Deployment](#4-services-deployment)
5. [Database Setup](#5-database-setup)
6. [Pipeline Deployment](#6-pipeline-deployment)
7. [End-to-End Validation](#7-end-to-end-validation)
8. [Cleanup](#8-cleanup)

---

## 1. Prerequisites

### 1.1 Required Tools

- Docker Desktop or Docker Engine
- kubectl (Kubernetes CLI)
- kind (Kubernetes in Docker)
- helm (Kubernetes package manager)
- terraform
- terragrunt
- netcat (`nc`)

### 1.2 Tool Versions Verification

```bash
# Check all required tools
docker --version
kubectl version --client
kind version
helm version
terraform version
terragrunt --version
nc -h >/dev/null 2>&1 && echo "✓ netcat available"
```

**Expected output:**
```text
Docker version 26.0.0 or higher
Client Version: v1.35.0
kind v0.26.0 or higher
version.BuildInfo{Version:"v3.17.0"}
Terraform v1.9.8
terragrunt v0.68.0
✓ netcat available
```

---

## 2. Environment Setup

### 2.1 Navigate to Project Directory

```bash
cd /path/to/sequra-data-platform-challenge
```

### 2.2 Kubernetes Context Configuration

**Note:** `TG_KUBE_CONTEXT` is pre-configured as `kind-sequra-platform` in `infra/root.hcl`.

For direct `kubectl` commands, you have two options:

**Option A:** Use context flag in each command
```bash
kubectl --context kind-sequra-platform <command>
```

**Option B:** Set default context once
```bash
kubectl config use-context kind-sequra-platform
```

### 2.3 Secret Configuration

Review and adjust credentials in the following files:

- `infra/services/03-postgres/terragrunt.hcl`
- `infra/services/04-minio/terragrunt.hcl`
- `infra/services/05-minio-buckets/terragrunt.hcl`
- `pipelines/airbyte/pipelines/*.yaml`

**Default credentials (for demo environment):**
```hcl
# PostgreSQL
postgresql_admin_password = "change-me-admin-password"
users.app_owner.password      = "change-me-owner-pass"
users.airbyte_reader.password  = "change-me-reader-pass"

# MinIO
root_password    = "change-me-minio-password"
minio_secret_key = "change-me-minio-password"
```

---

## 3. Cluster Deployment

### 3.1 Create KIND Cluster with Cilium

```bash
make kind-up
```

**Expected output:**
```text
Creating cluster "sequra-platform" ...
✓ Ensuring node image (kindest/node:v1.35.0) 🖼
✓ Preparing nodes 📦 📦 📦
✓ Writing configuration 📜
✓ Starting control-plane 🕹️
✓ Installing StorageClass 💾
✓ Joining worker nodes 🚜
Set kubectl context to "kind-sequra-platform"

Release "cilium" does not exist. Installing it now...
NAME: cilium
LAST DEPLOYED: <date>
NAMESPACE: kube-system
STATUS: deployed
```

### 3.2 Verify Cluster Health

```bash
# Wait for all nodes to be ready
kubectl wait --for=condition=Ready node --all --timeout=120s

# Check node status
kubectl get nodes

# Verify Cilium DaemonSet
kubectl -n kube-system get ds cilium

# Verify StorageClass
kubectl get storageclass
```

**Expected output:**
```text
NAME                            STATUS   ROLES           AGE   VERSION
sequra-platform-control-plane   Ready    control-plane   5m    v1.35.0
sequra-platform-worker          Ready    <none>          5m    v1.35.0
sequra-platform-worker2         Ready    <none>          5m    v1.35.0

NAME     DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
cilium   3         3         3       3            3           kubernetes.io/os=linux   2m

NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      AGE
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   5m
```

---

## 4. Services Deployment

Deploy services in strict order: `01 → 02 → 03 → 04 → 05`

### Recommended one-shot deployment

```bash
make install
```

This runs:
- `make install-platform` (`01-namespaces`, `02-airbyte`, `03-postgres`)
- `make install-storage` (`04-minio`, `05-minio-buckets`)

### 4.1 Service 01 - Namespaces

```bash
make svc-01-apply
```

**Verification:**
```bash
kubectl get ns
```

**Expected namespaces:**
```text
NAME                 STATUS   AGE
airbyte              Active   30s
data-source          Active   30s
kube-system          Active   5m
local-path-storage   Active   5m
minio                Active   30s
```

### 4.2 Service 02 - Airbyte

```bash
make svc-02-apply
```

**Expected duration:** ~5 minutes

**Verification:**
```bash
kubectl get pods -n airbyte
```

**Expected pods:**
```text
NAME                                                 READY   STATUS      RESTARTS   AGE
airbyte-db-0                                         1/1     Running     0          5m
airbyte-minio-0                                      1/1     Running     0          5m
sequra-airbyte-airbyte-bootloader                    0/1     Completed   0          5m
sequra-airbyte-cron-xxxxxxxxxx-xxxxx                 1/1     Running     0          2m
sequra-airbyte-server-xxxxxxxxxx-xxxxx               1/1     Running     0          2m
sequra-airbyte-temporal-xxxxxxxxxx-xxxxx             1/1     Running     0          2m
sequra-airbyte-worker-xxxxxxxxxx-xxxxx               1/1     Running     0          2m
sequra-airbyte-workload-api-server-xxxxxxxxxx-xxxxx  1/1     Running     0          2m
sequra-airbyte-workload-launcher-xxxxxxxxxx-xxxxx    1/1     Running     1          2m
```

**Capture workspace_id for later:**
```bash
terragrunt --working-dir infra/services/02-airbyte output -raw workspace_id
```

### 4.3 Service 03 - PostgreSQL

```bash
make svc-03-apply
```

**Expected duration:** ~2 minutes

**Verification:**
```bash
kubectl get pods -n data-source
```

**Expected output:**
```text
NAME                                          READY   STATUS      RESTARTS   AGE
sequra-postgres-postgresql-0                  1/1     Running     0          2m
```

**Note:** If the tables apply job fails due image pulls, run `make pull` and re-run `make svc-03-apply`.

### 4.4 Service 04 - MinIO

```bash
make svc-04-apply
```

**Expected duration:** ~1 minute

**Verification:**
```bash
kubectl get pods -n minio
```

**Expected output:**
```text
NAME                                    READY   STATUS    RESTARTS   AGE
sequra-minio-xxxxxxxxxx-xxxxx           1/1     Running   0          1m
sequra-minio-console-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
```

### 4.5 Service 05 - MinIO Buckets

```bash
make svc-05-apply
```

**Verification:**
```bash
terragrunt --working-dir infra/services/05-minio-buckets output
```

**Expected output:**
```text
bucket_arns = {
  "data-lake-analytics" = "arn:aws:s3:::data-lake-analytics"
  "data-lake-processed" = "arn:aws:s3:::data-lake-processed"
  "data-lake-raw" = "arn:aws:s3:::data-lake-raw"
}
bucket_names = {
  "data-lake-analytics" = "data-lake-analytics"
  "data-lake-processed" = "data-lake-processed"
  "data-lake-raw" = "data-lake-raw"
}
```

---

## 5. Database Setup

### 5.1 Seed Demo Data (Recommended)

```bash
make generate-bank-demo-data
```

**Expected output:**
```text
CREATE TABLE
CREATE TABLE
INSERT 0 120
INSERT 0 1500
GRANT
GRANT
Generated bank demo data successfully:
- bank_customers: +120 attempted rows
- card_transactions: +1500 rows
```

### 5.2 Verify Data Exists

```bash
kubectl --context kind-sequra-platform -n data-source exec sequra-postgres-postgresql-0 -- bash -lc \
'PGPASSWORD="$(cat /opt/bitnami/postgresql/secrets/postgres-password)" \
psql -U postgres -d airbyte_source_db -c "SELECT COUNT(*) FROM public.bank_customers; SELECT COUNT(*) FROM public.card_transactions;"'

```

**Expected output:**
```text
 count 
-------
   120
(1 row)

 count 
-------
  1500
(1 row)
```

---

## 6. Pipeline Deployment

### 6.1 Setup Airbyte API Access

**Option A: Using Make (Recommended)**
```bash
make install-pipeline
```

`install-pipeline` runs:
- `make generate-bank-demo-data`
- `make pipeline-airbyte-apply`

The `pipeline-airbyte-apply` target is configured to use `-parallelism=1` to avoid Airbyte API race conditions when creating source and destination in the same apply.

**Option B: Manual Setup**

```bash
# Get Airbyte namespace and service
AIRBYTE_NAMESPACE="$(terragrunt --working-dir infra/services/02-airbyte output -raw namespace)"
AIRBYTE_SERVICE="$(terragrunt --working-dir infra/services/02-airbyte output -raw service_name)"

# Start port-forward in background
kubectl -n "$AIRBYTE_NAMESPACE" \
  port-forward "svc/$AIRBYTE_SERVICE" 18080:8001 >/tmp/airbyte-pf.log 2>&1 &
PF_PID=$!

# Trap to cleanup on exit
trap 'kill $PF_PID >/dev/null 2>&1 || true' EXIT

# Wait for port-forward to be ready
sleep 5
nc -zv 127.0.0.1 18080

# Apply pipeline
terragrunt --working-dir pipelines/airbyte init
terragrunt --working-dir pipelines/airbyte validate
terragrunt --working-dir pipelines/airbyte plan
terragrunt --working-dir pipelines/airbyte apply -auto-approve

# Get pipeline IDs
terragrunt --working-dir pipelines/airbyte output
```

**Expected output:**
```text
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

enabled_pipelines = [
  "postgres_to_minio_banking_transactions",
]
pipeline_ids = {
  "postgres_to_minio_banking_transactions" = {
    "connection_id" = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    "destination_id" = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    "source_id"      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  }
}
```

### 6.2 Verify Pipeline Creation

```bash
# With port-forward running
curl -s http://127.0.0.1:8080/api/public/v1/connections | jq '.data[] | {name, status}'
```

**Expected output:**
```json
{
  "name": "postgres_to_minio_banking_transactions-connection",
  "status": "active"
}
```

---

## 7. End-to-End Validation

### 7.1 Trigger Manual Sync

```bash
# Get connection ID from output
CONNECTION_ID=$(curl -s http://127.0.0.1:8080/api/public/v1/connections \
  | jq -r '.data[] | select(.name=="postgres_to_minio_banking_transactions-connection") | .connectionId')

echo "$CONNECTION_ID"

# Trigger sync job
curl -i -s -X POST http://127.0.0.1:8080/api/public/v1/jobs \
  -H "Content-Type: application/json" \
  -d "{\"connectionId\":\"$CONNECTION_ID\",\"jobType\":\"sync\"}"
```

**Expected output:**
```bash
HTTP/1.1 200 Ok
date: Mon, 16 Mar 2026 08:19:16 GMT
content-type: application/json
content-length: 154

{"jobId":1,"status":"running","jobType":"sync","startTime":"2026-03-16T08:19:13Z","connectionId":"21ca0ac3-803f-4ad2-9d08-81e79eb2e2e3","duration":"PT1S"}% 
```

### 7.2 Monitor Sync Progress

```bash
# Wait for sync to complete (usually 30-60 seconds)
sleep 45

# Check job status
curl -s http://127.0.0.1:8080/api/public/v1/jobs | jq '.data[0]'
```

**Expected output:**
```json
{
  "jobId": 1,
  "status": "succeeded",
  "jobType": "sync",
  "startTime": "2026-03-16T08:19:13Z",
  "connectionId": "21ca0ac3-803f-4ad2-9d08-81e79eb2e2e3",
  "lastUpdatedAt": "2026-03-16T08:20:41Z",
  "duration": "PT1M28S",
  "bytesSynced": 586475,
  "rowsSynced": 3240
}
```

### 7.3 Verify Data in MinIO

```bash
# Setup MinIO client
MINIO_POD=$(kubectl get pod -n minio -l app.kubernetes.io/name=minio -o jsonpath='{.items[0].metadata.name}')
echo "$MINIO_POD"

# Setup alias
kubectl exec -n minio "$MINIO_POD" -- \
  mc alias set local http://sequra-minio.minio.svc.cluster.local:9000 minioadmin change-me-minio-password

# List buckets
kubectl exec -n minio "$MINIO_POD" -- mc ls local/

# Browse data lake raw
kubectl -n minio exec "$(kubectl -n minio get pod -l app.kubernetes.io/name=minio -o jsonpath='{.items[0].metadata.name}')" -- \
  mc ls --recursive local/data-lake-raw/banking/demo

```

**Expected structure:**
```text
[2026-03-15] data-lake-analytics/
[2026-03-15] data-lake-processed/
[2026-03-15] data-lake-raw/

[2026-03-16 08:20:37 UTC]  11KiB STANDARD bank_customers/2026_03_16_17736492341612026_03_16
[2026-03-16 08:20:37 UTC] 135KiB STANDARD card_transactions/2026_03_16_17736492341612026_03_16
```

### 7.4 Verify Data Content

```bash
# Inspect a sample file
kubectl exec -n minio sequra-minio-xxxxxxxxxx-xxxxx -- \
  mc cat local/data-lake-raw/banking/demo/bank_customers/2026_03_15_*/$(kubectl exec -n minio sequra-minio-xxxxxxxxxx-xxxxx -- mc ls local/data-lake-raw/banking/demo/bank_customers/2026_03_15_*/ | head -1 | awk '{print $5}') | head -20
```

**Expected format (Airbyte JSONL):**
```json
{"_airbyte_ab_id":"...","_airbyte_extracted_at":...,"_airbyte_data":{"customer_id":1,"full_name":"Juan Pérez","email":"juan.perez@example.com","country_code":"ES","created_at":"..."}}
{"_airbyte_ab_id":"...","_airbyte_extracted_at":...,"_airbyte_data":{"customer_id":2,"full_name":"María García","email":"maria.garcia@example.com","country_code":"ES","created_at":"..."}}
```

### 7.5 Network Security Validation

```bash
make validate-network
```

**Expected output:**
```text
Running positive connectivity check from namespace airbyte...
sequra-postgres-postgresql.data-source.svc.cluster.local (10.96.205.174:5432) open
✓ airbyte → postgres:5432 connection allowed

Running negative connectivity check from namespace netcheck-debug...
nc: sequra-postgres-postgresql.data-source.svc.cluster.local (10.96.205.174:5432): Connection timed out
✓ external namespace → postgres:5432 connection blocked (correct)
```
