# Copilot instructions for this repository

This repository is Terraform for Azure platform and application landing zones used for demos, labs, and POCs. It is not production infrastructure.

## Commands

Run Terraform commands from the module folder you are changing, not from the repository root.

```powershell
.\setSubscription.ps1
cd Networking
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Common checks:

```powershell
terraform fmt -check -recursive
cd <module-folder>
terraform init -backend=false
terraform validate
```

There is no dedicated test suite in this repo. Treat module-scoped `terraform validate` as the single-module check. Use `terraform plan` only when Azure auth, subscription, and prerequisite state are available.

## Architecture

The repo uses a two-tier landing-zone model:

- `Networking/` is the platform landing zone. It deploys Azure Virtual WAN, virtual hubs, shared spoke VNets, a test VM, Key Vault, Log Analytics, and optional Azure Firewall, Private DNS Resolver, and a second region.
- Application landing zones live in root-level folders such as `Foundry-byoVnet/`, `Foundry-managedVnet/`, `ContainerApps-byoVnet/`, and `Fabric-private/`. Each creates its own spoke VNet and connects to the platform vHub.
- Application modules read platform outputs with `data "terraform_remote_state" "networking"` from `../Networking/terraform.tfstate`. Deploy `Networking/` first.
- Private networking workloads generally require `add_private_dns00 = true` in `Networking/terraform.tfvars`. Existing app modules enforce this with Terraform `check` blocks.
- `Networking/modules/region-hub/` is an internal child module used by the platform layer to avoid duplicating per-region hub, firewall, DNS, Bastion, and VM resources.

Destroy application landing zones before destroying `Networking/`. Foundry modules require purging soft-deleted AI Foundry resources before the platform subnet can be removed. Fabric has its own capacity, workspace, SQL, and Key Vault cleanup notes in `Fabric-private/README.md`.

## Repository conventions

- Terraform state is local by default. `config.tf` files include commented Azure Storage backend blocks; do not assume remote state is configured.
- Providers are pinned per module. `Networking/` accepts broader AzureRM/AzAPI 4.x/2.x ranges, while application modules typically pin `azurerm ~> 4.26.0`, `azapi ~> 2.3.0`, and `random ~> 3.5`.
- The AzureRM provider sets `prevent_deletion_if_contains_resources = false` for lab cleanup. Do not copy that into production guidance without calling out the risk.
- Most app modules name resources with `{base-name}-{azure_region_0_abbr}-{random_string.unique.result}`. The platform uses `local.suffix = random_string.unique.id`.
- Common tags are defined in `locals.tf` and applied to taggable resources:
  `environment = "non-prod"`, `managed_by = "terraform"`, `project = "azure-infra-poc"`.
- Each new application landing zone gets the next free `/20` block from `docs/ip-addressing.md`. Defaults are hardcoded in module variables, and subnets must stay inside the assigned block.
- New application landing zones should follow `docs/adding-application-landing-zone.md`: root-level workload folder, `config.tf`, `locals.tf`, `main.tf`, `variables.tf`, `outputs.tf`, `README.md`, remote state from `../Networking/terraform.tfstate`, README update, and module-specific cleanup notes.
- Private DNS outputs from `Networking/outputs.tf` are null-safe when DNS is disabled. App modules should check required outputs before creating private endpoints or DNS policy links.
- `ContainerApps-byoVnet` has three `app_mode` values: `none`, `hello-world`, and `mcp-toolbox`. The `mcp-toolbox` mode uses `terraform_data` with a PowerShell `local-exec` to clone, build, and push an image via `az acr build`.
- `Fabric-private` gates resources with `local.deploy_inbound` and `local.deploy_outbound` from `network_mode`. Managed private endpoints are created pending and then approved through AzAPI resource actions filtered by PE resource ID.

## Documentation sources to keep in sync

- Root `README.md` owns the landing-zone table, prerequisites, deploy order, destroy order, and high-level disclaimer.
- `Networking/README.md` owns the platform-to-application output contract and vWAN/private DNS/firewall behavior.
- `docs/ip-addressing.md` is the IP address authority.
- `docs/adding-application-landing-zone.md` is the template for new application landing zones.
- Each module README owns module-specific prerequisites, variables, outputs, and cleanup steps.
