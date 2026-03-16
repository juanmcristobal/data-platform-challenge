# Airbyte Pipelines (Pipeline as Code)

This directory is a Terragrunt entrypoint for Airbyte `source -> destination -> connection` definitions, separate from `infra/services`.

## Layout

- `terragrunt.hcl`: entrypoint with global Airbyte API/workspace inputs
- `pipelines/*.yaml`: one file per pipeline
- `pipelines/examples/pipeline-template.yaml`: template for new pipelines
- `../modules/airbyte-pipelines`: reusable module that loads YAML and creates source/destination/connection

## Run

1. Ensure platform services are applied:
   - `make services-apply-core`
   - `make services-apply-storage`
2. Port-forward Airbyte API:
   - `make port-forward-airbyte`
3. In another terminal:
   - `terragrunt --working-dir=pipelines/airbyte init`
   - `terragrunt --working-dir=pipelines/airbyte plan`
   - `terragrunt --working-dir=pipelines/airbyte apply`

## Scaling Pattern

Add one new YAML file under `pipelines/airbyte/pipelines/` per pipeline.
Terraform loads all files automatically and provisions them with `for_each`.

## Secrets

### Current demo

Credentials are stored directly in each pipeline YAML file with `CHANGE_ME` / `change-me-*`
placeholders. This is acceptable for a local Kind cluster; **never** commit real secrets.

### Production strategy

```
AWS Secrets Manager
        ↓  (synced by)
External Secrets Operator
        ↓  (creates)
Kubernetes Secrets
        ↓  (read by)
Terragrunt get_env() / CI/CD variables
        ↓  (passed to)
Terraform provider / pipeline module
```

1. **Store** credentials in AWS Secrets Manager under a path convention:
   `sequra/data-platform/<team>/<pipeline-key>/{pg_password,s3_secret_key}`

2. **Sync** to Kubernetes Secrets via External Secrets Operator (ESO), which
   runs in the cluster and keeps secrets in sync automatically.

3. **Inject** into Terragrunt at plan/apply time:
   ```hcl
   # terragrunt.hcl
   inputs = {
     pg_password   = get_env("PG_AIRBYTE_PASSWORD")
     s3_secret_key = get_env("S3_SECRET_KEY")
   }
   ```
   CI/CD pipelines (GitHub Actions, GitLab CI) expose these from the secret store.

4. **Alternative (SOPS + age)**: encrypt YAML files at rest in the repo using
   [SOPS](https://github.com/getsops/sops) with `age` keys. Decrypt at apply time
   in CI/CD. Good for GitOps workflows with Flux/ArgoCD.
