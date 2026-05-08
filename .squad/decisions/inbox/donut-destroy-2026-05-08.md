# Decision Drop: Foundry-byoVnet + Networking Teardown — 2026-05-08

**Author:** Donut (Infra Dev)  
**Date:** 2026-05-08  
**Type:** Operational record  
**Status:** Complete ✅

---

## Summary

Full teardown of yesterday's deployment (2026-05-07 Foundry-byoVnet + Networking) completed successfully.

- **When destroyed:** 2026-05-08, starting ~16:18 UTC, completed ~17:38 UTC
- **Total wall clock:** ~75 min
- **Resources destroyed:** Foundry-byoVnet (32), Networking (579) — total 611
- **Orphan resources remaining:** None. Both RGs gone. Both state files at 0.

---

## Environment Status

**Environment is now empty and ready for re-deploy when Ryan needs it.**

- `rg-ai00-sece-3771` — deleted ✅
- `rg-net00-sece-8759` — deleted ✅
- `az group list --query "[?location=='swedencentral']"` → empty ✅
- Foundry-byoVnet state: 0 resources ✅
- Networking state: 0 resources ✅

---

## Issues Encountered

### 1. Orphan Testing Resources in Foundry RG
Ryan had manually deployed several resources during testing that weren't tracked in Terraform state:
- `bot-pe`, `bot-token-pe`, `bot1-pe` — private endpoints
- `bot-pe-nic`, `bot-token-pe-nic`, `bot1-pe-nic` — associated NICs
- `test-flow47755` — BotService

These blocked subnet deletion in the first `terraform destroy` run. Cleaned up manually before retry.

### 2. Stale Container Apps Service Association Link
The `ai-foundry-subnet-sece` subnet had a delegation to `Microsoft.App/environments` (from a Container Apps Environment Ryan had deployed during testing). The CAE was already deleted but left a stale `legionservicelink` service association. Azure's ARM API returned `UnauthorizedClientApplication` (409) on direct REST DELETE — only the CA service can remove its own links. Waited ~5 min; Azure cleared it automatically after propagating the CAE deletion.

### 3. Retries
- Foundry-byoVnet: 2 attempts (1 failed on subnets, 1 clean after orphan cleanup + SAL propagation)
- Networking: 1 attempt (clean, exit 0)

---

## New Patterns Captured

Updated `.squad/skills/lz-teardown/SKILL.md` with:
1. Pre-destroy orphan resource check step
2. Container Apps stale legionservicelink scenario (distinct from Foundry soft-delete SAL)
