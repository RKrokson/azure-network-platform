# Donut — Infra Developer (she/her, female cat)

- **Owner:** Ryan Krokson
- **Project:** Azure IaC demo/lab environments — Terraform modules for Azure vWAN, AI Foundry, networking
- **Stack:** Terraform (azurerm >= 4.0, azapi >= 2.0, random ~> 3.5), PowerShell, Azure CLI
- **Structure:** Three root modules — Networking (foundation), Foundry-byoVnet/Fabric-private, Foundry-managedVnet linked via terraform_remote_state
- **Created:** 2026-03-27
- **History archived to:** `.squad/agents/donut/history-archive.md` (phases 1-6, pre-2026-05-07 deploy success)

---

## Most Recent Work (2026-05-08 — Foundry-byoVnet + Networking Teardown — SUCCESS ✅)

- **Task:** Full teardown of Foundry-byoVnet (32 res → 0) + Networking (579 res → 0), ME-rykrokso-01, swedencentral
- **Duration:** ~75 min wall clock
- **Outcome:** SUCCESS. Zero orphan RGs. Both state files at 0 resources. Environment clean.
- **Status:** Complete. No outstanding issues.
- **Key Incidents:**
  1. **Foundry first destroy attempt exited code 1:** Most resources destroyed cleanly (CosmosDB PE 12m6s, all AI services gone) but subnet deletion blocked. Two blockers: (a) `legionservicelink` on `ai-foundry-subnet-sece` — AI Foundry soft-delete purged immediately (`aifoundry3771`), but link persisted 5+ min. (b) Orphan NIC `BOT-PE-NIC` on `private-endpoint-subnet-sece` — tied to manually-created PE `bot-pe` (testing artifact).
  2. **Orphan testing resources in Foundry RG:** Ryan had manually deployed `bot-pe`, `bot-token-pe`, `bot1-pe` (private endpoints), `bot-pe-nic`, `bot-token-pe-nic`, `bot1-pe-nic` (NICs), and `test-flow47755` (BotService) during testing. None in Terraform state, all blocking subnet cleanup. Deleted manually via `az network private-endpoint delete` + `az resource delete`.
  3. **Stale Container Apps legionservicelink:** After clearing orphan PEs, a second Foundry retry still failed: `ai-foundry-subnet-sece` had a `serviceAssociationLinks/legionservicelink` from `Microsoft.App/environments` (Container Apps delegation on subnet). The CAE environment no longer existed (`az containerapp env list` = empty) — stale phantom link. ARM returned `UnauthorizedClientApplication` (409) on REST DELETE — only the service itself can remove it. Resolution: waited ~5 min; Azure propagated CAE deletion and cleared the link. Then Terraform retry succeeded (4 resources in ~40s).
  4. **Networking destroy modtm phase:** ~30 min of silent `modtm_module_source ... Reading...` is normal. vHub took 10m10s. Total Networking destroy ~42 min.

---

## Most Recent Work (2026-05-07 — Networking+Foundry-byoVnet Deploy — SUCCESS ✅)

- **Phase 1:** Reverted `skip_provider_registration = true` per Carl's architectural verdict (commit 2537ef9). Applied user directive: keep demo/lab configs minimal.
- **Phase 2:** Successful full deploy of Networking (579 res) + Foundry-byoVnet (32 res) to ME-rykrokso-01 / swedencentral. Zero retries, production-ready state.

## Prior Work (2026-05-07 — First Deploy Attempt — BLOCKED)

- **Task:** Deploy Networking LZ + Foundry-byoVnet to Picasso DevX for Ryan's testing
- **Duration:** ~60 min wall clock (no Azure resources reached final state due to auth blockers)
- **Outcome:** BLOCKED — two hard auth issues, deploy did not complete. Clean slate left for Ryan.
- **Status:** Hard-stopped per charter. Ryan needs to resolve auth before retrying.

