# Deploy Success — Networking LZ + Foundry-byoVnet (2026-05-07)

**Author:** Donut (Infrastructure Dev)  
**Date:** 2026-05-07  
**Status:** COMPLETE ✅  
**Sub:** ME-rykrokso-01 (`b6b5dea5-81d3-4e4a-85f3-b05266fc6f89`)  
**Tenant:** krokson.xyz (`16248402-a86b-4108-b48d-77125ee2029f`)  
**Identity:** ryan@krokson.xyz  
**Region:** swedencentral  
**Suffix:** 8759 (Networking), 3771 (Foundry)

---

## What Was Deployed

### Networking LZ — `rg-net00-sece-8759`

| Resource | Name |
|----------|------|
| Resource Group (networking) | `rg-net00-sece-8759` |
| Resource Group (KV) | `rg-kv00-sece-8759` |
| Virtual WAN | (in `rg-net00-sece-8759`) |
| Virtual Hub | `vhub00-sece` |
| Azure Firewall | private IP `172.30.0.132` |
| Key Vault | `kv00-sece-8759` |
| Log Analytics Workspace | `law00-sece` |
| Spoke VNets + Bastion + VMs | in `rg-net00-sece-8759` |
| Private DNS Resolver + zones | all 579 resources |

**Total resources:** 579  
**Apply time:** ~35 min  
**Retries:** 0

### Foundry-byoVnet — `rg-ai00-sece-3771`

| Resource | Name / ID |
|----------|-----------|
| Resource Group | `rg-ai00-sece-3771` |
| AI Foundry account | `aifoundry3771` |
| AI Foundry project | `project3771` |
| AI Search | `aifoundry3771search` |
| CosmosDB | `aifoundry3771cosmosdb` |
| Storage Account | `aifoundry3771storage00` |
| Spoke VNet | `ai-vnet-sece-3771` |
| vHub connection | `vhub00-to-ai-vnet-3771` |
| Private endpoints (3) | cosmosdb, storage, ai-search |
| GPT deployment | `gpt-5.4` on `aifoundry3771` |

**Total resources:** 32  
**Apply time:** ~25 min  
**Retries:** 0

---

## Key Endpoints / Info for Testing

### AI Foundry Studio
- URL: `https://ai.azure.com`
- Sign in as ryan@krokson.xyz
- Switch to hub `aifoundry3771` → project `project3771` in Sweden Central
- GPT model deployed: `gpt-5.4` (deployment name `gpt-5.4`)

### AI Foundry Resource IDs
```
AI Foundry:   /subscriptions/b6b5dea5.../resourceGroups/rg-ai00-sece-3771/providers/Microsoft.CognitiveServices/accounts/aifoundry3771
Project:      /subscriptions/b6b5dea5.../resourceGroups/rg-ai00-sece-3771/providers/Microsoft.CognitiveServices/accounts/aifoundry3771/projects/project3771
AI Search:    /subscriptions/b6b5dea5.../resourceGroups/rg-ai00-sece-3771/providers/Microsoft.Search/searchServices/aifoundry3771search
```

### Networking
- Firewall private IP: `172.30.0.132`
- KV (VM credentials): `kv00-sece-8759` in `rg-kv00-sece-8759`
- Bastion: `bastion-host00-sece` in `rg-net00-sece-8759`

### Azure Portal Quick Links
- Foundry RG: `https://portal.azure.com/#@krokson.xyz/resource/subscriptions/b6b5dea5-81d3-4e4a-85f3-b05266fc6f89/resourceGroups/rg-ai00-sece-3771`
- Networking RG: `https://portal.azure.com/#@krokson.xyz/resource/subscriptions/b6b5dea5-81d3-4e4a-85f3-b05266fc6f89/resourceGroups/rg-net00-sece-8759`

---

## Notes

- Private endpoints are deployed for CosmosDB, Storage, and AI Search — traffic stays on the private network.
- The Foundry spoke (`ai-vnet-sece-3771`) is connected to `vhub00-sece` via hub connection — fully routed.
- DNS resolver policy VNet link was created for the AI VNet (`vnet-link-to-dns-policy-ai-vnet-3771`).
- RBAC assignments are in place: Storage Blob Data Owner (Foundry project MSI) + CosmosDB SQL role.
- Capability host provisioned on `project3771` — required for agent/connected resources to function.

---

## What Was Also Cleaned Up

- Deleted stale inbox file `donut-deploy-2026-05-07.md` (tenant-specific lessons from a deploy that never completed).
- Reverted `skip_provider_registration = true` from both `Networking/config.tf` and `Foundry-byoVnet/config.tf` per Ryan's no-over-engineering directive.

---

## Destroy Notes (when done testing)

1. **Destroy Foundry-byoVnet first:** `cd Foundry-byoVnet && terraform destroy`
2. **Purge AI Foundry soft-delete** before destroying Networking — otherwise subnet service association blocks VNet deletion:
   ```powershell
   az cognitiveservices account purge --resource-group rg-ai00-sece-3771 --name aifoundry3771 --location swedencentral
   ```
3. **Then destroy Networking:** `cd Networking && terraform destroy`
4. If `terraform destroy` on Networking fails on DNS resolver policy VNet link — re-run. Known transient.
