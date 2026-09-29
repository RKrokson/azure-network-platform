# Platform Landing Zone — Networking

This is the shared networking foundation that all application landing zones in this repo depend on. It deploys an Azure Virtual WAN environment for demos and labs (not production).

This can be used for demoing or testing network platform capabilities. It can also be used as a secure networking foundation for optional application landing zones.

## What Gets Deployed

**Base deployment:** Virtual WAN, virtual hub, spoke VNet, and test VM.

**Optionals:** Azure Firewall, Private DNS Resolver, and a second region. All default to `false`. Enable them in your `terraform.tfvars`:

| Toggle              | Enables                                            |
| ------------------- | -------------------------------------------------- |
| `create_vhub01`     | Second region (hub, VNets, VMs)                    |
| `add_firewall00`    | Azure Firewall in region 0                         |
| `add_firewall01`    | Azure Firewall in region 1 (requires vhub01)       |
| `add_private_dns00` | Private DNS Resolver in region 0                   |
| `add_private_dns01` | Private DNS Resolver in region 1 (requires vhub01) |

See `variables.tf` for the full configuration options (VNet ranges, VM sizes, region names, etc).

## Quick Start

```sh
cd Networking
terraform init && terraform apply
```

If this checkout just upgraded to the `alz_regions` contract, run `terraform apply` here before planning any application landing zone so the local state contains `alz_regions`.

**Optional:** Create a `terraform.tfvars` to enable Firewall and Private DNS. Two examples:

- `terraform.tfvars.example` — Just the toggles
- `terraform.tfvars.advanced.example` — Toggles + custom IP ranges

Rename either to `terraform.tfvars`, set values to `true`, then `terraform plan` and `terraform apply`.

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- Terraform >= 1.11
- `ARM_SUBSCRIPTION_ID` environment variable set (see `setSubscription.ps1` in the repo root)
- Sufficient Azure quota in your target region(s)

## Downstream Dependencies

Application landing zone modules (`Foundry-byoVnet/`, `Foundry-managedVnet/`, `ContainerApps-byoVnet/`, and `Fabric-private/`) consume `alz_regions.region0` via `terraform_remote_state` (local backend, reads `./terraform.tfstate`). Each module creates its own spoke VNet and subnets. If a workload needs private DNS resolution, set `add_private_dns00 = true`.

`Foundry-byoVnet/` also consumes `alz_regions.region1` when its `deploy_region1 = true`. That requires `create_vhub01 = true` and `add_private_dns01 = true` here.

## Outputs — Platform-to-ALZ Contract

Application landing zones consume these outputs via `terraform_remote_state`. See the full list in `outputs.tf`.

| Output                                   | Purpose                                                                          |
| ---------------------------------------- | -------------------------------------------------------------------------------- |
| `alz_regions`                            | Region 0 and optional region 1 resource group, vHub, Firewall, DNS, and Private DNS zone contract |
| `log_analytics_workspace_id`             | Shared Log Analytics workspace used by application diagnostics                   |
| `vm_admin_username`, `vm_admin_password` | Credentials for the platform test VMs                                            |

`alz_regions.<region>` is an object with these fields:

| Field                      | Type / nullable shape                         | Behavior |
| -------------------------- | ---------------------------------------------- | -------- |
| `enabled`                  | `bool`                                          | `true` for region 0; matches `create_vhub01` for region 1. |
| `region_name`              | `string`                                        | Azure region name for the deployed or configured region. |
| `region_abbr`              | `string`                                        | Short region label used by downstream naming and routing. |
| `resource_group_id`        | `string \| null`                               | Resource group ID for the region, or `null` when the region is absent. |
| `resource_group_name`      | `string \| null`                               | Resource group name for the region, or `null` when the region is absent. |
| `resource_group_location`  | `string \| null`                               | Resource group location for the region, or `null` when the region is absent. |
| `vhub_id`                  | `string \| null`                               | Virtual hub ID for the region, or `null` when the region is absent. |
| `firewall_enabled`         | `bool`                                          | Mirrors the region's Firewall toggle; `false` when Firewall is not enabled. |
| `dns_server_ip`            | `string \| null`                               | `null` when Private DNS is disabled for that region. With Private DNS enabled, this is the Azure Firewall private IP when that region's Firewall is enabled; otherwise it is the Private DNS Resolver inbound endpoint IP. |
| `dns_resolver_policy_id`    | `string \| null`                               | DNS Resolver policy ID for the region, or `null` when the region or DNS resources are absent. |
| `dns_vnet_id`              | `string \| null`                               | DNS VNet ID for the region, or `null` when the region or DNS resources are absent. |
| `private_dns_zone_ids`     | `map(string \| null)`                           | Keeps the known zone-key map shape; values are `null` when the region or DNS resources are absent. |

`alz_regions.region0` is always enabled. `alz_regions.region1.enabled` matches `create_vhub01`; its resource-derived values are null when region 1 is disabled. Application landing zones select their own deployment regions and must not assume that Networking region 1 automatically enables a second workload region.