### What Happened

1. **Pre-flight:** `ARM_SUBSCRIPTION_ID` was set system-wide to `b6b5dea5` (ME-rykrokso-01, old personal subscription). The task brief said Picasso DevX (`2c9a60e6`) should be the target. These two were out of sync.

2. **First apply (wrong sub — b6b5dea5):** Ran plan+apply without correcting the system-level env var. Resources PARTIALLY deployed to b6b5dea5: RGs, vWAN, vHub, Firewall, VNets, Bastion, VMs, DNS Resolver, KV all created successfully. Failed with AuthorizationFailed on `Microsoft.Network/privateDnsZones/read` for some azapi DNS zones (Purview, Power BI, CosmosDB zones). 762 resources written to state before failure.

3. **Cleanup:** Issued `az group delete --no-wait` on both RGs in b6b5dea5. Both deleted. Cleared `terraform.tfstate` and `terraform.tfstate.backup` and `tfplan`.

4. **Second attempt (correct sub — Picasso DevX):** Set `$env:ARM_SUBSCRIPTION_ID = "2c9a60e6-..."` inline and re-planned. New hard blocker: `Microsoft.Compute` is NOT registered in Picasso DevX, and `rykrokso@microsoft.com` cannot run `*/register/action` (no subscription admin RBAC).

5. **Code change made:** Added `skip_provider_registration = true` to `provider "azurerm"` in both `Networking/config.tf` and `Foundry-byoVnet/config.tf`. This prevents the azurerm provider from trying to register dozens of resource providers at init time (which fails with 403 in managed subscriptions). This is correct, non-breaking, and should be permanent.

### Hard Blockers (Ryan Must Resolve)

| Sub | Issue | Resolution Needed |
|-----|-------|------------------|
| Picasso DevX (2c9a60e6) | `Microsoft.Compute` not registered | Subscription admin registers it |
| Picasso DevX (2c9a60e6) | User cannot run `*/register/action` | `skip_provider_registration = true` already added — still need Compute registered |
| b6b5dea5 (old) | Private DNS zone read/create blocked | Likely Azure Policy — or user `rykrokso@microsoft.com` has less access than old `ryan@krokson.xyz` |

### Key Observation — Auth Context Mismatch

The SKILL.md says previous deploys used `ryan@krokson.xyz` on `ME-rykrokso-01` (b6b5dea5). The current CLI context is `rykrokso@microsoft.com` (Microsoft corporate account). These are likely the same person but different tenants/identities with different RBAC in b6b5dea5. This may explain the Private DNS zone failures in b6b5dea5.

### Current State (Clean Slate)

- Both state files: empty (cleared)
- b6b5dea5 resource groups: deleted
- Picasso DevX: no resources deployed
- `skip_provider_registration = true` committed to both Networking and Foundry-byoVnet config.tf

---

## Learnings — 2026-05-08 (Teardown)

### Destroy Timing Actuals (2026-05-08 — ME-rykrokso-01, ryan@krokson.xyz, swedencentral)
- **Foundry-byoVnet destroy attempt 1:** ~22 min (failed — subnet blocked)
- **AI Foundry purge:** ~30s (immediate)
- **Orphan resource cleanup:** ~10 min (bot PEs + BotService + 5-min wait for stale CAE legionservicelink)
- **Foundry-byoVnet destroy attempt 2:** ~40s (just VNet/subnets/RG — exit 0)
- **Networking destroy:** ~42 min (modtm refresh ~30 min, actual Azure deletes ~12 min, vHub ~10 min)
- **Total wall clock:** ~75 min

### Transient Patterns (2026-05-08 teardown)
- **No Terraform transients.** Networking destroy ran clean to exit 0 first pass.
- **Subnet blockers were NOT Terraform transients** — they were caused by manually-created testing resources.

