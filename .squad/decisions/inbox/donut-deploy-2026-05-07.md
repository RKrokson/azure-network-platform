# Deploy Decision Drop — Networking LZ + Foundry-byoVnet — 2026-05-07

**Author:** Donut (Infra Dev)  
**Date:** 2026-05-07  
**Status:** BLOCKED — deploy did not complete  
**Task:** Deploy Networking LZ + Foundry-byoVnet for Ryan's testing session  

---

## TL;DR

Deploy did not complete. Hit two hard auth blockers. Clean slate left — both subscriptions
empty, state files cleared. Code change committed (`skip_provider_registration = true` in
both Networking and Foundry-byoVnet). **Ryan needs to resolve one of the two auth paths
below before retrying.**

---

## What Got Attempted

| Phase | Result |
|-------|--------|
| Networking plan (b6b5dea5 — wrong sub) | Succeeded (579 adds, 0 destroy) |
| Networking apply (b6b5dea5 — wrong sub) | Partial — 762 resources in state, then AuthorizationFailed on Private DNS zones |
| Cleanup of wrong-sub resources | Complete — both RGs deleted |
| Networking plan (Picasso DevX — correct sub) | Failed — `Microsoft.Compute` not registered |
| Foundry-byoVnet | Not reached |

---

## Root Cause

### Issue 1: `ARM_SUBSCRIPTION_ID` was stale at system level

The system env var `ARM_SUBSCRIPTION_ID` was pointing to `ME-rykrokso-01` (b6b5dea5) — your
old personal subscription. The `az` CLI was set to Picasso DevX (2c9a60e6). These were out of
sync. Terraform's azurerm provider uses `ARM_SUBSCRIPTION_ID`, not the `az` CLI context.

**Result:** First apply went to the wrong subscription (b6b5dea5).

**Fix:** Always run `.\setSubscription.ps1` before ANY deploy session. It syncs the CLI and
the env var. Do not rely on a previously-set `ARM_SUBSCRIPTION_ID` without verifying.

---

### Issue 2: `Microsoft.Compute` not registered in Picasso DevX

After fixing the subscription mismatch, re-planning against Picasso DevX failed because
`Microsoft.Compute` (required for VMs) is not registered in that subscription. The user
`rykrokso@microsoft.com` does not have `*/register/action` permission to register it.

**What needs to happen:**
```powershell
# Requires subscription admin / Owner role:
az provider register --subscription 2c9a60e6-a5da-4586-be62-c54e06a745d2 --namespace Microsoft.Compute
az provider register --subscription 2c9a60e6-a5da-4586-be62-c54e06a745d2 --namespace Microsoft.OperationsManagement
az provider register --subscription 2c9a60e6-a5da-4586-be62-c54e06a745d2 --namespace Microsoft.SecurityInsights
```

Or if Picasso DevX has a subscription admin, ask them to run the above. The `skip_provider_registration = true`
change I've already committed handles the azurerm provider's auto-registration behavior — but
the providers still need to BE registered for actual resource creation to work.

---

### Issue 3 (secondary): Private DNS zone auth failure in b6b5dea5

If you want to go back to deploying on b6b5dea5 instead: the apply got very far (vHub, Firewall,
VMs, Bastion, DNS Resolver, KV all succeeded) but failed on `Microsoft.Network/privateDnsZones/read`
for three specific DNS zones (Purview, Power BI, CosmosDB) near the end.

**Likely cause:** Azure Policy at the management group level preventing Private DNS zone creation
for certain Microsoft service endpoints (standard corporate governance in MSIT). The AVM private
DNS module uses API version `2024-06-01` for azapi which may trigger the policy when the older
API version doesn't.

**Options for b6b5dea5 path:**
1. Check for Azure Policy denying `Microsoft.Network/privateDnsZones/write` in b6b5dea5
2. Or deploy with `add_private_dns00 = false` to skip the DNS resolver + zones entirely (core networking still works)
3. Or switch to `rykrokso@microsoft.com` having full Contributor on b6b5dea5 (if it's a guest account, permissions may be restricted vs. `ryan@krokson.xyz`)

---

## Code Changes Made (Already Committed)

### `Networking/config.tf` and `Foundry-byoVnet/config.tf`

Added `skip_provider_registration = true` to the `provider "azurerm"` block in both files.

**Why:** In managed subscriptions, the azurerm provider tries to register ~50 resource
providers at startup. Most users in enterprise subs don't have `*/register/action`. This
change is safe, non-breaking, and should be permanent — it's best practice for any
subscription you don't fully own.

**Before:**
```hcl
provider "azurerm" {
  features { ... }
}
```

**After:**
```hcl
provider "azurerm" {
  skip_provider_registration = true
  features { ... }
}
```

---

## Pre-Retry Checklist (for Ryan or next Donut session)

```powershell
# 1. Resolve provider registrations in Picasso DevX (needs subscription admin):
az provider register --subscription 2c9a60e6-a5da-4586-be62-c54e06a745d2 --namespace Microsoft.Compute

# 2. Verify sync:
az account show --query "{name:name,id:id}" -o json
# Must show Picasso DevX

.\setSubscription.ps1
# This sets ARM_SUBSCRIPTION_ID to match az account show

# 3. Verify ARM_SUBSCRIPTION_ID is correct:
echo $env:ARM_SUBSCRIPTION_ID
# Must be: 2c9a60e6-a5da-4586-be62-c54e06a745d2

# 4. Verify no orphan RGs:
az group list --subscription 2c9a60e6-a5da-4586-be62-c54e06a745d2 -o table

# 5. Verify state files are empty:
if (Test-Path "Networking\terraform.tfstate") { (Get-Content "Networking\terraform.tfstate" | ConvertFrom-Json).resources.Count } else { echo "clean" }

# 6. Re-run deploy:
cd Networking
terraform init -upgrade
terraform plan -out=tfplan   # Verify: 579 to add, 0 destroy
terraform apply tfplan
```

---

## Key Endpoints / Info for Testing

**Not available** — deploy did not complete. Once the above is resolved and deploy succeeds,
key outputs will include:
- `rg_net00_name` — networking resource group
- `vhub00_id` — virtual hub
- `firewall_private_ip00` — firewall private IP
- `dns_server_ip00` — private DNS resolver inbound IP
- `key_vault_name` — KV with VM credentials

For Foundry-byoVnet:
- AI Foundry endpoint URL
- Private endpoint IPs for Foundry services

---

## Timing (Actual)

- Deploy session: ~60 min (mostly cleanup + diagnosis, ~40 min Azure-side work before abort)
- Expected retry time after blockers resolved: ~75 min (Networking ~55 min, Foundry ~20 min)
