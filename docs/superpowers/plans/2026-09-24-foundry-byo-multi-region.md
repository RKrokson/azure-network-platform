# Foundry BYO VNet multi-region implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let `Foundry-byoVnet/` deploy an independent Foundry stack in region 0 and, when `deploy_region1 = true` and Networking region 1 exists, a second stack in region 1.

**Architecture:** Every regional resource moves into a new child module, `Foundry-byoVnet/modules/foundry-region/`, called with `for_each` over the selected regions. The root keeps remote state, the shared random suffix, region selection, input variables, and a single `foundry_regions` output. Prerequisites are enforced with variable `validation` rules so that `terraform plan` fails with a specific message.

**Tech Stack:** Terraform 1.11 or later, AzureRM `~> 4.26.0`, AzAPI `~> 2.4`, time, random. PowerShell for verification.

**Design:** `docs/superpowers/specs/2026-09-24-foundry-byo-multi-region-design.md`

## Global constraints

- Work on branch `feat/foundry-byo-multi-region` in the worktree `.worktrees/foundry-byo-multi-region`. Never commit to `main`.
- Only these paths change: `Foundry-byoVnet/`, `docs/ip-addressing.md`, `Networking/README.md`, and `.github/copilot-instructions.md`. Do not modify Terraform in `Networking/`, `Foundry-managedVnet/`, `ContainerApps-byoVnet/`, or `Fabric-private/`.
- `Foundry-byoVnet/config.tf` and `Foundry-byoVnet/.terraform.lock.hcl` do not change.
- The child module declares provider `source` values only, with no version constraints, matching `Networking/modules/region-hub/main.tf`. Validate it from the root, never standalone. A standalone `init` pulls the newest AzureRM major version and fails.
- Resource names, types, dependency ordering, wait durations, and `count` gating inside the moved files stay as they are, except for the reference rewrites in Task 2.
- Do not add `moved` blocks or state migration. The upgrade is destroy and redeploy.
- Do not use `check` blocks for prerequisites. They only warn. Use variable `validation`.
- This repository has no `terraform test`, TFLint, or CI. Do not invent them. The harness in Task 1 lives in the system temp folder and is never committed.
- Commit messages follow the existing convention, for example `refactor(foundry-byovnet): ...`. The executing agent adds its own commit trailers.

## Verification commands

Every code task ends with these, run from the module folder:

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Foundry-byoVnet')
terraform init -backend=false -input=false | Out-Null
terraform fmt -check -recursive
terraform validate
```

Expected: `terraform fmt -check -recursive` prints nothing and exits 0. `terraform validate` prints `Success! The configuration is valid.`

Plan-level checks use the harness from Task 1. It requires Azure CLI sign-in and `ARM_SUBSCRIPTION_ID`, because the AzureRM provider authenticates during `plan`. It creates nothing in Azure.

---

### Task 1: Verification harness and baseline

**Files:** none in the repository. Creates `anp-foundry-harness/` under the system temp folder.

**Interfaces:**
- Consumes: the current `Foundry-byoVnet/` module.
- Produces: `Invoke-FoundryHarness.ps1` and `baseline-addresses.txt` in the harness folder. Later tasks call the script with these parameters:
  - `-Region1` makes synthetic Networking report `alz_regions.region1.enabled = true`
  - `-NoRegion1Dns` makes region 1 report null DNS and zone IDs
  - `-PinSuffix` replaces the random suffix with `1234` in the harness copy only, so names are known at plan time
  - `-JsonOut <path>` writes `terraform show -json` of the plan
  - `-TfArgs <string[]>` passes extra arguments to `terraform plan`
  - The script prints `Plan:`, `Error:`, and validation message lines, then `exit=<code>`

- [ ] **Step 1: Create the harness script**

```powershell
$H = Join-Path ([IO.Path]::GetTempPath()) 'anp-foundry-harness'
New-Item -ItemType Directory -Force $H | Out-Null
@'
[CmdletBinding()]
param(
    [string]$ModulePath = (Join-Path (git rev-parse --show-toplevel) 'Foundry-byoVnet'),
    [switch]$Region1,
    [switch]$NoRegion1Dns,
    [switch]$PinSuffix,
    [string]$JsonOut,
    [string[]]$TfArgs = @()
)

# Plans Foundry-byoVnet against a synthetic Networking state. Creates nothing in Azure.
# Requires Azure CLI sign-in and ARM_SUBSCRIPTION_ID, because the AzureRM provider authenticates during plan.
$ErrorActionPreference = 'Stop'
$env:ARM_RESOURCE_PROVIDER_REGISTRATIONS = 'none'
$harness = Join-Path ([IO.Path]::GetTempPath()) 'anp-foundry-harness'
$net = Join-Path $harness 'Networking'
$mod = Join-Path $harness 'Foundry-byoVnet'
New-Item -ItemType Directory -Force $net, $mod | Out-Null

@"
variable "region1_enabled" {
  type    = bool
  default = false
}
variable "region1_dns" {
  type    = bool
  default = true
}
locals {
  sub   = "/subscriptions/00000000-0000-0000-0000-000000000000"
  zones = ["blob", "file", "table", "queue", "vaultcore", "cognitiveservices", "openai", "services_ai", "search", "documents", "acr", "fabric", "sql"]
  region = {
    region0 = { enabled = true, name = "swedencentral", abbr = "swc", rg = "rg-net00-swc-0000", ip = "172.20.16.4", dns = true }
    region1 = { enabled = var.region1_enabled, name = "centralus", abbr = "cus", rg = "rg-net01-cus-0000", ip = "172.21.16.4", dns = var.region1_dns }
  }
}
output "log_analytics_workspace_id" {
  value = "`${local.sub}/resourceGroups/rg-net00-swc-0000/providers/Microsoft.OperationalInsights/workspaces/law00-0000"
}
output "alz_regions" {
  value = { for k, r in local.region : k => {
    enabled                 = r.enabled
    region_name             = r.name
    region_abbr             = r.abbr
    resource_group_id       = r.enabled ? "`${local.sub}/resourceGroups/`${r.rg}" : null
    resource_group_name     = r.enabled ? r.rg : null
    resource_group_location = r.enabled ? r.name : null
    vhub_id                 = r.enabled ? "`${local.sub}/resourceGroups/`${r.rg}/providers/Microsoft.Network/virtualHubs/vhub-`${r.abbr}" : null
    firewall_enabled        = false
    dns_server_ip           = r.enabled && r.dns ? r.ip : null
    dns_resolver_policy_id  = r.enabled && r.dns ? "`${local.sub}/resourceGroups/`${r.rg}/providers/Microsoft.Network/dnsResolverPolicies/policy-`${r.abbr}" : null
    dns_vnet_id             = r.enabled && r.dns ? "`${local.sub}/resourceGroups/`${r.rg}/providers/Microsoft.Network/virtualNetworks/dns-`${r.abbr}" : null
    private_dns_zone_ids    = { for z in local.zones : z => r.enabled && r.dns ? "`${local.sub}/resourceGroups/`${r.rg}/providers/Microsoft.Network/privateDnsZones/`${z}" : null }
  } }
}
"@ | Set-Content (Join-Path $net 'main.tf')