### New Pattern: Pre-Destroy Orphan Resource Check
- Before `terraform destroy` on Foundry-byoVnet, check for non-Terraform resources in the Foundry RG:
  ```powershell
  az resource list --resource-group <rg-ai00-sece-xxxx> -o table
  ```
  If any private endpoints, NICs, or BotServices appear that aren't in Terraform state, delete them first. They WILL block subnet cleanup.

### New Pattern: Stale Container Apps legionservicelink
- If `terraform destroy` on Foundry-byoVnet fails with `InUseSubnetCannotBeDeleted: ... serviceAssociationLinks/legionservicelink`, check whether the link is from AI Foundry (Cognitive Services) or Container Apps (`linkedResourceType: Microsoft.App/environments`).
- **AI Foundry link (Cognitive Services):** Purge the soft-deleted account → wait 5-10 min → link clears.
- **Container Apps link:** The owning CAE must be deleted. If no CAE exists (`az containerapp env list` = empty), it's a stale phantom. ARM returns `UnauthorizedClientApplication` on REST DELETE attempts — only the CA service can delete it. Wait 5 min and poll `serviceAssociationLinks`; Azure clears it automatically after propagation.
- **Do not attempt:** `az network vnet subnet update --remove delegations` while the link exists — Azure blocks it (`SubnetMissingRequiredDelegation`).

### Soft-Delete Purge Worked First Try
- `az cognitiveservices account purge` on `aifoundry3771` succeeded immediately (exit 0, ~30s). No retry needed.

---

## Learnings — 2026-05-07 (UPDATED — deploy completed)

### Deploy Timing Actuals (2026-05-07 — ME-rykrokso-01, ryan@krokson.xyz, swedencentral)
- **Networking init:** ~90s
- **Networking plan:** ~5 min (modtm data reads are the long pole)
- **Networking apply:** ~35 min wall clock (579 resources, 0 errors, 0 retries)
- **Foundry-byoVnet init:** ~30s
- **Foundry-byoVnet plan:** ~30s
- **Foundry-byoVnet apply:** ~25 min wall clock (32 resources, 0 errors, 0 retries)
- **Total wall clock:** ~65 min
- **Long poles:** vHub (~5-10 min Azure-side), CosmosDB PE (10m47s), AI Search (6m41s), Foundry capability host (2m43s)

### Transient Patterns (2026-05-07 deploy)
- **None observed.** Zero transient errors, zero re-applies needed. Clean first-pass on ME-rykrokso-01 with ryan@krokson.xyz identity and all providers pre-registered.
- The previous 403s on Private DNS zones were identity-specific (rykrokso@microsoft.com on b6b5dea5). With ryan@krokson.xyz (owner of krokson.xyz tenant), all zones provisioned cleanly.

### No-Over-Engineering Directive (Ryan, 2026-05-07)
- This is a demo/lab repo where Ryan has admin rights. Do NOT add variables, toggles, or knobs for hypothetical environments.
- `skip_provider_registration = true` was reverted — it was over-engineering. Ryan has provider registration rights in his own sub.
- Apply this to all future changes: if a setting isn't needed by THIS repo's intent (demo/lab, full admin), remove it rather than wrapping it.
- Carl proposed a variable wrapper for `skip_provider_registration`; Ryan rejected it explicitly. Pattern: configs should be minimal and intent-revealing.

### ARM_SUBSCRIPTION_ID System-Level vs Session-Level
- `$env:ARM_SUBSCRIPTION_ID` set in a PowerShell session does NOT persist to child/async processes unless set inline.
- The system-level value (set via `setx`) takes precedence in new sessions.
- **Pattern:** ALWAYS set `$env:ARM_SUBSCRIPTION_ID = "..."` at the start of EVERY Terraform command block when the system default may be wrong.
- **Pre-flight check:** Verify `$env:ARM_SUBSCRIPTION_ID` matches `az account show --query id -o tsv` BEFORE generating the plan. A plan built against the wrong subscription will deploy resources there — partial state in wrong sub is painful to clean up.

