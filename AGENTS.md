## Project Skills

This repository includes project-local skills under `.agents/skills`.

### Available skills

- `terraform-style-guide`: Use when writing or reviewing Terraform HCL so files, interfaces, and naming stay aligned with HashiCorp conventions.
- `terraform-test`: Use when adding or maintaining `.tftest.hcl` coverage for this project.
- `refactor-module`: Use when changing module boundaries or extracting logic from the root Terraform project into reusable modules.
- `terraform-search-import`: Use when importing pre-existing infrastructure into Terraform state.
- `terraform-stacks`: Use only if the user explicitly asks to introduce Terraform Stacks.
- `azure-verified-modules`: Installed for reference, but not applicable unless this repo adds Azure infrastructure.
- `new-terraform-provider`: Installed for reference, but not applicable unless this repo starts developing a Terraform provider.
- `run-acceptance-tests`: Installed for reference, but not applicable unless this repo starts developing a Terraform provider.
- `provider-actions`: Installed for reference, but not applicable unless this repo starts developing a Terraform provider.
- `provider-resources`: Installed for reference, but not applicable unless this repo starts developing a Terraform provider.

### Default guidance for this repo

- Prefer `terraform-style-guide`, `terraform-test`, and `refactor-module` for normal Terraform work in this repository.
- Do not introduce Terraform Stacks unless the user asks for that architecture explicitly.
- Do not apply Azure- or provider-development-oriented skills to this repo unless the scope changes.
