# SKILL: Landing Zone Teardown

**Owner:** Donut (Infra Dev)
**Last updated:** 2026-05-08  
**Validated:** Full cycle on 2026-04-30 (37 + 944 resources destroyed, ~70 min, two regions); 2026-05-08 (32 + 579 resources, ~75 min, one region)

---

## Purpose

Documents the proven teardown sequence for this Azure Network Platform repo. Required reading before running `terraform destroy` on any module, especially Networking.

---

## State Discovery

Before destroying anything, check what's actually deployed:

```powershell
$modules = @("Foundry-byoVnet", "Foundry-managedVnet", "Fabric-private", "ContainerApps-byoVnet", "Networking")
foreach ($mod in $modules) {
    $statePath = "C:\github\azure-network-platform\$mod\terraform.tfstate"
    if (Test-Path $statePath) {
        $state = Get-Content $statePath | ConvertFrom-Json
        $resourceCount = if ($state.resources) { $state.resources.Count } else { 0 }
        Write-Host "$mod : $resourceCount resources"
    } else {
        Write-Host "$mod : NO STATE FILE"
    }
}
```

**Key distinction:** A state file with only `terraform_remote_state` + `random_string` resources means no Azure resources were deployed — destroy is instant and needs no SAL cleanup.

---

## Required Destroy Order

**App LZs must be destroyed BEFORE Networking.** Subnet service association links (SALs) and private endpoint (PE) DNS zone group links block subnet deletion if still attached.

```
1. Foundry-byoVnet      (if deployed)
2. Foundry-managedVnet  (if deployed)
3. Fabric-private       (if deployed)
4. ContainerApps-byoVnet (if deployed)
5. Networking           (LAST — always)
```

---

## Pre-Destroy Orphan Resource Check

**Run this before `terraform destroy` on any app LZ module.** In demo/lab environments, manually-created resources (test PEs, NICs, BotServices) may exist in the same RG and aren't tracked in Terraform state. They WILL block subnet cleanup.

```powershell
# Check for non-Terraform resources in the Foundry RG before destroy
# (get RG name from terraform output or state)
$rg = (terraform output -raw resource_group_id).Split('/')[-1]
az resource list --resource-group $rg --query "[].{type:type, name:name}" -o table
```

If any private endpoints, NICs, or unexpected resources appear, delete them before running destroy:
```powershell
az network private-endpoint delete --resource-group $rg --name <pe-name>
az resource delete --resource-group $rg --resource-type "Microsoft.BotService/botServices" --name <name>
```

---

## App LZ Destroy Pattern

Standard:
```powershell
cd C:\github\azure-network-platform\<module>
terraform destroy -auto-approve
```

### Foundry-byoVnet SAL gotcha (when Azure resources ARE deployed)

After `terraform destroy`, the AI Foundry resource enters soft-delete (7-day retention). The subnet service association link (`legionservicelink`) holds for 5–10 minutes post-purge. Pattern:

```bash
# 1. Destroy Foundry module
terraform destroy -auto-approve

# 2. Purge soft-deleted Cognitive Services (required before Networking destroy)
az cognitiveservices account list-deleted \
  --query "[].{name:name, location:location, resourceGroup:resourceGroup}"

az cognitiveservices account purge \
  --location <location> \
  --resource-group <rg> \
  --name <name>

# 3. Wait 5-10 min for legionservicelink to clear, then proceed to Networking destroy
# Poll: az network vnet subnet show ... --query "serviceAssociationLinks"
```

### legionservicelink variant: Stale Container Apps link

If subnet destroy fails with `legionservicelink` AND `linkedResourceType: Microsoft.App/environments` (not Cognitive Services), the link is from a Container Apps Environment that was deployed into the subnet during testing.

Check which type the link is:
```powershell
az network vnet subnet show \
  --resource-group <rg> --vnet-name <vnet> --name <subnet> \
  --query 'serviceAssociationLinks[].{type:linkedResourceType, allowDelete:allowDelete}' -o json
```

- **`Microsoft.CognitiveServices/accounts`** → Foundry soft-delete path above.
- **`Microsoft.App/environments`** → find and delete the Container Apps Environment:
  ```powershell
  az containerapp env list --query "[?properties.vnetConfiguration.infrastructureSubnetId=='<subnet-id>']"
  # If a CAE exists: delete it, then wait for link to clear
  # If list is empty (CAE already deleted): link is stale phantom — wait ~5 min for Azure propagation
  ```
  **Do NOT attempt:** REST DELETE on the serviceAssociationLink directly — ARM returns `UnauthorizedClientApplication` (409). The CA service must remove its own links. Waiting is the only option.
  **Do NOT attempt:** `az network vnet subnet update --remove delegations` while link exists — Azure blocks with `SubnetMissingRequiredDelegation`.
  Poll until `serviceAssociationLinks` returns null/empty, then re-run `terraform destroy`.