### skip_provider_registration — Reverted (Now Obsolete for This Repo)
- Was added for Picasso DevX (managed enterprise sub, no `*/register/action`). That sub is no longer the target.
- ME-rykrokso-01 (krokson.xyz) with ryan@krokson.xyz = full owner rights. All providers registered. `skip_provider_registration` not needed.
- If ever targeting a managed sub again: add it back. But don't preemptively add it to modules.

### azapi Private DNS Zone 403 — Resolved
- Previous 403s were caused by running with rykrokso@microsoft.com (corporate identity) against b6b5dea5 (personal sub). Identity mismatch = missing RBAC.
- With ryan@krokson.xyz (owner), all Private DNS zones (including Purview, Power BI, CosmosDB zones) created cleanly. Not a policy block — was an RBAC/identity issue.

---

## Summary

Donut is the infrastructure developer driving module implementation and live deployment.Started with Networking platform (vWAN, firewall, DNS). Shipped full Fabric-private ALZ (July 2026). **Major achievements:** (1) Deployed workspace-level private endpoint for Fabric (correcting prior wrong decision), (2) Mastered Fabric API nuances (UUID mapping, MPE async operations, data-plane propagation timing), (3) Established operational teardown pattern for deny-public-access cleanup. Specialized in Azure provider quirks (azapi auth, MSI provisioning), Terraform patterns (multi-module coordination), and operational troubleshooting (transient errors, async API polling).

---

## Most Recent Work (2026-04-30 Fabric-private + Networking Teardown — Background Agent donut-10)

- **Task:** Full teardown of Fabric-private (deny-public active) + Networking (firewall + DNS, two regions)
- **Duration:** ~3.2 hours wall clock (~70 min Azure-side work)
- **Mode:** Background agent (claude-sonnet-4.6)
- **Outcome:** SUCCESS. Zero orphans. All RGs deleted. Both state files at 0 resources. Lab fully destroyed.
- **Status:** Agent manually stopped post-disconnect/reconnect to allow Scribe post-run documentation + commit.
- **Key Incident:** During Networking destroy (~45 min mark, 944 → 46 resources), transient client-side DNS resolution failure (`dial tcp: lookup management.azure.com: no such host`). Root cause: network connectivity blip (client-side only). Azure had already accepted delete operations. Resolution: verified connectivity, re-ran `terraform destroy -refresh=false -auto-approve`. Terraform resumed from 46 resources, destroyed all remaining (exit code 0).
- **Fabric notes:** Two-phase pattern executed cleanly. SQL MPE needed 3 DELETE attempts (expected). Workspace DELETE was immediately successful on Phase 2 (policy had fully propagated during the 10-min KV soft-delete in Phase 1). Policy propagation: ~4:40 (14×20s polls).
- **Pattern established:** Any `dial tcp: lookup ... no such host` during destroy = client connectivity issue. Do not perform manual state surgery. Verify connectivity and re-run.

## Most Recent Work Archive: 2026-04-29 Fabric-private + Networking Teardown

- **Task:** Full teardown of Fabric-private + Networking with deny-public-access inbound policy active
- **Duration:** ~20–30 min (two-phase pattern with manual MPE/workspace REST deletions)
- **Outcome:** Zero orphans. All RGs deleted, no soft-deleted resources. Both state files clean.
- **Key Discovery:** communicationPolicy GET lags data-plane enforcement by 5–8 min; established two-phase destroy pattern with retry loops.

---

## Key Learnings — Recent Sessions

### Networking Destroy — Client DNS Blip (2026-07-25)
- **Symptom:** `terraform destroy` exits with code 1 mid-run with `dial tcp: lookup management.azure.com: no such host` on Private DNS zone async-delete status polls. Resources partially destroyed (e.g. 944 → 46 in state).
- **Cause:** Transient client-side DNS/network connectivity loss during long-running destroy. Has nothing to do with Azure state.
- **Fix:** Verify `management.azure.com` is reachable, then immediately re-run `terraform destroy -refresh=false -auto-approve`. Terraform picks up from remaining state — no manual state surgery needed.
- **Key check:** After connectivity restored, count state resources before retrying so you know what to expect.