Push-Location $net
try {
    terraform init -input=false -no-color | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Synthetic Networking init failed' }
    terraform apply -auto-approve -input=false -no-color "-var=region1_enabled=$($Region1.IsPresent.ToString().ToLower())" "-var=region1_dns=$((-not $NoRegion1Dns).ToString().ToLower())" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Synthetic Networking apply failed' }
}
finally { Pop-Location }

# Refresh the module copy but keep its .terraform cache
Get-ChildItem $mod -Force | Where-Object { $_.Name -notin '.terraform', 'terraform.tfstate' } | Remove-Item -Recurse -Force
Get-ChildItem $ModulePath -Force | Where-Object { $_.Name -notin '.terraform', 'terraform.tfstate', 'terraform.tfstate.backup', 'terraform.tfvars' } | Copy-Item -Destination $mod -Recurse -Force

if ($PinSuffix) {
    $main = Join-Path $mod 'main.tf'
    (Get-Content $main -Raw) -replace 'name_suffix(\s+)= random_string\.unique\.result', 'name_suffix$1= "1234"' | Set-Content $main -NoNewline
}

Push-Location $mod
try {
    terraform init -input=false -no-color | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Module init failed' }
    $planArgs = @('plan', '-input=false', '-no-color', '-refresh=false') + $TfArgs
    if ($JsonOut) { $planArgs += '-out=harness.tfplan' }
    $output = & terraform @planArgs 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    $output | Where-Object { $_ -match '^(Plan:|Error:|Warning:)' -or $_ -match 'Networking region|regional_networks|deploy_region1|zone IDs|Unknown keys' }
    if ($JsonOut -and $code -eq 0) {
        terraform show -json harness.tfplan | Set-Content $JsonOut
        Remove-Item harness.tfplan
    }
    "exit=$code"
}
finally { Pop-Location }
'@ | Set-Content (Join-Path $H 'Invoke-FoundryHarness.ps1')
```

The inner Terraform config is a PowerShell expandable here-string, so every Terraform `${` is escaped as `` `${ ``. Confirm the escaping survived:

```powershell
Select-String -Path (Join-Path $H 'Invoke-FoundryHarness.ps1') -Pattern 'resourceGroups/`\$\{r.rg\}' -SimpleMatch:$false | Measure-Object | Select-Object -ExpandProperty Count
```

Expected: `5`.

- [ ] **Step 2: Capture baseline counts**

Run from the worktree root:

```powershell
Set-Location (git rev-parse --show-toplevel)
$H = Join-Path ([IO.Path]::GetTempPath()) 'anp-foundry-harness'
& "$H\Invoke-FoundryHarness.ps1"
& "$H\Invoke-FoundryHarness.ps1" -TfArgs '-var=deploy_agent_data_services=false'
```

Expected:

```
Plan: 47 to add, 0 to change, 0 to destroy.
exit=0
Plan: 24 to add, 0 to change, 0 to destroy.
exit=0
```

The 47 is 46 regional resources plus `random_string.unique`. The 24 is 23 regional resources plus `random_string.unique`. If the counts differ, stop: the module on this branch is not the expected starting point.

- [ ] **Step 3: Capture baseline addresses**

```powershell
& "$H\Invoke-FoundryHarness.ps1" -JsonOut "$H\baseline.json"
(Get-Content "$H\baseline.json" -Raw | ConvertFrom-Json).resource_changes | ForEach-Object address |
    Where-Object { $_ -ne 'random_string.unique' } | Sort-Object | Set-Content "$H\baseline-addresses.txt"
(Get-Content "$H\baseline-addresses.txt").Count
```

Expected: `46`.

No commit. Nothing in the repository changed.

---

### Task 2: Move regional resources into a child module

This task is a structural refactor with region 0 only. It also applies the region-aware names and the prerequisite validations, because both live in the child module. Region 1 support comes in Task 3.

**Files:**
- Move: `Foundry-byoVnet/{networking,foundry,project,rbac,storage,cosmosdb,aisearch,diagnostics}.tf` to `Foundry-byoVnet/modules/foundry-region/`
- Create: `Foundry-byoVnet/modules/foundry-region/main.tf`, `locals.tf`, `variables.tf`, `outputs.tf`
- Modify: `Foundry-byoVnet/modules/foundry-region/foundry.tf`
- Replace: `Foundry-byoVnet/main.tf`, `Foundry-byoVnet/locals.tf`, `Foundry-byoVnet/outputs.tf`
- Modify: `Foundry-byoVnet/variables.tf`

**Interfaces:**
- Consumes: the harness and `baseline-addresses.txt` from Task 1.
- Produces:
  - `module.foundry_region`, keyed by `alz_regions` key, source `./modules/foundry-region`
  - Child inputs: `region_key` (string), `platform` (object: `region_name`, `region_abbr`, `resource_group_location`, `vhub_id`, `firewall_enabled`, `dns_server_ip`, `dns_resolver_policy_id`, `private_dns_zone_ids`), `network` (object: `vnet_address_space`, `foundry_subnet_address`, `private_endpoint_subnet_address`, each `list(string)`), `name_suffix`, `log_analytics_workspace_id`, `common_tags`, and the pass-through name, model, SKU, and `deploy_agent_data_services` inputs
  - Child output `foundry_region`: object with `region_name`, `region_abbr`, `resource_group_id`, `foundry_id`, `foundry_endpoint`, `project_id`, `model_deployment_names`, `storage_account_id`, `cosmosdb_account_id`, `ai_search_id`
  - Root output `foundry_regions`: `{ for key, stack in module.foundry_region : key => stack.foundry_region }`
  - Root variable `regional_networks`: `map(object({ vnet_address_space, foundry_subnet_address, private_endpoint_subnet_address }))`
  - Root local `selected_regions`: map of `alz_regions` entries to deploy

- [ ] **Step 1: Move the regional files**

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Foundry-byoVnet')
New-Item -ItemType Directory -Force modules\foundry-region | Out-Null
foreach ($f in 'networking', 'foundry', 'project', 'rbac', 'storage', 'cosmosdb', 'aisearch', 'diagnostics') {
    git mv "$f.tf" "modules/foundry-region/$f.tf"
}
```

- [ ] **Step 2: Rewrite references in the moved files**

The replacements are literal and run in this order. The four `aifoundry` name rules must run before the bare `"aifoundry${var.name_suffix}"` rule.

```powershell
$M = Join-Path (git rev-parse --show-toplevel) 'Foundry-byoVnet\modules\foundry-region'
$map = [ordered]@{
    'data.terraform_remote_state.networking.outputs.log_analytics_workspace_id' = 'var.log_analytics_workspace_id'
    'local.platform_region0'              = 'var.platform'
    'random_string.unique.result'         = 'var.name_suffix'
    'local.common_tags'                   = 'var.common_tags'
    'var.ai_vnet_address_space'           = 'var.network.vnet_address_space'
    'var.ai_foundry_subnet_address'       = 'var.network.foundry_subnet_address'
    'var.private_endpoint_subnet_address' = 'var.network.private_endpoint_subnet_address'
    '"aifoundry${var.name_suffix}storage00"' = '"${local.account_name}st"'
    '"aifoundry${var.name_suffix}cosmosdb"'  = '"${local.account_name}cosmosdb"'
    '"aifoundry${var.name_suffix}search"'    = '"${local.account_name}search"'
    '"aifoundry${var.name_suffix}"'          = 'local.account_name'
    '"appinsights-foundry-${var.name_suffix}"'              = '"appinsights-foundry-${var.platform.region_abbr}-${var.name_suffix}"'
    '"vhub00-to-${var.ai_vnet_name}-${var.name_suffix}"'    = '"${local.hub_label}-to-${var.ai_vnet_name}-${var.name_suffix}"'
}
Get-ChildItem $M -Filter *.tf | ForEach-Object {
    $t = [IO.File]::ReadAllText($_.FullName)
    foreach ($k in $map.Keys) { $t = $t.Replace($k, $map[$k]) }
    [IO.File]::WriteAllText($_.FullName, $t)
}
```

Confirm nothing root-scoped is left:

```powershell
Select-String -Path "$M\*.tf" -Pattern 'platform_region0|random_string|terraform_remote_state|local\.common_tags|aifoundry\$|vhub00|ai_vnet_address_space'
```

Expected: no output.

Confirm the new names are in place:

```powershell
Select-String -Path "$M\*.tf" -Pattern 'local\.account_name|local\.hub_label|appinsights-foundry-' | ForEach-Object { "$($_.Filename): $($_.Line.Trim())" }
```

Expected, in any order:

```
aisearch.tf: name                      = "${local.account_name}search"
cosmosdb.tf: name                = "${local.account_name}cosmosdb"
foundry.tf: name                      = local.account_name
foundry.tf: customSubDomainName = local.account_name
networking.tf: name                      = "${local.hub_label}-to-${var.ai_vnet_name}-${var.name_suffix}"
project.tf: name                = "appinsights-foundry-${var.platform.region_abbr}-${var.name_suffix}"
storage.tf: name                = "${local.account_name}st"
```

- [ ] **Step 3: Export the Foundry endpoint**

In `Foundry-byoVnet/modules/foundry-region/foundry.tf`, the `azapi_resource "foundry"` block ends with the closing of `body`. Replace:

```hcl
          useMicrosoftManagedNetwork = false
        }
      ]
    }
  }
}
```

with:

```hcl
          useMicrosoftManagedNetwork = false
        }
      ]
    }
  }

  response_export_values = [
    "properties.endpoint"
  ]
}
```

- [ ] **Step 4: Create the child `main.tf`**

`Foundry-byoVnet/modules/foundry-region/main.tf`:

```hcl
########## Regional Foundry stack
##########

# Provider sources only. Versions are pinned by the root module config.tf.
terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}

## Create a resource group for AI Foundry resources
##
resource "azurerm_resource_group" "rg-ai00" {
  name     = "${var.resource_group_name_ai00}-${var.platform.region_abbr}-${var.name_suffix}"
  location = var.platform.resource_group_location
  tags     = var.common_tags
}
```

- [ ] **Step 5: Create the child `locals.tf`**

`Foundry-byoVnet/modules/foundry-region/locals.tf`:

```hcl
locals {
  # Globally unique base name for the Foundry account and its data services
  account_name = "aifoundry${var.platform.region_abbr}${var.name_suffix}"

  # vhub00 for region0, vhub01 for region1
  hub_label = "vhub0${trimprefix(var.region_key, "region")}"

  project_id_guid = "${substr(azapi_resource.foundry_project.output.properties.internalId, 0, 8)}-${substr(azapi_resource.foundry_project.output.properties.internalId, 8, 4)}-${substr(azapi_resource.foundry_project.output.properties.internalId, 12, 4)}-${substr(azapi_resource.foundry_project.output.properties.internalId, 16, 4)}-${substr(azapi_resource.foundry_project.output.properties.internalId, 20, 12)}"
}
```

- [ ] **Step 6: Create the child `variables.tf`**

`Foundry-byoVnet/modules/foundry-region/variables.tf`:

```hcl
## Regional context
variable "region_key" {
  description = "alz_regions key for this stack: region0 or region1"
  type        = string

  validation {
    condition     = contains(["region0", "region1"], var.region_key)
    error_message = "region_key must be region0 or region1."
  }
}

variable "platform" {
  description = "Networking alz_regions entry for this region"
  type = object({
    region_name             = string
    region_abbr             = string
    resource_group_location = string
    vhub_id                 = string
    firewall_enabled        = bool
    dns_server_ip           = string
    dns_resolver_policy_id  = string
    private_dns_zone_ids    = map(string)
  })

  validation {
    condition     = can(regex("^[a-z0-9]{1,9}$", var.platform.region_abbr))
    error_message = "Networking ${var.region_key} region_abbr must be 1 to 9 lowercase letters or digits so the Storage account name stays within 24 characters."
  }

  validation {
    condition     = var.platform.vhub_id != null
    error_message = "Networking ${var.region_key} has no virtual hub. Apply Networking with create_vhub01 = true before deploying region1."
  }

  validation {
    condition     = var.platform.dns_server_ip != null && var.platform.dns_resolver_policy_id != null
    error_message = "Networking ${var.region_key} has no Private DNS. Apply Networking with add_private_dns0${trimprefix(var.region_key, "region")} = true before deploying this landing zone."
  }

  validation {
    condition     = alltrue([for zone in ["cognitiveservices", "services_ai", "openai"] : try(var.platform.private_dns_zone_ids[zone], null) != null])
    error_message = "Networking ${var.region_key} is missing Foundry Private DNS zone IDs: ${join(", ", [for zone in ["cognitiveservices", "services_ai", "openai"] : zone if try(var.platform.private_dns_zone_ids[zone], null) == null])}."
  }

  validation {
    condition     = !var.deploy_agent_data_services || alltrue([for zone in ["blob", "documents", "search"] : try(var.platform.private_dns_zone_ids[zone], null) != null])
    error_message = "Networking ${var.region_key} is missing agent data service Private DNS zone IDs: ${join(", ", [for zone in ["blob", "documents", "search"] : zone if try(var.platform.private_dns_zone_ids[zone], null) == null])}."
  }
}

variable "network" {
  description = "Address prefixes for this region's spoke VNet"
  type = object({
    vnet_address_space              = list(string)
    foundry_subnet_address          = list(string)
    private_endpoint_subnet_address = list(string)
  })
}

variable "name_suffix" {
  description = "Random suffix shared by every region"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Shared platform Log Analytics workspace ID"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to taggable resources"
  type        = map(string)
}

## Names
variable "resource_group_name_ai00" {
  description = "Resource group base name"
  type        = string
}

variable "ai_vnet_name" {
  description = "AI spoke VNet base name"
  type        = string
}

variable "ai_foundry_subnet_name" {
  description = "Foundry workload subnet base name"
  type        = string
}

variable "private_endpoint_subnet_name" {
  description = "Private endpoint subnet base name"
  type        = string
}

## Model deployment
variable "gpt_model_deployment_name" {
  description = "Name of the GPT model deployment"
  type        = string
}

variable "gpt_model_name" {
  description = "GPT model name"
  type        = string
}

variable "gpt_model_version" {
  description = "GPT model version"
  type        = string
}

variable "gpt_model_sku_name" {
  description = "SKU name for the GPT model deployment"
  type        = string
}

variable "gpt_model_capacity" {
  description = "Capacity units for the GPT model deployment"
  type        = number
}

## Service SKUs
variable "ai_search_sku" {
  description = "SKU for the AI Search service"
  type        = string
}

variable "foundry_sku" {
  description = "SKU for the Foundry account and project"
  type        = string
}

## Agent data services
variable "deploy_agent_data_services" {
  description = "Deploy BYO agent data services (Storage, Cosmos DB, AI Search) and their dependents"
  type        = bool
}
```

The root passes each full `alz_regions` entry as `platform`. Terraform drops the attributes the object type does not declare, such as `enabled` and `dns_vnet_id`.

- [ ] **Step 7: Create the child `outputs.tf`**

`Foundry-byoVnet/modules/foundry-region/outputs.tf`:

```hcl
output "foundry_region" {
  description = "Regional Foundry contract entry published in the root foundry_regions output"
  value = {
    region_name            = var.platform.region_name
    region_abbr            = var.platform.region_abbr
    resource_group_id      = azurerm_resource_group.rg-ai00.id
    foundry_id             = azapi_resource.foundry.id
    foundry_endpoint       = azapi_resource.foundry.output.properties.endpoint
    project_id             = azapi_resource.foundry_project.id
    model_deployment_names = [azurerm_cognitive_deployment.aifoundry_deployment_gpt_4o.name]
    storage_account_id     = one(azurerm_storage_account.storage_account[*].id)
    cosmosdb_account_id    = one(azurerm_cosmosdb_account.cosmosdb[*].id)
    ai_search_id           = one(azapi_resource.ai_search[*].id)
  }
}
```

- [ ] **Step 8: Replace the root `main.tf`**

This removes the root resource group and the `check "dns_prerequisite"` block. The child validations replace the check.

`Foundry-byoVnet/main.tf`:

```hcl
########## Create infrastructure resources
##########

## Create a random string shared by every region
##
resource "random_string" "unique" {
  length      = 4
  min_numeric = 4
  numeric     = true
  special     = false
  lower       = true
  upper       = false
}

## Data imports from Networking
##

data "terraform_remote_state" "networking" {
  backend = "local"
  config = {
    path = "../Networking/terraform.tfstate"
  }
}

## Deploy one independent Foundry stack per selected region
## Prerequisites are enforced by variable validation in this module and in modules/foundry-region.
##
module "foundry_region" {
  for_each = local.selected_regions
  source   = "./modules/foundry-region"

  region_key                 = each.key
  platform                   = each.value
  network                    = var.regional_networks[each.key]
  name_suffix                = random_string.unique.result
  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id
  common_tags                = local.common_tags

  resource_group_name_ai00     = var.resource_group_name_ai00
  ai_vnet_name                 = var.ai_vnet_name
  ai_foundry_subnet_name       = var.ai_foundry_subnet_name
  private_endpoint_subnet_name = var.private_endpoint_subnet_name

  gpt_model_deployment_name = var.gpt_model_deployment_name
  gpt_model_name            = var.gpt_model_name
  gpt_model_version         = var.gpt_model_version
  gpt_model_sku_name        = var.gpt_model_sku_name
  gpt_model_capacity        = var.gpt_model_capacity

  ai_search_sku              = var.ai_search_sku
  foundry_sku                = var.foundry_sku
  deploy_agent_data_services = var.deploy_agent_data_services
}
```

- [ ] **Step 9: Replace the root `locals.tf`**

Region 0 only for now. Task 3 widens the selection.

`Foundry-byoVnet/locals.tf`:

```hcl
locals {
  alz_regions = data.terraform_remote_state.networking.outputs.alz_regions

  selected_regions = {
    region0 = local.alz_regions.region0
  }

  common_tags = {
    environment = "non-prod"
    managed_by  = "terraform"
    project     = "azure-infra-poc"
  }
}
```

- [ ] **Step 10: Replace the root `outputs.tf`**

`Foundry-byoVnet/outputs.tf`:

```hcl
output "foundry_regions" {
  description = "Deployed Foundry stacks keyed by alz_regions key. region1 is present only when it was deployed."
  value       = { for key, stack in module.foundry_region : key => stack.foundry_region }
}
```

- [ ] **Step 11: Replace the address variables in the root `variables.tf`**

In `Foundry-byoVnet/variables.tf`, replace this block:

```hcl
## Spoke VNet variables
## WARNING: Default address spaces use Block 2 (172.20.32.0/20). Block 3 is reserved for Foundry-managedVnet.
## See docs/ip-addressing.md for the full allocation table.
variable "ai_vnet_name" {
  description = "AI spoke VNet name"
  type        = string
  default     = "ai-vnet"
}
variable "ai_vnet_address_space" {
  description = "AI spoke VNet address space (Block 2 — 172.20.32.0/20)"
  type        = list(string)
  default     = ["172.20.32.0/20"]
}
variable "ai_foundry_subnet_name" {
  description = "Foundry workload subnet name (Microsoft.App delegation)"
  type        = string
  default     = "ai-foundry-subnet"
}
variable "ai_foundry_subnet_address" {
  description = "Foundry workload subnet address prefix"
  type        = list(string)
  default     = ["172.20.32.0/26"]
}
variable "private_endpoint_subnet_name" {
  description = "Private endpoint subnet name"
  type        = string
  default     = "private-endpoint-subnet"
}
variable "private_endpoint_subnet_address" {
  description = "Private endpoint subnet address prefix"
  type        = list(string)
  default     = ["172.20.33.0/24"]
}
```

with:

```hcl
## Spoke VNet variables
## WARNING: Defaults use Block 2 (172.20.32.0/20). Block 3 is reserved for Foundry-managedVnet.
## See docs/ip-addressing.md for the full allocation table.
variable "regional_networks" {
  description = "Spoke VNet and subnet address prefixes keyed by alz_regions key. Overriding one region requires supplying the whole map."
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
  }

  validation {
    condition     = contains(keys(var.regional_networks), "region0")
    error_message = "regional_networks must contain region0."
  }

  validation {
    condition     = alltrue([for key in keys(var.regional_networks) : contains(["region0", "region1"], key)])
    error_message = "regional_networks keys must be region0 or region1. Unknown keys: ${join(", ", [for key in keys(var.regional_networks) : key if !contains(["region0", "region1"], key)])}."
  }
}

variable "ai_vnet_name" {
  description = "AI spoke VNet name"
  type        = string
  default     = "ai-vnet"
}
variable "ai_foundry_subnet_name" {
  description = "Foundry workload subnet name (Microsoft.App delegation)"
  type        = string
  default     = "ai-foundry-subnet"
}
variable "private_endpoint_subnet_name" {
  description = "Private endpoint subnet name"
  type        = string
  default     = "private-endpoint-subnet"
}
```

- [ ] **Step 12: Run the static checks**

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Foundry-byoVnet')
terraform init -backend=false -input=false | Out-Null
terraform fmt -check -recursive
terraform validate
```

Expected: `fmt` prints nothing. `validate` prints `Success! The configuration is valid.`

If `fmt -check` lists files, run `terraform fmt -recursive`, review the whitespace-only diff, and rerun.

- [ ] **Step 13: Confirm plan counts are unchanged**

```powershell
Set-Location (git rev-parse --show-toplevel)
$H = Join-Path ([IO.Path]::GetTempPath()) 'anp-foundry-harness'
& "$H\Invoke-FoundryHarness.ps1"
& "$H\Invoke-FoundryHarness.ps1" -TfArgs '-var=deploy_agent_data_services=false'
```

Expected: `Plan: 47 to add` then `Plan: 24 to add`, both `exit=0`.

- [ ] **Step 14: Confirm region 0 has exactly the baseline resources**

```powershell
& "$H\Invoke-FoundryHarness.ps1" -JsonOut "$H\task2.json" | Out-Null
$pre = 'module.foundry_region["region0"].'
$new = (Get-Content "$H\task2.json" -Raw | ConvertFrom-Json).resource_changes | ForEach-Object address |
    Where-Object { $_.StartsWith($pre) } | ForEach-Object { $_.Substring($pre.Length) } | Sort-Object
"count=$($new.Count)"
Compare-Object (Get-Content "$H\baseline-addresses.txt") $new
```

Expected: `count=46` and no `Compare-Object` output.

- [ ] **Step 15: Confirm region 0 names**

```powershell
& "$H\Invoke-FoundryHarness.ps1" -PinSuffix -JsonOut "$H\task2-names.json" | Out-Null
$rc = (Get-Content "$H\task2-names.json" -Raw | ConvertFrom-Json).resource_changes
$m = 'module.foundry_region["region0"]'
function After($a) { ($rc | Where-Object address -eq $a).change.after }
(After "$m.azurerm_resource_group.rg-ai00").name
(After "$m.azapi_resource.foundry").name
(After "$m.azapi_resource.foundry").body.properties.customSubDomainName
(After "$m.azurerm_storage_account.storage_account[0]").name
(After "$m.azurerm_cosmosdb_account.cosmosdb[0]").name
(After "$m.azapi_resource.ai_search[0]").name
(After "$m.azurerm_application_insights.foundry_appinsights").name
(After "$m.azurerm_virtual_hub_connection.vhub_connection_to_ai").name
```

Expected:

```
rg-ai00-swc-1234
aifoundryswc1234
aifoundryswc1234
aifoundryswc1234st
aifoundryswc1234cosmosdb
aifoundryswc1234search
appinsights-foundry-swc-1234
vhub00-to-ai-vnet-1234
```

- [ ] **Step 16: Commit**

```powershell
Set-Location (git rev-parse --show-toplevel)
git add Foundry-byoVnet
git status --short
git commit -m "refactor(foundry-byovnet): move regional resources into child module"
```

`git status --short` must show only paths under `Foundry-byoVnet/`, with the eight moved files shown as renames. It must not show `.terraform/`, `terraform.tfstate`, or `terraform.tfvars`.

---

### Task 3: Add the optional region 1 stack

**Files:**
- Modify: `Foundry-byoVnet/variables.tf`
- Modify: `Foundry-byoVnet/locals.tf`

**Interfaces:**
- Consumes: `module.foundry_region`, `var.regional_networks`, and `local.selected_regions` from Task 2.
- Produces: `var.deploy_region1` (bool, default `false`), the region 1 entry in the `regional_networks` default, and the final `selected_regions` expression.

- [ ] **Step 1: Write the failing check**

```powershell
Set-Location (git rev-parse --show-toplevel)
$H = Join-Path ([IO.Path]::GetTempPath()) 'anp-foundry-harness'
& "$H\Invoke-FoundryHarness.ps1" -Region1 -TfArgs '-var=deploy_region1=true'
```

Expected: `exit=1`. The plan fails because `deploy_region1` is not declared yet. The harness filter prints the `Error:` line and the `deploy_region1` detail.

- [ ] **Step 2: Add `deploy_region1`**

In `Foundry-byoVnet/variables.tf`, insert after the `resource_group_name_ai00` variable:

```hcl

## Regional deployment
variable "deploy_region1" {
  description = "Deploy a second, independent Foundry stack in Networking region 1. Requires Networking create_vhub01 = true and add_private_dns01 = true."
  type        = bool
  default     = false

  validation {
    condition     = !var.deploy_region1 || data.terraform_remote_state.networking.outputs.alz_regions.region1.enabled
    error_message = "deploy_region1 = true requires Networking region 1. Apply Networking with create_vhub01 = true and add_private_dns01 = true, then plan this module again."
  }
}
```

- [ ] **Step 3: Add the region 1 network default and validation**

In `Foundry-byoVnet/variables.tf`, replace the `regional_networks` comment header and default:

```hcl
## Spoke VNet variables
## WARNING: Defaults use Block 2 (172.20.32.0/20). Block 3 is reserved for Foundry-managedVnet.
## See docs/ip-addressing.md for the full allocation table.
```

with:

```hcl
## Spoke VNet variables
## WARNING: Defaults use Block 2 in each region (172.20.32.0/20 and 172.21.32.0/20). Block 3 is reserved for Foundry-managedVnet.
## See docs/ip-addressing.md for the full allocation table.
```

Then replace:

```hcl
    region0 = {
      vnet_address_space              = ["172.20.32.0/20"]
      foundry_subnet_address          = ["172.20.32.0/26"]
      private_endpoint_subnet_address = ["172.20.33.0/24"]
    }
  }
```

with:

```hcl
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
```

Then add a third validation after the unknown-keys validation, inside the `regional_networks` block:

```hcl

  validation {
    condition     = !var.deploy_region1 || contains(keys(var.regional_networks), "region1")
    error_message = "regional_networks must contain region1 when deploy_region1 = true."
  }
```

- [ ] **Step 4: Widen region selection**

In `Foundry-byoVnet/locals.tf`, replace:

```hcl
  selected_regions = {
    region0 = local.alz_regions.region0
  }
```

with:

```hcl
  # region0 always deploys. region1 deploys only when this module asks for it and Networking provides it.
  selected_regions = {
    for key, region in local.alz_regions : key => region
    if key == "region0" || (key == "region1" && var.deploy_region1 && region.enabled)
  }
```

- [ ] **Step 5: Run the static checks**

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Foundry-byoVnet')
terraform fmt -check -recursive
terraform validate
```

Expected: `fmt` prints nothing. `validate` prints `Success! The configuration is valid.`

- [ ] **Step 6: Run the plan matrix**

```powershell
Set-Location (git rev-parse --show-toplevel)
$H = Join-Path ([IO.Path]::GetTempPath()) 'anp-foundry-harness'
"1"; & "$H\Invoke-FoundryHarness.ps1"
"2"; & "$H\Invoke-FoundryHarness.ps1" -TfArgs '-var=deploy_agent_data_services=false'
"3"; & "$H\Invoke-FoundryHarness.ps1" -TfArgs '-var=deploy_region1=true'
"4"; & "$H\Invoke-FoundryHarness.ps1" -Region1
"5"; & "$H\Invoke-FoundryHarness.ps1" -Region1 -TfArgs '-var=deploy_region1=true'
"6"; & "$H\Invoke-FoundryHarness.ps1" -Region1 -TfArgs '-var=deploy_region1=true', '-var=deploy_agent_data_services=false'
"7"; & "$H\Invoke-FoundryHarness.ps1" -Region1 -NoRegion1Dns -TfArgs '-var=deploy_region1=true'
"8"; & "$H\Invoke-FoundryHarness.ps1" -Region1 -NoRegion1Dns
```

Expected:

| # | Networking | Arguments | Expected output |
|---|---|---|---|
| 1 | Region 0 only | defaults | `Plan: 47 to add`, `exit=0` |
| 2 | Region 0 only | data services off | `Plan: 24 to add`, `exit=0` |
| 3 | Region 0 only | `deploy_region1=true` | `deploy_region1 = true requires Networking region 1...`, `exit=1` |
| 4 | Two regions | defaults | `Plan: 47 to add`, `exit=0` |
| 5 | Two regions | `deploy_region1=true` | `Plan: 93 to add`, `exit=0` |
| 6 | Two regions | `deploy_region1=true`, data services off | `Plan: 47 to add`, `exit=0` |
| 7 | Region 1 without DNS | `deploy_region1=true` | `Networking region1 has no Private DNS... add_private_dns01 = true...`, the Foundry zone message, and the data service zone message listing `blob, documents, search`, `exit=1` |
| 8 | Region 1 without DNS | defaults | `Plan: 47 to add`, `exit=0` |

A failing plan may also print a partial `Plan: N to add` line. The `exit=1` and the message are what count. The same applies to Step 7.

- [ ] **Step 7: Check the `regional_networks` validations**

```powershell
$h1 = Join-Path $H 'missing-region1.tfvars'
$h2 = Join-Path $H 'unknown-key.tfvars'
@'
regional_networks = {
  region0 = { vnet_address_space = ["172.20.32.0/20"], foundry_subnet_address = ["172.20.32.0/26"], private_endpoint_subnet_address = ["172.20.33.0/24"] }
}
'@ | Set-Content $h1
@'
regional_networks = {
  region0 = { vnet_address_space = ["172.20.32.0/20"], foundry_subnet_address = ["172.20.32.0/26"], private_endpoint_subnet_address = ["172.20.33.0/24"] }
  region2 = { vnet_address_space = ["172.22.32.0/20"], foundry_subnet_address = ["172.22.32.0/26"], private_endpoint_subnet_address = ["172.22.33.0/24"] }
}
'@ | Set-Content $h2
& "$H\Invoke-FoundryHarness.ps1" -Region1 -TfArgs '-var=deploy_region1=true', "-var-file=$h1"
& "$H\Invoke-FoundryHarness.ps1" -TfArgs "-var-file=$h2"
```

Expected: the first prints `regional_networks must contain region1 when deploy_region1 = true.` and `exit=1`. The second prints `regional_networks keys must be region0 or region1. Unknown keys: region2.` and `exit=1`.

- [ ] **Step 8: Check both regions' resources and names**

```powershell
& "$H\Invoke-FoundryHarness.ps1" -Region1 -PinSuffix -JsonOut "$H\task3.json" -TfArgs '-var=deploy_region1=true' | Out-Null
$rc = (Get-Content "$H\task3.json" -Raw | ConvertFrom-Json).resource_changes
function After($a) { ($rc | Where-Object address -eq $a).change.after }
foreach ($k in 'region0', 'region1') {
    $pre = "module.foundry_region[`"$k`"]."
    $addr = $rc | ForEach-Object address | Where-Object { $_.StartsWith($pre) } | ForEach-Object { $_.Substring($pre.Length) } | Sort-Object
    $m = "module.foundry_region[`"$k`"]"
    "$k diff=$(@(Compare-Object (Get-Content "$H\baseline-addresses.txt") $addr).Count)"
    "  " + (After "$m.azapi_resource.foundry").name + " " + (After "$m.azurerm_storage_account.storage_account[0]").name + " " + (After "$m.azurerm_virtual_hub_connection.vhub_connection_to_ai").name
    "  vhub=" + ((After "$m.azurerm_virtual_hub_connection.vhub_connection_to_ai").virtual_hub_id -split '/')[-1] + " dns=" + ((After "$m.azurerm_virtual_network_dns_servers.ai_vnet_dns").dns_servers -join ',') + " vnet=" + ((After "$m.azurerm_virtual_network.ai_vnet").address_space -join ',')
    "  zone-rg=" + (((After "$m.azurerm_private_endpoint.pe-aifoundry").private_dns_zone_group[0].private_dns_zone_ids | ForEach-Object { ($_ -split '/')[4] }) | Sort-Object -Unique)
}
```

