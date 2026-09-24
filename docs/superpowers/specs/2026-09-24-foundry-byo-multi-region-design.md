# Foundry BYO VNet multi-region

**Date:** 2026-09-24  
**Status:** Draft, pending user review

## Purpose

This is package 3 of the feature roadmap in `docs/superpowers/specs/2026-07-23-feature-roadmap-design.md`. It lets `Foundry-byoVnet/` deploy a second, independent Foundry stack in Networking region 1.

Region 0 is always deployed. Region 1 is deployed only when the module sets `deploy_region1 = true` and Networking reports `alz_regions.region1.enabled = true`.

This package also sets the regional composition pattern that packages 4, 6, and 7 will reuse, and it publishes the `foundry_regions` output that package 5 (AI Gateway) will consume.

## Decisions

| Topic | Decision |
|---|---|
| Structure | Move every regional resource into a child module, `Foundry-byoVnet/modules/foundry-region/`, called once per selected region with `for_each` |
| Address variables | Replace the three address variables with one map variable, `regional_networks`, keyed by `region0` and `region1` |
| Outputs | Replace all current scalar outputs with one `foundry_regions` map. No compatibility aliases |
| Shared settings | Both regions use the same model, SKU, and `deploy_agent_data_services` values |
| Cross-region DNS | Out of scope. Each regional stack resolves only through its own region's Private DNS. Package 5 owns cross-region reachability |
| Prerequisite failures | Enforced with variable `validation` blocks, which fail `terraform plan`. `check` blocks only warn |
| Upgrade path | Breaking. Existing deployments must be destroyed before adopting this version. No `moved` blocks |

## Scope

In scope:

- `Foundry-byoVnet/` root and a new `Foundry-byoVnet/modules/foundry-region/` child module
- `Foundry-byoVnet/README.md` and `Foundry-byoVnet/terraform.tfvars.example`
- `docs/ip-addressing.md`, `Networking/README.md`, and `.github/copilot-instructions.md` where they describe how application landing zones consume `alz_regions`

Out of scope:

- Cross-region private endpoints, cross-region DNS, and any change to Networking Private DNS
- Shared agent state, synchronized projects, automatic failover, and traffic routing
- Per-region model, SKU, or data-service overrides
- Every other application landing zone, including `Foundry-managedVnet/` (package 4)

## Architecture

### Root module

The root keeps the pieces that are shared by every region:

- `config.tf`, unchanged
- `data.terraform_remote_state.networking`
- `random_string.unique`, one suffix shared by both regions
- Input variables, region selection, and the `foundry_regions` output

Region selection:

```hcl
locals {
  alz_regions = data.terraform_remote_state.networking.outputs.alz_regions

  selected_regions = {
    for key, region in local.alz_regions : key => region
    if key == "region0" || (key == "region1" && var.deploy_region1 && region.enabled)
  }
}

module "foundry_region" {
  for_each = local.selected_regions
  source   = "./modules/foundry-region"
  # ...
}
```

The remote state is known during planning, so the `for_each` keys are known and the plan shows exactly which regions will deploy.

### Child module

`modules/foundry-region/` owns every resource the root module creates today, except `random_string.unique` and the remote state:

- Resource group
- Spoke VNet, Foundry delegated subnet, private-endpoint subnet, both NSGs and their associations
- vHub connection, VNet DNS servers, and DNS resolver policy link
- Foundry account, `time_sleep.wait_foundry_account`, model deployment, and Foundry private endpoint
- Foundry project, `time_sleep.wait_project_identities`, Application Insights, and its project connection
- The optional agent data-service bundle, gated by `deploy_agent_data_services` exactly as today
- Role assignments, `time_sleep.wait_rbac`, and the project capability host
- All diagnostic settings

The child keeps the current file split: `main.tf`, `networking.tf`, `foundry.tf`, `project.tf`, `rbac.tf`, `storage.tf`, `cosmosdb.tf`, `aisearch.tf`, `diagnostics.tf`, `locals.tf`, `variables.tf`, and `outputs.tf`. It adds a `terraform` block declaring `azure/azapi`, `hashicorp/azurerm`, and `hashicorp/time` sources without version constraints. The root `config.tf` remains the only place that pins versions.

Every reference to `local.platform_region0` becomes a reference to the child's `platform` input. Dependency ordering, wait durations, the sequential private-endpoint chain, and the `count` gating move unchanged.

### Child module inputs

| Input | Type | Source |
|---|---|---|
| `region_key` | `string` | `each.key` |
| `platform` | object | `each.value`, the matching `alz_regions` entry |
| `network` | object | `var.regional_networks[each.key]` |
| `name_suffix` | `string` | `random_string.unique.result` |
| `log_analytics_workspace_id` | `string` | Networking remote state |
| `common_tags` | `map(string)` | Root `locals.tf` |
| Name, model, SKU, and data-service settings | as today | Root variables, passed through unchanged |

