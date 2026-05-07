# SKILL: Landing Zone Deploy

**Owner:** Donut (Infra Dev)  
**Last updated:** 2026-04-30  
**Validated:** Full cycle 2026-04-30 (579 Networking + full Fabric-private, inbound_and_outbound + lakehouse)

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

# CRITICAL: Run setSubscription.ps1 EVERY session to sync ARM_SUBSCRIPTION_ID
# to the current az CLI context. The system-level env var (set via setx) may be
# stale from a prior session pointing to a different subscription.
.\setSubscription.ps1

# Verify they match:
$cliSub = az account show --query id -o tsv
if ($env:ARM_SUBSCRIPTION_ID -ne $cliSub) {
    Write-Error "MISMATCH! ARM_SUBSCRIPTION_ID=$env:ARM_SUBSCRIPTION_ID but az CLI sub=$cliSub"
    # Do not proceed — will deploy to wrong subscription
}

# 5. Confirm required providers are registered in target subscription
az provider show --namespace Microsoft.Compute   --query "{ns:namespace,state:registrationState}" -o json
az provider show --namespace Microsoft.Network   --query "{ns:namespace,state:registrationState}" -o json
az provider show --namespace Microsoft.KeyVault  --query "{ns:namespace,state:registrationState}" -o json
# All must show "Registered". If any show "NotRegistered", subscription admin must register them.

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

**Networking must always be deployed first.** Fabric-private reads from `../Networking/terraform.tfstate`.

```
1. Networking        (platform LZ — foundation)
2. Fabric-private    (app LZ — depends on Networking state)
```

---

## Step 1: Deploy Networking

```powershell
Set-Location "C:\github\azure-network-platform\Networking"
terraform init
terraform apply -auto-approve
```

**Expected:** ~579 resources, ~36 min.  
**Long pole:** modtm data sources (~30 min reading GitHub). Normal — do not interrupt.  
**Known transient:** `azapi_resource.dns_policy_dns_vnet_link` InternalServerError. Simple re-apply resolves it (no state manipulation needed).

**Success markers:**
- `Apply complete! Resources: 579 added, 0 changed, 0 destroyed.`
- Outputs include `vhub00_id`, `dns_zone_fabric_id`, `dns_server_ip00`

---

## Step 2: Deploy Foundry-byoVnet

```powershell
Set-Location "C:\github\azure-network-platform\Foundry-byoVnet"
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
terraform init
terraform apply -auto-approve
```

**Expected:** ~30-40 resources, ~20-25 min.

### Known Transients

Private endpoints can hit transient errors on creation — simple re-apply resolves.

### Key Outputs

- `foundry_endpoint` — AI Foundry project endpoint URL
- Private endpoint IPs for each Foundry service

---

## Known Issue: Provider Registration in Managed Subscriptions

The azurerm provider by default tries to register resource providers at startup.
In managed subscriptions, users often lack `*/register/action`.

**Fix (already applied to both modules):**
```hcl
provider "azurerm" {
  skip_provider_registration = true
  features { ... }
}
```

Required providers still need to be registered by a subscription admin. Check before deploying:
```powershell
az provider show --namespace Microsoft.Compute --query registrationState -o tsv
# Must be "Registered"
```

---

## Post-Deploy Verification

```powershell
# Check final Fabric-private outputs
Set-Location "C:\github\azure-network-platform\Fabric-private"
terraform output
```

**Key outputs to verify:**
- `fabric_workspace_id` — workspace GUID (format: `4f44a9c1-...`)
- `workspace_private_endpoint_ip` — should be `172.20.80.5`
- `lakehouse_sql_connection_string_private_link` — contains `.z4f.datawarehouse.fabric.microsoft.com` (z{xy} format for SSMS on private network)
- `mpe_keyvault_id`, `mpe_sql_id`, `mpe_storage_id` — all three should be populated

**Workspace URL:**  
`https://app.fabric.microsoft.com/groups/{fabric_workspace_id}`  
Access requires VPN or Bastion (deny-public is active on `inbound_and_outbound` mode).

**Bastion host:**  
`bastion-host00-sece` in `rg-net00-sece-{suffix}`  
Connect via Azure Portal → Bastion. Use VM credentials from KV `kv00-sece-{suffix}`.

**SQL connection string (private — SSMS):**  
Use `lakehouse_sql_connection_string_private_link` output.  
Format: `{workspace-encoded}.z{xy}.datawarehouse.fabric.microsoft.com`  
Port: 1433. Requires VPN or Bastion. Regular (non-z{xy}) format will fail from private network.

---

## Timing Reference

| Module | Resources | Typical Time | Notes |
|--------|-----------|--------------|-------|
| Networking init | — | ~2 min | Providers from cache |
| Networking apply | 579 | ~55 min | modtm is the long pole (~30 min); vHub+Firewall ~20 min |
| Foundry-byoVnet init | — | ~30 sec | |
| Foundry-byoVnet apply | ~30-40 | ~20-25 min | PE transients may add 1 retry |
| **Total** | **~620** | **~80 min** | |

---

## See Also

- `.squad/skills/lz-teardown/SKILL.md` — reverse this process
- `setSubscription.ps1` — sets ARM_SUBSCRIPTION_ID env var for providers (run every session)
- `.squad/decisions/inbox/donut-deploy-2026-05-07.md` — subscription mismatch incident + provider registration blockers