Expected:

```
region0 diff=0
  aifoundryswc1234 aifoundryswc1234st vhub00-to-ai-vnet-1234
  vhub=vhub-swc dns=172.20.16.4 vnet=172.20.32.0/20
  zone-rg=rg-net00-swc-0000
region1 diff=0
  aifoundrycus1234 aifoundrycus1234st vhub01-to-ai-vnet-1234
  vhub=vhub-cus dns=172.21.16.4 vnet=172.21.32.0/20
  zone-rg=rg-net01-cus-0000
```

- [ ] **Step 9: Commit**

```powershell
Set-Location (git rev-parse --show-toplevel)
git add Foundry-byoVnet/variables.tf Foundry-byoVnet/locals.tf
git commit -m "feat(foundry-byovnet): add optional region 1 stack"
```

---

### Task 4: Documentation

**Files:**
- Replace: `Foundry-byoVnet/README.md`
- Replace: `Foundry-byoVnet/terraform.tfvars.example`
- Modify: `docs/ip-addressing.md`
- Modify: `Networking/README.md`
- Modify: `.github/copilot-instructions.md`

**Interfaces:**
- Consumes: variable, output, and naming facts from Tasks 2 and 3.
- Produces: documentation only.

- [ ] **Step 1: Replace `Foundry-byoVnet/README.md`**

