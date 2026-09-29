# Copilot instructions for this repository

This repository contains Terraform for Azure platform and application landing zones used for demos, labs, and POCs. It is not production infrastructure.

## Commands

All active root modules require Terraform >= 1.11. Run Terraform from the module folder you are changing, not from the repository root.

```powershell
.\setSubscription.ps1
# setSubscription.ps1 uses setx; open a new shell before relying on ARM_SUBSCRIPTION_ID.

Set-Location .\Networking
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Use this as the smallest module-scoped check, equivalent to running a single test in this repository:

```powershell
Set-Location .\Foundry-byoVnet # replace with the module being changed
terraform init -backend=false
terraform fmt -check
terraform validate
```

Run the repository-wide format check from the root:

```powershell
terraform fmt -check -recursive
```

There are no `.tftest.hcl` files, standalone test suite, repository TFLint configuration, or CI workflows. Do not invent `terraform test`, TFLint, or CI commands. Use `terraform plan` only when Azure authentication, subscription context, and prerequisite state are available.

## Architecture

The repository uses a two-tier landing-zone model:

- `Networking/` is the platform landing zone. It deploys Azure Virtual WAN, a shared Log Analytics workspace, and one or two regional stacks. `Networking/modules/region-hub/` owns each region's vHub, shared spoke, optional Firewall and Private DNS Resolver, Bastion, and test VM. Region 0 is always created; region 1 is gated by `create_vhub01`.
- Root-level application landing zones (`Foundry-byoVnet/`, `Foundry-managedVnet/`, `ContainerApps-byoVnet/`, and `Fabric-private/`) create workload resources and a dedicated spoke VNet connected to the platform vHub.
- Application modules consume `../Networking/terraform.tfstate` through `data "terraform_remote_state" "networking"`. Deploy `Networking/` first. State is local by default, so do not assume a remote backend exists.
- Existing application modules require platform Private DNS. Single-region modules enforce required outputs with Terraform `check` blocks; `Foundry-byoVnet/` uses variable `validation` rules instead. Set `add_private_dns00 = true` before deploying them.
- `Foundry-managedVnet/` still creates a spoke for private endpoints and platform connectivity, but the Foundry agent network itself is Microsoft-managed. Its optional `foundry_mvnet_fw_aoao` path uses PowerShell, Azure CLI, and AzAPI to configure approved outbound access.

Destroy application landing zones before `Networking/`. `Foundry-byoVnet/` requires purging each soft-deleted Foundry resource before its delegated subnet can be removed. `Fabric-private/README.md` owns its capacity, workspace, SQL, and Key Vault cleanup sequence.

## Repository conventions

- Terraform state is local by default. `config.tf` files include commented Azure Storage backend blocks; do not assume remote state is configured.
- Provider constraints intentionally differ by module. `Networking/` accepts AzureRM 4.x and AzAPI 2.x; the Foundry modules pin AzAPI `~> 2.4`; Container Apps and Fabric pin AzAPI `~> 2.3.0`; Fabric also requires `microsoft/fabric ~> 1.9` with preview enabled. Preserve each module's `config.tf` instead of normalizing versions across the repository.
- The AzureRM provider sets `prevent_deletion_if_contains_resources = false` for lab cleanup. Do not present this as a production default.
- Application resources generally use `{base-name}-{region_abbr}-{random_string.unique.result}`. `Foundry-byoVnet/` also puts the region abbreviation in globally unique names, such as `aifoundry{abbr}{suffix}`. The platform uses `local.suffix = random_string.unique.id`.
- Common tags live in `locals.tf` and are applied to taggable resources: `environment = "non-prod"`, `managed_by = "terraform"`, and `project = "azure-infra-poc"`.
- Each application landing zone owns a `/20` block from `docs/ip-addressing.md`. Pick the next free block, keep all default subnets inside it, and update the address authority when adding a landing zone.
- New application landing zones should follow `docs/adding-application-landing-zone.md`: root-level workload folder, `config.tf`, `locals.tf`, `main.tf`, `variables.tf`, `outputs.tf`, `README.md`, remote state from `../Networking/terraform.tfstate`, README update, and module-specific cleanup notes.
- Application spokes use their region's `alz_regions` entry, `local.platform_region0` in single-region modules and the `platform` input in `Foundry-byoVnet/modules/foundry-region/`: vHub connections use `vhub_id`, `internet_security_enabled` follows `firewall_enabled`, private-endpoint subnets use its inverse for `default_outbound_access_enabled`, VNet DNS uses `dns_server_ip`, resolver policy links use `dns_resolver_policy_id`, and private endpoint zone groups use `private_dns_zone_ids`.
- Networking's `alz_regions` entries are null-safe for optional DNS, Firewall, and region-1 resources. Single-region application modules check required values with `check` blocks, which only warn. `Foundry-byoVnet/` uses variable `validation` rules, which fail `terraform plan`.
- `Foundry-byoVnet/` is the multi-region pattern. The root selects `region0` plus `region1` when `deploy_region1 = true` (default `false`) and Networking enables it, then calls `modules/foundry-region/` with `for_each`. The child declares provider sources only, so validate it from the root. It publishes a `foundry_regions` output keyed by region.
- `ContainerApps-byoVnet` supports `app_mode = "none"`, `"hello-world"`, or `"mcp-toolbox"`. The MCP mode uses `terraform_data` with a PowerShell `local-exec` to clone source and run `az acr build`.
- `Fabric-private` decomposes `network_mode` into `local.deploy_inbound` and `local.deploy_outbound`. Its managed private endpoints are approved through AzAPI by matching the target connection to the Fabric MPE resource ID; never approve the first pending connection by position or state alone.
- Some resources cannot be expressed fully through providers. Preserve the error handling, dependency ordering, and read-back checks in `terraform_data`/`local-exec` flows for Foundry managed-network setup and Fabric workspace communication policy.
- Terraform state, `.tfvars`, plan files, and `.terraform/` are intentionally ignored. Do not commit or rewrite local state as part of normal code changes.

## Documentation sources to keep in sync

- Root `README.md` owns the landing-zone table, prerequisites, deploy order, destroy order, and high-level disclaimer.
- `Networking/README.md` owns the platform-to-application output contract and vWAN, Private DNS, and Firewall behavior.
- `docs/ip-addressing.md` is the IP address authority.
- `docs/adding-application-landing-zone.md` is the template for new application landing zones.
- Each module README owns module-specific prerequisites, variables, outputs, and cleanup steps.