The child declares its `platform` input with only the `alz_regions` fields it reads: `region_name`, `region_abbr`, `resource_group_location`, `vhub_id`, `firewall_enabled`, `dns_server_ip`, `dns_resolver_policy_id`, and `private_dns_zone_ids`.

## Variables

### New: `deploy_region1`

A bool with a default of `false`.

```hcl
validation {
  condition     = !var.deploy_region1 || data.terraform_remote_state.networking.outputs.alz_regions.region1.enabled
  error_message = "deploy_region1 = true requires Networking region 1. Apply Networking with create_vhub01 = true and add_private_dns01 = true, then plan this module again."
}
```

A validation rule may reference a data source when running Terraform 1.9 or later. The module already requires 1.11.

### New: `regional_networks`

Replaces `ai_vnet_address_space`, `ai_foundry_subnet_address`, and `private_endpoint_subnet_address`.

```hcl
variable "regional_networks" {
  type = map(object({
    vnet_address_space              = list(string)
    foundry_subnet_address          = list(string)
    private_endpoint_subnet_address = list(string)
  }))
  default = {
    region0 = {
      vnet_address_space              = ["172.20.32.0/20"]
      foundry_subnet_address          = ["172.20.32.0/26"]
      private_endpoint_subnet_address = ["172.20.33.0/24"]
    }
    region1 = {
      vnet_address_space              = ["172.21.32.0/20"]
      foundry_subnet_address          = ["172.21.32.0/26"]
      private_endpoint_subnet_address = ["172.21.33.0/24"]
    }
  }
}
```

Validation rules:

- The map must contain `region0`.
- The map must contain `region1` when `deploy_region1 = true`.
- Keys other than `region0` and `region1` are rejected.

Overriding one region means supplying the whole map. The region 1 defaults use the Foundry-byoVnet block already reserved in `docs/ip-addressing.md`.

### Unchanged

`resource_group_name_ai00`, `ai_vnet_name`, `ai_foundry_subnet_name`, `private_endpoint_subnet_name`, the five `gpt_model_*` variables, `ai_search_sku`, `foundry_sku`, and `deploy_agent_data_services` keep their names and defaults. They apply to every deployed region.

## Naming

Names keep the shared four-digit suffix. Names that must be globally unique gain the region abbreviation so that the two regions cannot collide.

| Resource | Current name | New name |
|---|---|---|
| Resource group | `{rg}-{abbr}-{suffix}` | unchanged |
| VNet, subnets, NSGs | include `{abbr}` | unchanged |
| vHub connection | `vhub00-to-{vnet}-{suffix}` | `vhub{nn}-to-{vnet}-{suffix}`, where `nn` is `00` for region 0 and `01` for region 1 |
| Foundry account and custom subdomain | `aifoundry{suffix}` | `aifoundry{abbr}{suffix}` |
| Storage account | `aifoundry{suffix}storage00` | `aifoundry{abbr}{suffix}st` |
| Cosmos DB account | `aifoundry{suffix}cosmosdb` | `aifoundry{abbr}{suffix}cosmosdb` |
| AI Search service | `aifoundry{suffix}search` | `aifoundry{abbr}{suffix}search` |
| Application Insights | `appinsights-foundry-{suffix}` | `appinsights-foundry-{abbr}-{suffix}` |

Private endpoint, connection, and DNS zone group names derive from the account names and follow automatically. The project, model deployment, capability host, and diagnostic setting names are scoped to their parent resource and stay unchanged. Role assignment names use `uuidv5` over the project name and principal ID, so they are already unique per region.

The storage account name is limited to 24 lowercase letters and digits. The new pattern is 15 characters plus the abbreviation, so the child validates that `platform.region_abbr` matches `^[a-z0-9]{1,9}$`.

## Output

`foundry_regions` replaces all six current outputs. It is a map keyed by the regions actually deployed, so region 1 is absent unless it was selected.

| Field | Type | Value |
|---|---|---|
| `region_name` | `string` | Azure region name from `alz_regions` |
| `region_abbr` | `string` | Region abbreviation from `alz_regions` |
| `resource_group_id` | `string` | Regional resource group ID |
| `foundry_id` | `string` | Foundry account ID |
| `foundry_endpoint` | `string` | Foundry account `properties.endpoint`, exported through `response_export_values` |
| `project_id` | `string` | Foundry project ID |
| `model_deployment_names` | `list(string)` | Model deployment names in the account |
| `storage_account_id` | `string` or `null` | Null when data services are disabled |
| `cosmosdb_account_id` | `string` or `null` | Null when data services are disabled |
| `ai_search_id` | `string` or `null` | Null when data services are disabled |

The root builds the map with a `for` expression over `module.foundry_region`. Package 4 must publish the same fields, excluding the three data-service IDs, which only apply to the BYO module. Package 5 detects region 1 by key presence.

## Error handling

All prerequisite failures stop `terraform plan` with a specific message.

