# SKILL: Landing Zone Deploy

**Owner:** Donut (Infra Dev)  
**Last updated:** 2026-05-07  
**Validated:** Full cycle 2026-05-07 (579 Networking + 32 Foundry-byoVnet, ME-rykrokso-01, swedencentral, 0 retries)

---

## Purpose

Proven deploy sequence for the Azure Network Platform repo. Covers pre-flight checks, deploy order,
known transients and their retry patterns, and post-deploy verification.

---

## Pre-Flight Checklist

Before starting any deploy:

```powershell
# 1. Confirm clean git working tree (no unexpected modifications to .tf files)
git status

# 2. Confirm both state files are empty (0 resources or no file)
foreach ($mod in @("Networking", "Foundry-byoVnet")) {
    $p = "C:\github\azure-network-platform\$mod\terraform.tfstate"
    if (Test-Path $p) {
        $r = (Get-Content $p -Raw | ConvertFrom-Json).resources.Count
        Write-Host "$mod state: $r resources"
    } else { Write-Host "$mod: no state file" }
}

# 3. Confirm no orphan Azure RGs from prior deploys
az group list --query "[?contains(name, 'sece') || contains(name, 'cus')].name" -o tsv

# 4. Confirm correct Azure CLI auth context AND sync ARM_SUBSCRIPTION_ID
az account show --query "{user:user.name, sub:name, id:id}" -o json
# Must show the intended subscription. If not, set it first:
#   az account set --subscription <subscription_id>

# CRITICAL: Set ARM_SUBSCRIPTION_ID inline every session — do not rely on system-level setx value
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)

# Verify they match:
$cliSub = az account show --query id -o tsv
if ($env:ARM_SUBSCRIPTION_ID -ne $cliSub) {
    Write-Error "MISMATCH! ARM_SUBSCRIPTION_ID=$env:ARM_SUBSCRIPTION_ID but az CLI sub=$cliSub"
    # Do not proceed — will deploy to wrong subscription
}

# 5. Confirm required providers are registered in target subscription
az provider show --namespace Microsoft.Compute   --query registrationState -o tsv
az provider show --namespace Microsoft.Network   --query registrationState -o tsv
az provider show --namespace Microsoft.KeyVault  --query registrationState -o tsv
# All must show "Registered". In this repo's target sub (ME-rykrokso-01, ryan@krokson.xyz),
# all are registered. If deploying to a managed sub, a sub admin must register them first.

# 6. Confirm tfvars match intended settings
# Networking: single-region (sece), add_firewall00=true, add_private_dns00=true, create_vhub01=false
# Foundry-byoVnet: gpt_model_name=gpt-5.4, gpt_model_deployment_name=gpt-5.4
```

### ARM_SUBSCRIPTION_ID Session Safety Pattern

**Always set it inline** when the system default may be wrong:

```powershell
# Safe pattern for any Terraform command:
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
terraform plan -out=tfplan
```

Do NOT trust a previously-set system env var. A plan generated against the wrong subscription
will silently deploy all resources to that subscription. Clean-up requires deleting RGs in the
wrong sub + clearing the state file.

---

## Deploy Order

**Networking must always be deployed first.** Foundry-byoVnet reads from `../Networking/terraform.tfstate`.

```
1. Networking        (platform LZ — foundation)
2. Foundry-byoVnet   (app LZ — depends on Networking state)
```

---

## Step 1: Deploy Networking

```powershell
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
Set-Location "C:\github\azure-network-platform\Networking"
terraform init -upgrade
terraform plan -out=tfplan
terraform apply tfplan
```

**Expected:** ~579 resources, ~35 min.  
**Long pole:** modtm data sources (~5 min reading GitHub), vHub creation (~5-10 min Azure-side).  
**Known transient:** `azapi_resource.dns_policy_dns_vnet_link` InternalServerError. Simple re-apply resolves it (no state manipulation needed).

**Success markers:**
- `Apply complete! Resources: 579 added, 0 changed, 0 destroyed.`
- Outputs include `vhub00_id`, `firewall_private_ip00`, `key_vault_name`, `rg_net00_name`

---

## Step 2: Deploy Foundry-byoVnet

```powershell
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
Set-Location "C:\github\azure-network-platform\Foundry-byoVnet"
terraform init -upgrade
terraform plan -out=tfplan
terraform apply tfplan
```

**Expected:** 32 resources, ~25 min.

### Known Transients

- CosmosDB private endpoint takes 10+ min Azure-side — normal, not a failure.
- AI Search resource takes 6+ min — normal.
- Foundry capability host takes ~2-3 min after a 60s RBAC wait — expected.
- Other PE transients: simple re-apply resolves.

### Key Outputs

- `ai_foundry_id` — AI Foundry account resource ID
- `ai_foundry_project_id` — Project resource ID (use for AI Foundry Studio URL)
- `ai_search_id` — AI Search service resource ID
- `resource_group_id` — Foundry RG (`rg-ai00-sece-{suffix}`)

---

## Post-Deploy Verification

```powershell
# Check Foundry outputs
Set-Location "C:\github\azure-network-platform\Foundry-byoVnet"
terraform output
```

**Key things to verify:**
- AI Foundry Studio: `https://ai.azure.com` — sign in, switch to project `project{suffix}` in `swedencentral`
- Private endpoints: cosmosdb, storage, ai-search — all should appear in `rg-ai00-sece-{suffix}`
- vHub connection: `vhub00-to-ai-vnet-{suffix}` in `rg-net00-sece-{suffix}` — confirms spoke is routed

**Bastion host:**  
`bastion-host00-sece` in `rg-net00-sece-{suffix}`  
Connect via Azure Portal → Bastion. Use VM credentials from KV `kv00-sece-{suffix}`.

---

## Timing Reference (2026-05-07 actuals — ME-rykrokso-01, swedencentral)

| Module | Resources | Actual Time | Notes |
|--------|-----------|-------------|-------|
| Networking init | — | ~90s | Providers from cache |
| Networking plan | — | ~5 min | modtm data reads |
| Networking apply | 579 | ~35 min | vHub ~5-10 min, DNS zones fast (0 transients) |
| Foundry-byoVnet init | — | ~30s | |
| Foundry-byoVnet plan | — | ~30s | |
| Foundry-byoVnet apply | 32 | ~25 min | CosmosDB PE 10m47s, AI Search 6m41s, cap host 2m43s |
| **Total** | **611** | **~65 min** | 0 retries, 0 errors |

---

## See Also

- `.squad/skills/lz-teardown/SKILL.md` — reverse this process
- `setSubscription.ps1` — reference script showing az CLI commands for subscription alignment
