# Data Platform Challenge

[![Terraform](https://img.shields.io/badge/Terraform-1.x-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Terragrunt](https://img.shields.io/badge/Terragrunt-IaC-005F73)](https://terragrunt.gruntwork.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-kind-326CE5?logo=kubernetes&logoColor=white)](https://kind.sigs.k8s.io/)
[![Helm](https://img.shields.io/badge/Helm-3-0F1689?logo=helm&logoColor=white)](https://helm.sh/)
[![Airbyte](https://img.shields.io/badge/Airbyte-OSS-615EFF)](https://airbyte.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Source-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![MinIO](https://img.shields.io/badge/MinIO-S3%20Compatible-C72E49?logo=minio&logoColor=white)](https://min.io/)
[![Cilium](https://img.shields.io/badge/Cilium-NetworkPolicy-F8C300)](https://cilium.io/)

End-to-end data ingestion platform built for the Data Platform Engineer Technical Challenge.

This repository provisions:
- Kubernetes platform services (Airbyte, PostgreSQL source, MinIO destination, namespaces, network controls).
- Reusable Airbyte pipelines as code (YAML-driven, scalable to 30+ pipelines).

## Tech Stack
- Infrastructure as Code: Terraform + Terragrunt
- Runtime: kind (Kubernetes) + Helm
- Data Ingestion: Airbyte OSS
- Source DB: PostgreSQL
- Data Lake Destination: MinIO (S3-compatible), with AWS S3 path implemented in module design
- Network Security: Cilium + Kubernetes NetworkPolicy

## Repository Structure
- `infra/` platform infrastructure and reusable Terraform modules
- `pipelines/` Airbyte pipeline-as-code root and reusable pipeline module
- `docs/` challenge submission report and installation guide

## Setup and Run
Use the step-by-step guide:
- [Installation Guide](docs/installation-guide.md)

## Documentation
- [Installation Guide](docs/installation-guide.md)
- [Challenge Submission Report](docs/challenge-submission-report.md)

## Important Execution Note
For `infra/services/*`, the supported workflow is **Terragrunt** (not isolated `terraform apply` per service root).
Terragrunt is required here to resolve inter-service dependencies and generated provider configuration correctly.