| Condition | Where | Message names |
|---|---|---|
| `deploy_region1 = true` and Networking region 1 is disabled | Root `deploy_region1` validation | `create_vhub01` and `add_private_dns01` |
| `regional_networks` is missing a selected region or has an unknown key | Root `regional_networks` validation | The missing or unknown key |
| A selected region has a null `vhub_id` | Child `platform` validation | The region key and the matching Networking `create_vhub` variable |
| A selected region has a null `dns_server_ip` or `dns_resolver_policy_id` | Child `platform` validation | The region key and the matching Networking `add_private_dns` variable |
| A selected region has a null zone ID for `cognitiveservices`, `services_ai`, or `openai` | Child `platform` validation | The region key and the missing zone key |
| Data services are enabled and a selected region has a null `blob`, `documents`, or `search` zone ID | Child `platform` validation, which also reads `deploy_agent_data_services` | The region key and the missing zone key |
| `platform.region_abbr` is not 1 to 9 lowercase letters or digits | Child `platform` validation | The region key and the abbreviation |

The root `check "dns_prerequisite"` block is removed. Its region 0 condition now lives in the child validation and applies to both regions as a hard failure instead of a warning.

## Upgrade and cleanup

Every resource address changes from the root to `module.foundry_region["region0"]`, and several account names change. The module README will state that an existing deployment must be destroyed, including the Foundry purge, before this version is applied.

Cleanup for two regions follows the existing single-region steps once per region:

1. `terraform destroy` in `Foundry-byoVnet/`
2. Purge the soft-deleted Foundry account in each deployed region
3. Wait about 10 minutes after each purge before destroying Networking, so the delegated subnets release their service association links

The orphaned service association link guidance applies to each region's delegated subnet.

## Cost

Region 1 roughly doubles the module's cost. With data services enabled, each region adds an AI Search service at the configured SKU, a Cosmos DB account, a Storage account, three private endpoints, and the Foundry private endpoint. The default remains `deploy_region1 = false`.

## Prerequisites for region 1

- Networking applied with `create_vhub01 = true` and `add_private_dns01 = true`
- The region 1 Azure region supports Foundry Agent Service with BYO VNet injection
- The region 1 subscription has quota for the configured model and SKU. `GlobalStandard` is the default
- The region 1 Networking test VM or Bastion is used to test the region 1 private endpoint, because region 0 cannot resolve it

## Validation

Static checks from `Foundry-byoVnet/`:

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Foundry-byoVnet')
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

Authenticated plan cases, each run against Networking state:

| Networking | `deploy_region1` | `deploy_agent_data_services` | Expected |
|---|---|---|---|
| Region 0 only | `false` | `true` | Only `module.foundry_region["region0"]`. The same resource types and count as the current module |
| Region 0 only | `false` | `false` | Only region 0, with 23 fewer resources than the previous case |
| Region 0 only | `true` | either | Plan fails with the `deploy_region1` validation message |
| Two regions | `false` | `true` | Only region 0 |
| Two regions | `true` | `true` | Both regions, each with the single-region resource count |
| Two regions | `true` | `false` | Both regions, each with 23 fewer resources |

Deployment cases:

- One region and two regions with data services enabled
- One region and two regions with data services disabled
- In each deployed region, `caphostproj` reaches a succeeded provisioning state
- In each deployed region, an agent created in the project runs a conversation through the private endpoint from that region's test VM
- `foundry_regions` contains one entry per deployed region with non-null account, project, and endpoint values

## Documentation updates

- `Foundry-byoVnet/README.md`: multi-region section, `deploy_region1` and `regional_networks` variables, the `foundry_regions` output table, the destroy-first upgrade notice, per-region cleanup, region 1 prerequisites, and the cross-region DNS limitation
- `Foundry-byoVnet/terraform.tfvars.example`: replace the three address variables with `regional_networks` and add a commented `deploy_region1`
- `docs/ip-addressing.md`: mark region 1 block 2 as assigned to Foundry-byoVnet with its two subnets
- `Networking/README.md`: note that Foundry-byoVnet consumes `alz_regions.region1` when `deploy_region1 = true`
- `.github/copilot-instructions.md`: describe the regional child-module pattern, so the `local.platform_region0` guidance no longer reads as universal

The root `README.md` deploy and destroy order does not change.

## Hand-off to package 5

Region 1 Foundry private endpoints register only in region 1 Private DNS zones. A client in region 0, including a future region 0 API Management instance, cannot resolve them privately. Package 5 must design cross-region reachability. The expected approach is a region 0 private endpoint to each region 1 Foundry account, registered in region 0 zones.

## References

- [Foundry high availability and resiliency](https://learn.microsoft.com/en-us/azure/foundry/how-to/high-availability-resiliency)
- [Foundry Agent Service regions and limits](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/limits-quotas-regions)
- [Foundry Agent Service virtual networks](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/virtual-networks)