---

## AI Foundry Soft-Delete Check

Always run before Networking destroy (even if you think Foundry wasn't deployed — a partial deploy can leave a soft-deleted resource):

```bash
az cognitiveservices account list-deleted \
  --query "[].{name:name, location:location, resourceGroup:resourceGroup}" -o table
```

If results are empty, proceed immediately to Networking destroy.

---

## Networking Destroy

```powershell
cd C:\github\azure-network-platform\Networking
terraform destroy -auto-approve
```

### ⏱ Timing expectations

| Phase | Duration | Notes |
|---|---|---|
| modtm state refresh | ~30 min | 181 outbound GitHub API calls — **do not kill the process** |
| Azure resource deletion | ~14 min | Actual Azure API calls |
| vHub deletion | ~10-11 min | Normal, expect "Still destroying..." messages |
| vWAN deletion | ~12s | Fast after vHub is gone |
| RG deletion | ~11s | |
| **Total** | **~44 min** | One region + firewall config |

### What "stuck" looks like vs. "working"

The modtm refresh phase produces **no visible new output for ~30 minutes** while looking like this:

```
module.region0.module.private_dns[0].data.modtm_module_source.telemetry[0]: Reading...
module.region0.module.private_dns[0].module.regions.data.modtm_module_source.telemetry[0]: Reading...
```

**This is normal.** Verify the process is alive:
```powershell
Get-Process | Where-Object { $_.Name -like "*terraform*" } | Select-Object Name, CPU
```
If CPU is >10, it's working. If CPU is 0 for >5 min, something may be wrong.

### vHub InternalServerError (if it occurs)

Known transient error during vHub destroy or DNS policy link operations. Documented pattern:
```bash
# 1. Remove the failed resource from state
terraform state rm module.region0.azurerm_virtual_hub.hub

# 2. Delete directly via REST API or portal
az rest --method DELETE --url "https://management.azure.com/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/virtualHubs/{name}?api-version=2023-09-01"

# 3. Re-run terraform destroy to clean up remaining resources
terraform destroy -auto-approve
```

---

## Post-Destroy Verification

```bash
# Check for orphan RGs matching our naming pattern
az group list --query "[?starts_with(name, 'rg-')].name" -o tsv
```

**Our naming pattern:** `rg-{type}-{region_abbr}-{random_suffix}` (e.g., `rg-net00-sece-7768`)

**Pre-existing RGs to ignore** (not created by this project):
- `Default-ActivityLogAlerts` — Azure Monitor platform RG
- `NetworkWatcherRG` — Azure Network Watcher platform RG
- `rg-shared00-krok`, `rg-arc00-krok` — pre-existing (no region_abbr/suffix in name)
- `McapsGovernance` — Azure governance

If you see an `rg-*-{region_abbr}-{4digit_suffix}` pattern remaining — that's an orphan. Report to Ryan, don't auto-delete.

---

## Fabric-private Destroy — Two-Phase Pattern (PROVEN 2026-07-19)

Use this when `restrict_workspace_public_access = true` was applied (deny-public in effect).

### Phase 1 — Pre-flight and main destroy

```powershell
$workspaceId = "<workspace-guid>"
$token = (az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }

# Step 1: Flip inbound policy to Allow
$body = '{"inbound":{"publicAccessRules":{"defaultAction":"Allow"}}}'
Invoke-WebRequest -Uri "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/networking/communicationPolicy" -Headers $headers -Method PUT -Body $body -ContentType "application/json"
# NOTE: Policy GET will show Allow immediately, but data-plane enforcement continues ~5–8 min.
# Do NOT proceed until the MPE list endpoint is actually accessible.

# Step 2: Poll MPE list until accessible (retry with 20s sleeps)
for ($i = 1; $i -le 10; $i++) {
    $result = az rest --method GET --url "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/managedPrivateEndpoints" --resource "https://api.fabric.microsoft.com" 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Host "MPE endpoint accessible"; break }
    Write-Host "[$i] still blocked. waiting 20s..."; Start-Sleep -Seconds 20
}

# Step 3: Delete all MPEs with retries (async — poll until gone, don't trust 200 alone)
$mpes = ($result | ConvertFrom-Json).value
foreach ($mpe in $mpes) {
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        $r = az rest --method DELETE --url "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/managedPrivateEndpoints/$($mpe.id)" --resource "https://api.fabric.microsoft.com" 2>&1
        if ($LASTEXITCODE -eq 0) { break }
        Start-Sleep -Seconds 15
    }
}
# Poll until list returns 0 MPEs
for ($i = 1; $i -le 10; $i++) {
    $check = az rest --method GET --url "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/managedPrivateEndpoints" --resource "https://api.fabric.microsoft.com" 2>&1
    if ($LASTEXITCODE -eq 0 -and ($check | ConvertFrom-Json).value.Count -eq 0) { Write-Host "All MPEs gone"; break }
    Start-Sleep -Seconds 20
}

# Step 4: State-rm MPEs + approve actions from Terraform state
cd C:\github\azure-network-platform\Fabric-private
terraform state rm "fabric_workspace_managed_private_endpoint.mpe_keyvault[0]"
terraform state rm "fabric_workspace_managed_private_endpoint.mpe_sql[0]"
terraform state rm "fabric_workspace_managed_private_endpoint.mpe_storage[0]"
terraform state rm "azapi_resource_action.approve_mpe_keyvault[0]"
terraform state rm "azapi_resource_action.approve_mpe_sql[0]"
terraform state rm "azapi_resource_action.approve_mpe_storage[0]"

# Step 5: First destroy run (handles all resources except workspace — which will fail on inbound policy)
terraform destroy -refresh=false -auto-approve
# Expected: workspace delete will fail with RequestDeniedByInboundPolicy even with Allow policy set.
# KV soft-delete takes ~10 min — this is normal.
```

### Phase 2 — Workspace + cleanup

```powershell
# Step 6: Delete workspace directly via REST (poll until accessible)
for ($i = 1; $i -le 15; $i++) {
    try {
        $r = Invoke-WebRequest -Uri "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId" -Headers $headers -Method DELETE -ErrorAction Stop
        Write-Host "Workspace deleted (HTTP $($r.StatusCode))"; break
    } catch { Write-Host "[$i] blocked. waiting 30s..."; Start-Sleep -Seconds 30 }
}

# Step 7: State-rm workspace and finish destroy
cd C:\github\azure-network-platform\Fabric-private
terraform state rm fabric_workspace.workspace
terraform destroy -refresh=false -auto-approve
# Destroys: azurerm_fabric_capacity + azurerm_resource_group + random_string
```

### ⏱ Fabric-private timing (with deny-public)

| Phase | Duration |
|---|---|
| Allow policy flip propagation | 5–8 min (poll until MPE accessible) |
| MPE deletions + polling | ~2 min |
| First destroy (most Azure resources + KV soft-delete) | ~11 min (KV is long pole at ~10 min) |
| Workspace REST delete (poll until accessible) | variable, up to ~15 min post-flip |
| Final destroy (capacity + RG) | ~2 min |
| **Total** | **~20 min** |

### Key gotchas (discovered 2026-07-19)

- `communicationPolicy GET` shows Allow immediately after flip. **Do not trust it** — data-plane enforcement continues 5–8 min. Always poll the actual data-plane endpoint.
- Policy enforcement is **inconsistent during propagation** — same endpoint can return 200 on one call and 403 on the next. Retry loops with 15–30s sleeps are mandatory.
- `fabric_workspace` DELETE is **data-plane** (not management-plane like communicationPolicy). It remains blocked longer than the MPE endpoints. Budget up to ~15 min post-flip for it to clear.
- MPE DELETE returning 200 does **not** guarantee deletion. Poll the list endpoint until the MPE is absent.

---

## Known Issues Log

| Date | Issue | Workaround |
|---|---|---|
| 2026-04-27 | DNS resolver policy VNet link InternalServerError during deploy (not destroy) | Re-apply, resolves in ~15s |
| 2026-04-27 | vHub InternalServerError during destroy | terraform state rm + REST DELETE + re-apply |
| Prior cycles | legionservicelink 5-10 min hold post-Foundry-purge | Wait + poll `serviceAssociationLinks` |
| 2026-07-16 | None — clean cycle | — |
| 2026-07-19 | Fabric workspace DELETE blocked by inbound policy even after Allow flip | Two-phase destroy pattern — see above |
| 2026-07-19 | MPE DELETE 200 but resource still visible | Poll list until absent, retry DELETE if still present |
| 2026-04-30 | Networking destroy exits code 1 mid-run: `dial tcp: lookup management.azure.com: no such host` on async DNS zone delete poll | Client-side DNS blip only. Verify connectivity, re-run `terraform destroy -refresh=false -auto-approve`. No state surgery needed — Terraform resumes from remaining state. |
| 2026-05-08 | Foundry-byoVnet subnet deletion blocked by orphan testing PEs/NICs/BotService in RG | Run orphan resource check before destroy (see above). Delete orphans via az CLI, then re-run. |
| 2026-05-08 | `legionservicelink` on `ai-foundry-subnet-sece` from stale Container Apps Environment (CAE already deleted, no CAE in listing) | Wait ~5 min. ARM automatically clears the link after CAE deletion propagates. Direct REST DELETE returns 409 `UnauthorizedClientApplication` — do not attempt. |