### Inspect a deployed region

Run this example from `Networking/` after applying the current Networking configuration so the configured state contains the `alz_regions` output. It displays both regions without requiring any edits:

```powershell
$alz = terraform output -json alz_regions | ConvertFrom-Json

foreach ($regionName in 'region0', 'region1') {
  $region = $alz.$regionName
  $regionLabel = $regionName -replace 'region', 'Region '

  Write-Host "`n=== $regionLabel ==="
  $region | Format-List *

  Write-Host "--- Private DNS zone IDs ---"
  $region.private_dns_zone_ids | Format-List *
}
```

For each region, the first list shows its resource group, vHub, Firewall, and DNS fields. The second list expands its Private DNS zone names and values. A disabled region 1 remains visible with `enabled = false` and null resource-derived values.

## CIDR Allocation

Each region uses a `172.2x.0.0/16` supernet split into `/20` blocks, and the vHub prefixes use a separate `172.30.x.x` range. The authoritative per-ALZ allocations live in [docs/ip-addressing.md](../docs/ip-addressing.md); update that file instead of duplicating the blocks here.

## Module Structure

For contributors: Networking uses an internal `modules/region-hub/` child module to avoid duplicating per-region blocks. The root module calls it twice (region 0 always, region 1 conditional on `create_vhub01`).

**This doesn't change how you use it.** Variables, outputs, and tfvars work the same. The child module is a code organization detail:

```
Networking/
├── main.tf, vwan.tf, credentials.tf, variables.tf, outputs.tf
└── modules/region-hub/
    ├── main.tf (per-region hub, VNet, firewall, DNS, compute)
    └── variables.tf, outputs.tf
```

## Notes

**VM credentials:** Terraform generates one password shared by the regional test VMs. The username includes the deployment's random numeric suffix. Retrieve both values explicitly when connecting through Bastion:

```sh
terraform output -raw vm_admin_username
terraform output -raw vm_admin_password
```

The password is stored in the local Terraform state. State files are excluded from Git and should be deleted with the lab.

**Firewall:** Deployed with Routing Intent enabled. Default policy is allow-all. Update rules as needed.

**Bastion:** Defaults to Standard SKU with native client support (`tunneling_enabled`) enabled. This lets you use `az network bastion` CLI commands for RDP/SSH instead of the portal. IP-based connections (`ip_connect_enabled`) were removed because they conflict with vWAN routing intent; use resource ID instead.

Connect via native RDP client:

```sh
az network bastion rdp \
  --name <bastion-name> --resource-group <rg-name> \
  --target-resource-id <vm-resource-id>
```

Example resource ID: `/subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.Compute/virtualMachines/<vm-name>`

Connect via native SSH client:

```sh
az network bastion ssh \
  --name <bastion-name> --resource-group <rg-name> \
  --target-resource-id <vm-resource-id> \
  --auth-type password --username yourAdminUser
```

Cross-VNet Bastion access is not supported in this vWAN topology.

**Private DNS:** Uses [Azure Verified Module](https://azure.github.io/Azure-Verified-Modules/indexes/terraform/tf-pattern-modules/) — deploys all common `privatelink.*` zones except `privatelink.{dnsPrefix}.database.windows.net` (create manually if needed). See [exceptions list](https://github.com/Azure/terraform-azurerm-avm-ptn-network-private-link-private-dns-zones?tab=readme-ov-file#-private_link_private_dns_zones).

> [!NOTE]
> Terraform may report that the AzAPI `retry.multiplier` and `retry.randomization_factor` attributes are deprecated. These values come from the nested Private DNS Zone AVM used by the upstream pattern, not from this repository's Terraform configuration. The warning does not affect deployment and requires no Azure resource or state cleanup. Do not edit files under `.terraform`; the warning will be removed when the upstream AVM updates its retry schema.

**Regions:** Defaults are Sweden Central (region 0) and Central US (region 1). Override in `terraform.tfvars` — update both the full name and abbreviation.

## Examples

Common configurations. See [terraform.tfvars.example](./terraform.tfvars.example) and [terraform.tfvars.advanced.example](./terraform.tfvars.advanced.example) for ready-to-use templates. Rename one to `terraform.tfvars` and set the toggles:

### Single Region + DNS Resolver

```hcl
create_vhub01     = false
add_firewall00    = false
add_private_dns00 = true
```

![Diagram](./Diagrams/1reg-hub-dns-v1.2.png)

### Single Region + Firewall + DNS

```hcl
create_vhub01     = false
add_firewall00    = true
add_private_dns00 = true
```

![Diagram](./Diagrams/1reg-shub-dns-v1.2.png)

### Two Regions + Firewall + DNS

```hcl
create_vhub01     = true
add_firewall00    = true
add_firewall01    = true
add_private_dns00 = true
add_private_dns01 = true
```

![Diagram](./Diagrams/2reg-shub-dns-v1.2.png)

See [terraform.tfvars.advanced.example](./terraform.tfvars.advanced.example) to customize IP ranges, regions, or VM sizes.