````markdown
# Application Landing Zone — Microsoft Foundry (BYO VNet)

This is an optional application landing zone. It deploys Microsoft Foundry with Agent Service and private endpoints into its own spoke VNet. The module creates the VNet, subnets, and hub connection. You do not need to deploy this to use the Networking module on its own.

This module is based on the [validated Terraform sample](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-terraform/15b-private-network-standard-agent-setup-byovnet), modified to pull network dependencies from the platform landing zone via `terraform_remote_state`.

"Secure" refers to the use of private endpoints. Local auth (API keys) is disabled on AI Search and Cosmos DB when the agent data services are deployed. The Foundry account keeps `disableLocalAuth = false`, which the Agent proxy requires for internal communication over a BYO VNet.

The template follows the [documented architecture](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/virtual-networks) for Microsoft Foundry Standard Setup with private networking (BYO VNet).

![secureAIFoundry](../Diagrams/secureAIFoundry-diagram.png)

## Prerequisites

- All [platform landing zone prerequisites](../README.md#prerequisites)
- Platform Landing Zone (`Networking/`) applied first
- Private DNS zones enabled (`add_private_dns00 = true` in Networking)
- Azure region with AI Foundry support and quota
- For a second region, see [Region 1](#region-1)

## Quick Start

```sh
cd Foundry-byoVnet
terraform init && terraform apply
```

**Prerequisites:** Networking module must be applied first with `add_private_dns00 = true`.

## Upgrading an existing deployment

⚠️ This version moves every resource into `modules/foundry-region/` and adds the region abbreviation to the Foundry account and data service names. Terraform cannot carry an earlier deployment forward. Run `terraform destroy` with the version you deployed, finish the [cleanup](#cleanup) steps, then apply this version.

## Variables

This module creates its own VNet with subnets and hub connection per region. Customize networking and deployment names, or use defaults.

| Variable                     | Default                    | Purpose                                         |
| ---------------------------- | -------------------------- | ----------------------------------------------- |
| `resource_group_name_ai00`   | `"rg-ai00"`                | Resource group base name                        |
| `deploy_region1`             | `false`                    | Deploy a second stack in Networking region 1    |
| `regional_networks`          | See below                  | Per-region VNet and subnet address prefixes     |
| `deploy_agent_data_services` | `true`                     | Deploy BYO agent data services in every region  |

`regional_networks` defaults:

| Key       | VNet             | Foundry subnet   | Private endpoint subnet |
| --------- | ---------------- | ---------------- | ----------------------- |
| `region0` | `172.20.32.0/20` | `172.20.32.0/26` | `172.20.33.0/24`        |
| `region1` | `172.21.32.0/20` | `172.21.32.0/26` | `172.21.33.0/24`        |

Overriding `regional_networks` replaces the whole map, so include `region0` and, when `deploy_region1 = true`, `region1`. See `docs/ip-addressing.md` before changing prefixes.

For GPT deployment names, SKUs, and other service config, see `variables.tf`. Model, SKU, and data service settings apply to every deployed region.

### Region 1

Region 0 always deploys. Set `deploy_region1 = true` to add a second, independent stack in Networking region 1. It gets its own resource group, spoke VNet, hub connection, Foundry account, project, model deployment, private endpoints, and, when enabled, data services.

Region 1 requires:

- Networking applied with `create_vhub01 = true` and `add_private_dns01 = true`
- A region 1 Azure region that supports Foundry Agent Service with BYO VNet injection
- Quota in region 1 for the configured model and SKU

If Networking region 1 is missing, `terraform plan` fails with a message naming the Networking variables to set. Networking region 1 on its own does not deploy a second Foundry stack. This module only uses it when `deploy_region1 = true`.

Each stack resolves private endpoints through its own region's Private DNS. A client in region 0 cannot resolve the region 1 Foundry endpoint, so test region 1 from the region 1 test VM. The two stacks share no state and do not fail over.

Region 1 roughly doubles the module's cost. With data services enabled, it adds a second AI Search service, Cosmos DB account, and Storage account.

### Agent data services

By default the module deploys its own Azure Storage, Cosmos DB, and AI Search, and the project capability host points agent data at them.

Set `deploy_agent_data_services = false` to omit all three, along with their private endpoints, project connections, role assignments, and diagnostic settings. Foundry Agent Service then uses Microsoft-managed storage for conversation history, file uploads, and vector data.

The module remains a bring-your-own virtual network deployment in both modes. The Foundry account, its network injection, the project, the model deployment, and the private endpoint are unchanged.

The module waits three minutes after creating or replacing the Foundry account before it creates the account's private endpoint. The account reports a finished create while its provisioning state is still `Accepted`, and an endpoint created during that window fails with `AccountProvisioningStateInvalid`. In the default mode, the wait runs in parallel with the sequential data service endpoints.

Capability hosts cannot be updated in place, so pick a value before you deploy. Changing it on a live deployment requires `terraform destroy` first.

## Outputs

`foundry_regions` is a map keyed by `region0` and, when deployed, `region1`. Each entry has:

| Field                    | Purpose                                                    |
| ------------------------ | ---------------------------------------------------------- |
| `region_name`            | Azure region name                                          |
| `region_abbr`            | Region abbreviation used in resource names                 |
| `resource_group_id`      | Regional resource group ID                                 |
| `foundry_id`             | Microsoft Foundry account ID                               |
| `foundry_endpoint`       | Microsoft Foundry account endpoint                         |
| `project_id`             | Microsoft Foundry project ID                               |
| `model_deployment_names` | Model deployment names in the account                      |
| `storage_account_id`     | Storage account ID, null when data services are disabled   |
| `cosmosdb_account_id`    | Cosmos DB account ID, null when data services are disabled |
| `ai_search_id`           | AI Search service ID, null when data services are disabled |

## Cleanup

Destroy this module before Networking. Repeat the purge for every region you deployed.

⚠️ **Soft-delete gotcha:** After `terraform destroy`, each Foundry account enters soft-delete state with a `serviceassociationlink` to its region's AI subnet. You must purge every soft-deleted account before destroying Networking, or the subnet delete will fail. Wait ~10 minutes after each purge completes.

- [Purge a deleted resource](https://learn.microsoft.com/en-us/azure/ai-services/recover-purge-resources?tabs=azure-cli#purge-a-deleted-resource)

⚠️ **Orphaned Service Association Link:** Another issue could be an orphaned service association link (SAL). Each AI subnet uses a SAL to the Microsoft-managed environment behind the scenes, and the SAL is owned by the Microsoft backend. If you’re unable to delete an AI subnet due to an existing SAL, remove the service association from the subnet and wait 48-72 hours for the backend cleanup process to complete; then you should be able to delete the VNet.

## Security & Privacy — Foundry Trace Logs

> ⚠️ **PII Risk in Agent Traces**
>
> The Foundry project diagnostic setting captures Trace Logs via the `allLogs` category group. Per [Microsoft's documentation](https://learn.microsoft.com/azure/foundry/observability/how-to/trace-agent-setup#security-and-privacy), these traces may contain user inputs, model outputs, and tool arguments — i.e., sensitive content and PII. All trace data flows into the Log Analytics workspace, where it is queryable by anyone with `Log Analytics Reader` role.
>
> Before graduating this lab to production, review your data handling requirements. If PII handling is critical, consider excluding `Trace Logs` from the project diagnostic setting or restricting Log Analytics access via Azure RBAC.
````

- [ ] **Step 2: Replace `Foundry-byoVnet/terraform.tfvars.example`**

```hcl
# ─────────────────────────────────────────────
# Foundry (BYO VNet) — Example config
# ─────────────────────────────────────────────
# Copy this file to terraform.tfvars and edit.
# Requires Networking module deployed first.

# ── Regions ──────────────────────────────────
# Region 0 always deploys. Set to true to add an independent stack in
# Networking region 1 (requires create_vhub01 and add_private_dns01).
# deploy_region1 = false

# ── VNet address space ───────────────────────
# Block 2 in each region — must not overlap Networking or Foundry-managedVnet.
# Overriding this replaces the whole map.
regional_networks = {
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

# ── GPT model deployment ────────────────────
# Applies to every deployed region.
gpt_model_deployment_name = "gpt-5.4"
gpt_model_name            = "gpt-5.4"
gpt_model_version         = "2026-03-05"
gpt_model_sku_name        = "GlobalStandard"
gpt_model_capacity        = 1

# ── Service SKUs ─────────────────────────────
# ai_search_sku = "standard"
# foundry_sku   = "S0"

# ── Agent data services ──────────────────────
# Set to false to omit Storage, Cosmos DB, and AI Search and let
# Foundry Agent Service use Microsoft-managed storage instead.
# deploy_agent_data_services = true
```

- [ ] **Step 3: Assign region 1 block 2 in `docs/ip-addressing.md`**

Replace:

```markdown
| 2 | `172.21.32.0/20` | Reserved — Foundry-byoVnet (region 1, future) | — |
```

with:

```markdown
| 2 | `172.21.32.0/20` | App LZ — **Foundry-byoVnet** (optional, `deploy_region1 = true`) | `172.21.32.0/26` (AI Foundry), `172.21.33.0/24` (Private Endpoints) |
```

- [ ] **Step 4: Update `Networking/README.md` downstream dependencies**

Replace:

```markdown
Application landing zone modules (`Foundry-byoVnet/`, `Foundry-managedVnet/`, `ContainerApps-byoVnet/`, and `Fabric-private/`) consume `alz_regions.region0` via `terraform_remote_state` (local backend, reads `./terraform.tfstate`). Each module creates its own spoke VNet and subnets. If a workload needs private DNS resolution, set `add_private_dns00 = true`.
```

with:

```markdown
Application landing zone modules (`Foundry-byoVnet/`, `Foundry-managedVnet/`, `ContainerApps-byoVnet/`, and `Fabric-private/`) consume `alz_regions.region0` via `terraform_remote_state` (local backend, reads `./terraform.tfstate`). Each module creates its own spoke VNet and subnets. If a workload needs private DNS resolution, set `add_private_dns00 = true`.

`Foundry-byoVnet/` also consumes `alz_regions.region1` when its `deploy_region1 = true`. That requires `create_vhub01 = true` and `add_private_dns01 = true` here.
```

- [ ] **Step 5: Update `.github/copilot-instructions.md`**

Replace:

```markdown
Destroy application landing zones before `Networking/`. `Foundry-byoVnet/` requires purging the soft-deleted Foundry resource before its delegated subnet can be removed.
```

with:

```markdown
Destroy application landing zones before `Networking/`. `Foundry-byoVnet/` requires purging each soft-deleted Foundry resource before its delegated subnet can be removed.
```

Replace:

```markdown
- Application resources generally use `{base-name}-{local.platform_region0.region_abbr}-{random_string.unique.result}`. The platform uses `local.suffix = random_string.unique.id`.
```

with:

```markdown
- Application resources generally use `{base-name}-{region_abbr}-{random_string.unique.result}`. `Foundry-byoVnet/` also puts the region abbreviation in globally unique names, such as `aifoundry{abbr}{suffix}`. The platform uses `local.suffix = random_string.unique.id`.
```

Replace:

```markdown
- Application spokes use `local.platform_region0` from the `alz_regions` output: vHub connections use `vhub_id`, `internet_security_enabled` follows `firewall_enabled`, private-endpoint subnets use its inverse for `default_outbound_access_enabled`, VNet DNS uses `dns_server_ip`, resolver policy links use `dns_resolver_policy_id`, and private endpoint zone groups use `private_dns_zone_ids`.
- Networking's `alz_regions` entries are null-safe for optional DNS, Firewall, and region-1 resources. Application modules validate required values with `check` blocks before creating dependent resources.
```

with:

```markdown
- Application spokes use their region's `alz_regions` entry, `local.platform_region0` in single-region modules and the `platform` input in `Foundry-byoVnet/modules/foundry-region/`: vHub connections use `vhub_id`, `internet_security_enabled` follows `firewall_enabled`, private-endpoint subnets use its inverse for `default_outbound_access_enabled`, VNet DNS uses `dns_server_ip`, resolver policy links use `dns_resolver_policy_id`, and private endpoint zone groups use `private_dns_zone_ids`.
- Networking's `alz_regions` entries are null-safe for optional DNS, Firewall, and region-1 resources. Single-region application modules check required values with `check` blocks, which only warn. `Foundry-byoVnet/` uses variable `validation` rules, which fail `terraform plan`.
- `Foundry-byoVnet/` is the multi-region pattern. The root selects `region0` plus `region1` when `deploy_region1 = true` (default `false`) and Networking enables it, then calls `modules/foundry-region/` with `for_each`. The child declares provider sources only, so validate it from the root. It publishes a `foundry_regions` output keyed by region.
```

- [ ] **Step 6: Verify**

```powershell
Set-Location (git rev-parse --show-toplevel)
Select-String -Path Foundry-byoVnet\README.md, Foundry-byoVnet\terraform.tfvars.example -Pattern 'ai_vnet_address_space|ai_foundry_subnet_address|^#?\s?private_endpoint_subnet_address\b|ai_foundry_id|ai_foundry_project_id'
Select-String -Path docs\ip-addressing.md -Pattern 'Reserved — Foundry-byoVnet'
Set-Location Foundry-byoVnet
terraform fmt -check -recursive
terraform validate
```

Expected: both `Select-String` commands print nothing. The new tfvars example uses `private_endpoint_subnet_address` only indented inside the map, so the line-anchored pattern skips it and matches only the old top-level variable. `fmt` prints nothing and `validate` succeeds.

Confirm the example file is valid input:

```powershell
$H = Join-Path ([IO.Path]::GetTempPath()) 'anp-foundry-harness'
Set-Location (git rev-parse --show-toplevel)
& "$H\Invoke-FoundryHarness.ps1" -TfArgs "-var-file=$((Resolve-Path Foundry-byoVnet\terraform.tfvars.example).Path)"
```

Expected: `Plan: 47 to add`, `exit=0`.

- [ ] **Step 7: Commit**

```powershell
git add Foundry-byoVnet/README.md Foundry-byoVnet/terraform.tfvars.example docs/ip-addressing.md Networking/README.md .github/copilot-instructions.md
git commit -m "docs(foundry-byovnet): document multi-region deployment"
```

- [ ] **Step 8: Remove the harness**

```powershell
Remove-Item -Recurse -Force (Join-Path ([IO.Path]::GetTempPath()) 'anp-foundry-harness')
```

---

### Task 5: Authenticated deployment validation and completion gate

This task needs Azure authentication, an active subscription, and real Networking state. The repository owner runs it, not an automated worker.

**Files:** none.

**Interfaces:**
- Consumes: the completed feature from Tasks 2 through 4.
- Produces: the pass or fail signal that closes this package.

Before starting, destroy and purge any existing `Foundry-byoVnet/` deployment made with an earlier version, as the README upgrade notice describes.

- [ ] **Step 1: One region, data services enabled**

With Networking applied using `add_private_dns00 = true`:

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'Foundry-byoVnet')
terraform init
terraform apply
terraform output -json foundry_regions
```

Expected: `apply` creates 47 resources. The output has one `region0` entry with non-null `foundry_id`, `project_id`, and `foundry_endpoint`. `caphostproj` reaches a succeeded provisioning state. From the region 0 test VM, create an agent in the project and run a conversation.

- [ ] **Step 2: Region 1 prerequisite failure**

With Networking still at one region:

```powershell
terraform plan -var deploy_region1=true
```

Expected: the plan fails with `deploy_region1 = true requires Networking region 1`.

- [ ] **Step 3: Two regions, data services enabled**

Apply Networking with `create_vhub01 = true` and `add_private_dns01 = true`. Then:

```powershell
terraform plan
terraform apply -var deploy_region1=true
terraform output -json foundry_regions
```

Expected: the first plan shows no changes, because `deploy_region1` defaults to `false`. The apply adds 46 region 1 resources. The output has `region0` and `region1` entries. In region 1, `caphostproj` succeeds, and an agent created in the project runs a conversation from the region 1 test VM.

- [ ] **Step 4: Two regions, data services disabled**

Destroy, purge both Foundry accounts, and wait for the service association links to release. Then:

```powershell
terraform apply -var deploy_region1=true -var deploy_agent_data_services=false
```

Expected: the apply creates 47 resources. Neither resource group contains Storage, Cosmos DB, or AI Search. In each region, `caphostproj` succeeds, and an agent runs a conversation from that region's test VM.

- [ ] **Step 5: One region, data services disabled**

Destroy and purge. Then:

```powershell
terraform apply -var deploy_agent_data_services=false
```

Expected: the apply creates 24 resources, and an agent runs a conversation from the region 0 test VM.

- [ ] **Step 6: Clean up and record the outcome**

Destroy, purge every Foundry account, wait about 10 minutes, then destroy Networking if it is no longer needed.

If every step passes, this package is complete. If an apply fails, stop and return to the design. The spec defines no fallback configuration.