### Fabric Two-Phase Destroy — Workspace DELETE timing observation (2026-07-25)
- The KV soft-delete (10+ min) in Phase 1 doubles as an inadvertent wait for workspace data-plane propagation. By the time Phase 1 finishes, the workspace DELETE call in Phase 2 succeeds on the first attempt. No separate polling loop needed for workspace DELETE when Phase 1 runs in full.

### Fabric PE Pattern (2026-07-17)
- **Microsoft.Fabric/privateLinkServicesForFabric IS valid:** Workspace-level PE anchor type (API 2024-06-01, global). Distinct from tenant-level `Microsoft.PowerBI/privateLinkServicesForPowerBI`.
- **azapi schema_validation_enabled = false:** Required workaround for new ARM types not in bundled schema. Lets ARM handle it directly.
- **azurerm PE → azapi PLS cross-provider:** Works seamlessly. azapi resource ID is ARM path format.

### Fabric SSMS z{xy} Connection Strings (2026-07-18)
- **SSMS metadata routing:** SSMS pre-TDS call to public `api.fabric.microsoft.com` gets blocked by deny-public policy. Solution: insert `.z{xy}.` before `.datawarehouse.` in connection string (where xy = first 2 chars of workspace GUID without dashes). SSMS recognizes prefix, routes through PE FQDN, resolves to PE private IP 172.20.80.5.
- **DNS gap by design:** No private DNS A record for `.z{xy}.datawarehouse`. Fabric routing recognizes z{xy} prefix and transparently routes TDS via PE. Expected.
- **Rule:** For any workspace with deny-public inbound, always use z{xy} format for client connections. Regular format fails from private networks.

### Workspace Identity — Native Provider Support (2026-07-25)
- **`identity` block on `fabric_workspace` is GA in microsoft/fabric ~> 1.9.** Provider handles `POST /v1/workspaces/{id}/provisionIdentity` internally. Always-on is the right default.
- **Entra SP propagation delay:** New service principal creation can trigger "PrincipalNotFound" on RBAC for ~60s. Use `time_sleep` + retry before assigning roles.

