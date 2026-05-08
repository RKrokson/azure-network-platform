# Decisions Archive

Decisions older than 7 days, archived from decisions.md.

**Reverses:** Incorrect decision from 2026-04-28 ("Fabric private links are tenant-scoped only")
**Corrected by:** Ryan Krokson via `copilot-directive-fabric-workspace-pe-correction.md`

       "apiVersion": "2024-06-01",
       "name": "<resource-name>",
       "location": "global",
       "properties": {
         "tenantId": "<tenant-id>",
         "workspaceId": "<workspace-id>"
       }
     }
     ```

4. **Private Endpoint:** Create a standard Azure private endpoint targeting the above resource. Key parameters:
   - **Resource type:** `Microsoft.Fabric/privateLinkServicesForFabric`
   - **Target sub-resource (group_id):** `workspace`
   - **DNS zone:** `privatelink.fabric.microsoft.com`
   - The docs note that **at least 10 IP addresses** should be reserved per workspace PE (currently 5 IPs are allocated per PE).

5. **Deny public access (optional but required for our use case):** Set the workspace communication policy via the Fabric data-plane REST API:
   ```
   PUT https://api.fabric.microsoft.com/v1/workspaces/{workspaceID}/networking/communicationPolicy
   Body: {"inbound":{"publicAccessRules":{"defaultAction":"Deny"}}}
   ```
   This takes up to **30 minutes** to take effect per Microsoft docs.

**Source:** [Private links for Fabric tenants (overview)](https://learn.microsoft.com/en-us/fabric/security/security-private-links-overview) — provides context on tenant-level vs workspace-level scoping and limitations.

### Critical distinction: This is NOT the same as tenant-level private link

Tenant-level private link uses `Microsoft.PowerBI/privateLinkServicesForPowerBI` and affects **all** workspaces. Workspace-level uses `Microsoft.Fabric/privateLinkServicesForFabric` and targets a **single workspace**. These are completely different ARM resource types. Donut's original error was conflating these two.

| Private Link Service (anchor) | **azapi** | `Microsoft.Fabric/privateLinkServicesForFabric@2024-06-01` | No `azurerm` resource exists for this type. `azapi` is the only declarative option. |
| Private Endpoint | **azurerm** | `azurerm_private_endpoint` | Standard PE pattern, consistent with `pe_fabric_kv` already in `fabric.tf`. `group_id` = `workspace`. |
| DNS zone group on PE | **azurerm** (inline) | `private_dns_zone_group` block on the PE | Links to Networking's `privatelink.fabric.microsoft.com` zone. |
| Deny public access | **terraform_data + local-exec** | Fabric REST API | Already implemented in `workspace-policy.tf`. No changes needed — just needs the PE to exist first. |

### Where the PE lands

The private endpoint goes into the **existing `pe_subnet`** in the Fabric spoke VNet (`azurerm_subnet.pe_subnet`). This is the same subnet hosting the KV PE. The /24 subnet (256 IPs) has plenty of room for the 5 IPs the workspace PE allocates.

### DNS zone

Zone: `privatelink.fabric.microsoft.com`
- Already created by the **Networking** module (centralized DNS pattern).
- Already exposed as `dns_zone_fabric_id` output.
- Already validated by `check "fabric_dns_zone_present"` in `main.tf`.
- **No new DNS zone needed.** The PE's `private_dns_zone_group` will reference `data.terraform_remote_state.networking.outputs.dns_zone_fabric_id`.

### Dependency chain

```
azurerm_fabric_capacity → fabric_workspace → azapi_resource (PL service) → azurerm_private_endpoint (workspace PE) → terraform_data (deny public access)
```

The existing `workspace-policy.tf` already has `depends_on = [fabric_workspace.workspace]`. Donut must update this to depend on the **workspace PE** instead, ensuring the private path is live before public access is denied.

| 1 | `fabric.tf` | **Modify** | Remove the incorrect comment block. Add: (a) `azapi_resource` for `Microsoft.Fabric/privateLinkServicesForFabric@2024-06-01` — global resource, binds tenant_id + workspace_id; (b) `azurerm_private_endpoint` targeting the PL service with `subresource_names = ["workspace"]`, landing in `pe_subnet`, with `private_dns_zone_group` referencing `dns_zone_fabric_id`. |
| 2 | `workspace-policy.tf` | **Modify** | Update `depends_on` from `fabric_workspace.workspace` to the new workspace PE resource. This ensures the private inbound path is live before public deny takes effect. |
| 3 | `variables.tf` | **No change expected** | `restrict_workspace_public_access` already defaults to `true`. No new variables needed. |
| 4 | `outputs.tf` | **Modify** | Add outputs: `workspace_private_link_service_id`, `workspace_private_endpoint_id`, `workspace_private_endpoint_ip`. |
| 5 | `main.tf` | **No change expected** | `check "fabric_dns_zone_present"` already validates the DNS zone. |
| 6 | `README.md` | **Modify** | Document the workspace PE, tenant prerequisite, and the "deny public access" flow. |

| `azapi_resource.fabric_private_link_service` | `fabric-pls-3886` | `Microsoft.Fabric/privateLinkServicesForFabric@2024-06-01`, location: global, binds tenant + workspace |
| `azurerm_private_endpoint.pe_fabric_workspace` | `fabric-workspace-pe-3886` | Lands in `pe_subnet`, DNS: `privatelink.fabric.microsoft.com`, subresource: `workspace` |

**PE Private IP:** `172.20.80.5`

### Files changed

| File | Change |
|---|---|
| `Fabric-private/fabric.tf` | Removed wrong comment block. Added `azapi_resource.fabric_private_link_service` + `azurerm_private_endpoint.pe_fabric_workspace`. Added `schema_validation_enabled = false` to azapi resource. |
| `Fabric-private/workspace-policy.tf` | Updated `depends_on` from `fabric_workspace.workspace` → `azurerm_private_endpoint.pe_fabric_workspace`. |
| `Fabric-private/outputs.tf` | Added `workspace_private_link_service_id`, `workspace_private_endpoint_id`, `workspace_private_endpoint_ip`. |
| `Fabric-private/README.md` | Added 30-min propagation callout. Updated Outputs table. |

### Terraform plan summary

- **3 added:** `fabric_private_link_service`, `pe_fabric_workspace`, `approve_mpe_storage` (drift)
- **1 changed:** `azurerm_storage_account.lab_storage` (drift)
- **1 destroyed:** `approve_mpe_storage` replacement (drift)
- **No workspace replacement.** `fabric_workspace.workspace` unchanged.

### Apply outcome

Success. Resources created cleanly:
- `azapi_resource.fabric_private_link_service`: created in 24s
- `azurerm_private_endpoint.pe_fabric_workspace`: created in 56s

### 2026-04-28T23:53Z: Fabric next-round scope clarifications

**By:** Ryan (via Copilot)

**Context:** Pre-design brief for Carl's next design pass on Fabric-private. Scope confirmed before teardown completes.

**Decisions:**

1. **Lakehouse:** Add a **native Fabric Lakehouse** (OneLake-backed, `fabric_lakehouse` resource) inside the deployed workspace. NOT a shortcut to external ADLS Gen 2.

2. **Network mode conditional:** Three-way enum `network_mode`:
   - `inbound_only` — **default.** Workspace PE + communicationPolicy (deny public). No MPEs.
   - `outbound_only` — MPEs to storage/etc. only. No workspace PE. Workspace remains publicly reachable. **Niche / demo-only** scenario: customer is OK with public Fabric but needs to reach a private Azure resource.
   - `inbound_and_outbound` — both directions.
   - README must document `outbound_only` use case so future-self knows why it exists.

3. **Storage account upgrades for outbound (MPE) path:**
   - Storage account becomes ADLS Gen 2 (`is_hns_enabled = true`).
   - Enable Fabric **Workspace Identity** on the workspace.
   - Assign **Storage Blob Data Contributor** to the workspace identity SP on the storage account.
   - Shortcut creation is **out of scope** — Ryan will set up the shortcut manually. We're just enabling the prerequisites.

**Sequencing:** Carl designs first → Donut implements → Ryan validates. Hold until teardown completes.



# Design: Fabric-private Next Round — Lakehouse, network_mode, Storage Upgrades

**Author:** Carl (Lead / Architect)
**Date:** 2026-07-25
**Status:** Draft — pending Ryan approval
**Module:** `Fabric-private/`
**Branch target:** squad/fabric-alz-impl (new branch from current HEAD)

---

**Date:** 2026-04-30  
**Author:** Donut (Infrastructure Dev)  
**File:** `Fabric-private/terraform.tfvars`

## New Transients Observed (2026-04-30) — For Playbook

1. **`az login` account switch:** Always run `az account set --subscription <id>` after any `az login`
   call to restore the correct auth context before re-running apply.
2. **Workspace identity `InternalError`:** Transient on brand-new capacity. Resolved on first re-apply.
3. **MPE `UnknownError` (storage + SQL):** Transient Fabric MPE API error. Resolved within 2-3 re-applies.
   KV → storage → SQL is the typical resolution order.