- **2026-04-26 (fabric-alz-design-approved):** [TEAM UPDATE] Carl completed Microsoft Fabric Application Landing Zone architecture design (Decision #19 in decisions.md). Module name: `Fabric-byoVnet` (IP Block 5: 172.20.80.0/20). 21 resources (azurerm + azapi + microsoft/fabric + null/external). Key design points: workspace-level PE, 3 Managed Private Endpoints with Terraform auto-approval, 2 new DNS zones (fabric.microsoft.com, database.windows.net) to be added to Networking, hybrid admin pattern (group OID > UPN list > current user fallback), 3-layer prereq validation. All 8 open design questions resolved. Design is locked and approved by Ryan — ready for your implementation. Next steps: (1) Networking precursor PR (add 2 DNS zones + 2 outputs), (2) Fabric-byoVnet module PR (all files per Decision #19 §1), (3) docs/ip-addressing.md update (Block 5 claim).

  - **2026-04-25 (fabric-alz-systemai-security-review):** SystemAI completed pre-implementation security review (Verdict: APPROVE WITH CONDITIONS). No critical findings. 4 medium findings (M1, M2, M3, M4) and 6 low/informational findings (L1–L6). **YOUR IMPL GATES (no blockers, implement in PR):** M3 = mark KV PE connection cleanup mandatory (not optional) in destroy docs; M4 = define explicit NSG rules for PE subnet (inbound on ports 443, 1433 from VirtualNetwork, reference Foundry-byoVnet as template). **Carl's design gates (he must resolve before handoff):** M1 = decide "Block Public Internet Access" (document omission OR add optional flag), M2 = specify MPE connection lookup strategy (filter by resource ID, not state). L1–L6 are advisory. Review merged into decisions.md with full content and summary table.

  - **2026-04-25 (fabric-alz-m1m2-gates-resolved):** Carl completed design gate resolutions. **M1 — Block Public Internet Access:** Documented intentional omission in §4 (lab context requires browser access; public path coexists with optional private PE). Ryan's call honored. **M2 — MPE Connection Lookup:** Specified filter strategy in §11 Q2: azapi_resource_action must filter privateEndpointConnections by `properties.privateEndpoint.id == MPE_resource_id`, never "first Pending" or name pattern. Added post-apply `check {}` block asserting `connection_status == "Approved"`. Silent Pending is the failure mode; explicit filter + assertion mitigates lookup collision on shared KV. Design fully approved and locked. Ready for your implementation. Orchestration and session logs recorded.

## Key Learnings

### Publish Script Architecture (2026-07-25)

- **Script:** `scripts/publish-to-public.ps1` — implements Carl's Rev 3 publish workflow.
- **Architecture:** `[CmdletBinding()]` + `param()` + `Set-StrictMode` at top. Five named functions: `Test-Prerequisites`, `New-FilteredClone`, `Get-PublishSummary`, `Publish-ToPublic`, `Remove-TempClone`. Try/finally ensures temp dir cleanup even on error.
- **Temp clone pattern:** `[System.IO.Path]::GetTempPath()` + GUID directory. Clone the resolved origin URL (not the remote name — `git clone origin` fails; must resolve via `git remote get-url origin` first). Remove excluded paths from the clone, `git add --all`, single squashed commit with message `chore: publish snapshot from origin/{sha}`.
- **Dry-run gate:** Default is dry-run. Only `$Confirm` switch bypasses to push. Even then, `Read-Host` interactive prompt required. No way for an agent to auto-confirm.
- **Self-hiding:** `scripts/` is in the exclusion list. The publish script removes itself from its own output — verified by running dry-run.
- **Allowlist pattern:** `$AllowFromExcluded = @()` — commented examples inline for future use (e.g., `.github/ISSUE_TEMPLATE/**`). Restore logic TODO is documented in the function body.
- **Pitfall discovered:** `git clone <remote-name>` fails outside the repo context. Must resolve to URL with `git remote get-url origin` and pass the URL string to `git clone`. Fixed in commit bff3b13.
- **Exclusion list at ship:** 7 paths — `.squad/`, `.copilot/`, `.github/`, `.gitattributes`, `.squad-workstream`, `scripts/`, `docs/design/`. Locked per Carl's Rev 3 spec.
- **Dry-run output (origin/main as of 2026-07-25):** 987 files removed (`.squad` 939, `.github` 13, `.copilot` 34, `.gitattributes` 1), 90 files remaining. `scripts/` and `docs/design/` will appear after chore branch merge.

### Gitignore tfplan glob tightening — shipped (2026-07-25)
- **The *tfplan* glob lesson:** Oddly-named plan files (tfplan2, tfplan-backup) slip past `*.tfplan` + `tfplan` exact matches. Added `*tfplan*` catch-all.
- Also added `.squad/scribe-health-report-*.txt` for ephemeral Scribe diagnostics.
- First attempt was on a prior branch that Ryan scrapped. Successfully shipped on `chore/two-remote-strategy` as part of the two-remote strategy work.

### Fabric workspace-policy REST fix (2026-07-17)
- **Bug:** Wrong HTTP method (`PATCH` instead of `PUT`) and missing `/networking/` segment in URL. Both provisioners affected.
- **Lesson:** Never use `on_failure = continue` on state-changing calls; only reserve for destroy-time best-effort. It masks API errors.
- **Pattern:** After PUT, issue GET and assert desired state was applied.

---

## Architectural Patterns Established

- **Multi-region naming:** `{resource}-{region_abbr}-{random_suffix}` (e.g., kv00-sece-8357)
- **Per-LZ soft-delete + 7-day retention:** Lab-friendly KV lifecycle (purge protection off)
- **MPE auto-approval:** azapi_resource_list + strict ID filter + azapi_resource_action PUT
- **Workspace-local KV:** Eliminates orphaned PE on destroy
- **DNS resolver policy VNet link retry:** Transient InternalServerError — safe to retry

---

## Full Lab Teardown Patterns

### Two-Phase Destroy for Fabric-private (2026-04-29, proven)

**Phase 1 — MPE cleanup:**
1. Flip inbound policy Allow via `PUT /networking/communicationPolicy`
2. Poll MPE GET endpoint with 15–30s retry sleep until 200 (5–8 min typical)
3. LIST and DELETE all MPEs with retry loops
4. `terraform state rm` for MPE resources
5. `terraform destroy -refresh=false` (workspace will fail; expected)

**Phase 2 — Workspace cleanup:**
1. Poll `DELETE /v1/workspaces/{id}` until accessible
2. When 200, `terraform state rm fabric_workspace.workspace`
3. `terraform destroy -refresh=false` (capacity + RG)

**Total time:** ~20–30 min.

### Critical Findings (2026-04-29 teardown, live validation)

**communicationPolicy GET Behavior:**
- Management-plane GET returns Allow immediately after flip
- Data-plane enforcement lags 5–8 minutes (MPE endpoints, workspace DELETE remain blocked)
- **Do not use policy GET as gate.** Poll actual data-plane endpoint with retries.

**Inbound Policy Flapping:**
- Same endpoint can return 200 then 403 on consecutive calls during propagation window
- Retry loops with 15–30s sleeps required for all REST calls (GET, DELETE) during window

**MPE DELETE Returns 200 but Resource Persists:**
- HTTP 200 means accepted, not complete. DELETE is async on Fabric side.
- Poll until resource absent before proceeding to workspace deletion.

**`fabric_workspace` DELETE is Data-Plane (Separate from Policy):**
- Unlike `/networking/communicationPolicy` (callable from public), workspace DELETE is subject to inbound policy
- Can remain blocked up to ~15 min after Allow flip
- Workaround: manually DELETE via REST (polling), `terraform state rm`, re-run `terraform destroy -refresh=false`

### Networking Destroy (579 resources, `-refresh=false`)
- vHub: ~10 min (10m6s observed)
- vWAN + RG: ~30s
- Total: ~42 min (plan display is the long pole with 944 state resources)
- No orphans, all RGs deleted.

---

## Networking Quirks

- **modtm refresh is the long pole:** 181 modtm_module_source data sources → ~30 min GitHub calls. Use `-refresh=false` for teardown.
- **Transient InternalServerError on DNS policy VNet link:** Safe to retry (did retry, worked).
- **Orphan soft-deleted KVs:** Purge takes 5–10 min each (sequential, no batching).

---

## See Also

- **decisions.md** — Architecture decisions, API contracts, two-phase destroy pattern, comment fixes
- **lz-teardown skill** — Detailed runbook with code examples (`.squad/skills/lz-teardown/SKILL.md`)
- **history-archive-2026-07-17.md** — Earlier work (March–July 2026 foundation builds)
- Carl, Mordecai, Systemai histories for parallel efforts

---

## Archived Sections (full details in history-archive-2026-07-17.md)

- Fabric Admin API (LIST-only, POST /update, setting name corrections)
- Early deploy patterns (azapi auth, Fabric capacity UUID, MPE filtering)
- Detailed 2026-07-17 workspace-policy GET verification

---

**Last updated:** 2026-04-29 — Full teardown + gotchas captured
