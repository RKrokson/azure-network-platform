# Carl — Architecture Lead (Architect)

**Project:** Azure IaC demo/lab (Networking platform LZ + AI Foundry + Container Apps + Fabric ALZ modules)  
**Stack:** Terraform (azurerm, azapi, random), PowerShell, Azure CLI  
**Created:** 2026-03-27  
**History archived to:** `.squad/agents/carl/history-archive.md` (pre-2026-07-18)

---

## 2026-05-07 Directives

- Reviewed Donut's `skip_provider_registration` hardcoding on managed subscription. Verdict: revert + conditional variable (no blanket flags). User directive captured: keep demo/lab configs minimal, no over-engineering.

## Learnings

### Fabric workspace-level PE model (2026-07-16)

Fabric supports private links at **two distinct scopes** — tenant-level (`Microsoft.PowerBI/privateLinkServicesForPowerBI`) and workspace-level (`Microsoft.Fabric/privateLinkServicesForFabric`). These are completely different ARM resource types. The workspace-level flow:

1. Fabric admin enables tenant setting "Configure workspace-level inbound network rules" (portal-only, not ARM).
2. Deploy ARM resource `Microsoft.Fabric/privateLinkServicesForFabric@2024-06-01` (location: `global`, binds tenantId + workspaceId).
3. Create standard `azurerm_private_endpoint` targeting that PL service with `subresource_names = ["workspace"]`.
4. DNS zone: `privatelink.fabric.microsoft.com` (already centralized in our Networking module).
5. Optionally deny public access via Fabric REST API `communicationPolicy` endpoint.

**What Donut got wrong on 2026-04-28:** Concluded "Fabric private links are tenant-scoped only" and removed the workspace PE. This conflated the tenant-level PL service (`Microsoft.PowerBI/...`) with the workspace-level PL service (`Microsoft.Fabric/...`). The incorrect comment was left in `fabric.tf` lines 123-127. The workspace was left publicly reachable as a result.

**Fix designed:** ADR `carl-fabric-workspace-pe-fix.md` — additive two-resource fix (azapi PL service + azurerm PE), no existing resources destroyed. Pending Ryan approval.

### Two-remote strategy (2026-07-18)

Adopted a one-repo, two-remote model: `origin` → private working repo (`azure-network-platform-private`), `public-readonly` → curated public mirror (`azure-network-platform`). Rationale: `.squad/` files contain real Azure subscription IDs and tenant GUIDs that were leaking to public commit history. Private remote lets team memory ride unencrypted; publish script filters content for the public mirror.

Governance changes made: added "Remote Model — Public/Private Mirror" section to `squad.agent.md` with explicit agent rules (never push to public-readonly), updated Scribe charter with remote-targeting constraint, clarified `team.md` Issue Source (issues public, code private). The `no_push` URL trick on `public-readonly` is a nice defense-in-depth — even if an agent tries, git rejects the push.

Key insight: renaming `public` → `public-readonly` is a small thing but matters for muscle memory. Typing the full name forces a pause. Same principle as `--force-with-lease` over `--force`.

## Cross-Agent Update — Fabric Workspace-Level PE Fix Deployed (2026-07-17)

**Partner:** Donut (Infrastructure Dev)  
**Branch:** squad/fabric-alz-impl  
**Outcome:** ✅ Workspace PE deployed and verified (IP 172.20.80.5)

Donut successfully implemented the workspace-level PE fix design per the ADR. The corrected pattern is confirmed:
- **Resource type:** `Microsoft.Fabric/privateLinkServicesForFabric@2024-06-01` (azapi provider, location: global)
- **azapi quirk:** `schema_validation_enabled = false` required (bundled schema outdated)
- **PE dependency:** workspace-policy.tf now depends on PE (not bare workspace), ensuring private path is live before deny-public-access fires
- **Scope guardrail:** Tenant-level PE remains out of scope per Ryan directive

All inbox files merged into decisions.md; superseded 2026-04-28 entry marked with full resolution context.

### REST API method/URL drift — recurrence pattern (2026-07-18)

This has happened at minimum twice: an implementer reads a design doc that cites a specific HTTP
method + URL, then writes code using a different method or a slightly different path based on REST
convention intuition. The cited spec is overridden silently.

**Confirmed instance:** `Fabric-private/workspace-policy.tf` (commit `4171dc3`). Design cited
`PUT /v1/workspaces/{id}/networking/communicationPolicy`. Code wrote `PATCH /v1/workspaces/{id}/communicationPolicy`.
Two errors — wrong method, missing `/networking/` path segment. `on_failure = continue` masked
both. Ryan caught it from the portal. Fixed in `0471d6a`.

**Root cause:** Implementers pattern-match REST conventions instead of treating the cited
method+URL as a verbatim contract.

**Remediation:** Created `.squad/skills/rest-api-from-design/SKILL.md` — codifies the rule
(copy verbatim, cite source as a comment, `on_failure = fail` on mutating calls, read-back
validation) and preserves this instance as a concrete prior failure example. Skill confidence:
`medium` (second observation).

## See Also

- **decisions.md** — Team approval decisions and architecture direction
- **history-archive-2026-07-25.md** — Earlier learnings (April–July 2026)
- Donut, Katia, Mordecai, SystemAI histories for parallel work


---

## Publish/Scrub Scope Analysis (2026-07-25)

Completed scope analysis for deferred items B (publish script) and C (history scrub) from the two-remote strategy decision.

**Key findings:**
- `.squad/` is the sole source of sensitive data (real subscription GUIDs, tenant IDs, user emails). 76 of 149 public commits touch `.squad/`.
- Terraform source is **clean** — all GUIDs are placeholders (`00000000-...`) or runtime-generated. `.tfvars` are gitignored.
- Recommended sequence: B (script) first → C (scrub) second. Script defines the exclusion list; scrub reuses it. Script is reversible; force-push is not.

**Rev 2 (same session):** Ryan proposed "dev surface vs consumption surface" framing. Agreed — expanded exclusion scope:
- `.squad/` — agent memory, GUIDs
- `.copilot/` — MCP config, 30 agent skills (all dev tooling, zero consumer value)
- `.github/` — currently 100% dev surface (squad.agent.md, copilot-instructions.md, squad-*.yml workflows). No consumer-facing templates exist yet.
- `.gitattributes` — Squad merge strategies only
- `scripts/` — will hold publish script (meta-tooling, never self-publishes)

**Rev 3 (same session):** Ryan resolved all open questions and flagged `docs/` as potential leak. Analysis:
- `docs/` is mixed: 4 consumer-facing files (ALZ onboarding guide, IP addressing, SVG diagram, excalidraw source) + 2 internal design docs (NAT gateway design, region-module-design). No GUIDs anywhere.
- README.md has hard dependencies on `docs/` (image embed + link to adding-application-landing-zone.md). Cannot exclude entirely.
- **Partition:** Move design docs to `docs/design/`, exclude `docs/design/` from publish. Consumer files stay at `docs/` root.
- Final exclusion list: 7 entries (`.squad/`, `.copilot/`, `.github/`, `.gitattributes`, `.squad-workstream`, `scripts/`, `docs/design/`)
- Mandatory `--dry-run` gate baked into publish script spec (no `--confirm` = no push)
- 2 forks exist, low-impact, force-push proceeds without coordination
- Pre-req before script build: `git mv` the 2 design docs into `docs/design/`

**Rev 4 (same session):** Ryan flagged `.github/` conflict — workflows on public fire on issue events but need `.squad/team.md` which is excluded. Analysis:
- All 3 issue-event workflows (`sync-squad-labels`, `squad-triage`, `squad-issue-assign`) hard-read `.squad/team.md` and `.squad/routing.md`
- All have graceful fallbacks (`if (!fs.existsSync(teamFile)) { return; }`) but degrade to no-ops without team.md
- **Decision: exclude all of `.github/` (Option 1). Accept that squad automation runs on private only.**
- Rationale: Zero external contributors today. Publishing workflows that fire but do nothing is noise. Publishing a sanitized team.md is ongoing maintenance for zero value.
- External users can still file issues on public — issue page works regardless of `.github/`. Ryan triages manually or via private-side Copilot session.
- `copilot-instructions.md` not published — @copilot infers project structure from READMEs. Add to allowlist if this proves insufficient.
- Escape hatch: allowlist in publish script for future ISSUE_TEMPLATE/, consumer CI, or copilot-instructions.md. All additive, 1-line changes.
- "Issues live on public" decision remains valid but squad automation is private-only. Acceptable tradeoff.

Decision filed: `.squad/decisions/inbox/carl-publish-scope.md` (Rev 4 — FINAL). Ready for Donut.

---

## Cross-Agent Notice: REST API from Design Skill (2026-07-18)

**All agents:** A new skill .squad/skills/rest-api-from-design/SKILL.md has been created to prevent recurring REST implementation errors. This affects anyone writing REST calls in Terraform, GitHub Actions, or shell scripts.

**Trigger:** Apply when implementing a REST call whose method + URL appears in a design doc or vendor docs. Key rule: use on_failure = fail on all state-mutating calls (POST/PUT/PATCH/DELETE); never substitute your own HTTP conventions.

**Named prior failure:** Fabric workspace-policy.tf bug (commit 4171dc3) — used PATCH instead of PUT, wrong URL path, on_failure=continue masked the error.

For details, see .squad/skills/rest-api-from-design/SKILL.md.

---

## Next Design Pass Queued


Fabric next design pass ready to spawn. Scope locked in decisions.md: native Lakehouse, three-way network_mode enum (inbound_only / outbound_only / inbound_and_outbound), and storage account upgrades (ADLS Gen 2 + Workspace Identity + Storage Blob Data Contributor) for outbound MPE path. Teardown complete; environment clean. See orchestration-log and session-log for context.

---

## Reusable Pattern: Deploy + Develop in Single Checkout (2026-XX-XX)

**Scenario:** User wants to deploy existing LZs from current checkout while simultaneously editing a new ALZ module in the same tree.

**Answer: YES, safe to do in the same checkout.**

**Why it's safe:**
1. **Isolated terraform state:** Each module (Networking/, Foundry-*, NewService-*) has its own `terraform.tfstate` file in its directory. No state sharing = no cross-module locking conflicts during concurrent `terraform apply`.
2. **File edit safety:** Editing `NewService-byoVnet/main.tf` while `terraform apply` runs on `Foundry-byoVnet/` is safe. Different working directories. Git tracks the same files, but terraform state operations never collide.
3. **Git operations:** Different branches can be checked out in git worktrees (`git worktree add ../tmp squad/new-service`). Single checkout on `main` can deploy + edit same branch — edits are uncommitted until you commit them.

**The gotchas (real, specific to this repo):**

| Gotcha | Impact | Mitigation |
|--------|--------|-----------|
| **Networking 90–120 min deploy** | `terraform apply` on Networking blocks that terminal. Apply runs 2 re-applies for known transient errors (vHub InternalServerError, MPE UnknownError). | Run Networking apply in a separate terminal session or detached PowerShell process so you can edit Foundry/NewService modules in the main terminal. |
| **Foundry soft-delete cleanup** | After `terraform destroy` on Foundry, AI Foundry enters soft-delete for 7 days. If you destroy Networking before purging, subnet service link blocks Networking teardown. | Destroy Foundry modules in order, purge soft-deleted resources from Azure portal *before* destroying Networking. Or just leave Networking deployed while you develop NewService. |
| **terraform_remote_state path** | Foundry modules read `../Networking/terraform.tfstate` as a file. If you move the Networking directory or checkout a branch without it, remote state breaks. | Keep Networking/ in the same relative location. Use git worktrees if you need multiple concurrent branch states (one worktree per branch). |
| **Two-remote gotcha** | Both remotes point to local backend. If you're switching branches across private/public mirrors, ensure you're on the private remote (origin). | Run `git remote -v`. Confirm `origin` is `azure-network-platform-private`. Public-readonly has `no_push` guard anyway. |

**Recommended workflow:**

```powershell
# Terminal 1 (deployment):
cd Networking
terraform init
terraform apply  # ~90-120 min. Go do other work.

# Terminal 2 (development — independent, can run in parallel):
cd Foundry-byoVnet
# Edit, test, validate — no state conflicts with Terminal 1 above
terraform validate
terraform fmt

# Or create new module:
mkdir NewService-byoVnet
# Copy from Foundry-byoVnet/ as template, adapt for your service
terraform validate
# Commit when ready
```

**Alternative (if you want strict isolation):** Use `git worktree add ../tmp-new-service squad/feature-branch`. Separate working tree for the new ALZ. Deploy from main checkout, develop in worktree. Zero risk of accidental file edits. Worktree gets its own .terraform state cache.

**Bottom line:** Same checkout is fine and recommended for this repo. The transient Networking errors will require re-applies (normal for this environment), but they don't block your new ALZ development. Just use separate terminals for the long-running `terraform apply` so your editing isn't blocked.

## Provider Registration: Conditional vs. Blanket (2026-XX-XX)

**Context:** Donut added `skip_provider_registration = true` to both Networking/ and Foundry-byoVnet/ to work around a 403 error on provider registration in a managed subscription where Ryan's account lacks permission. Ryan questioned whether this is sensible as a blanket setting.

**Analysis:** The flag does what it says — it disables automatic provider registration. Sensible for RBAC-constrained accounts, compliance gates, or pre-registered shared subscriptions. NOT sensible for demo/lab environments with full admin rights, because it hides dependencies and adds friction.

**Verdict: REVERT + Make Conditional.**  
Default should be `false` (auto-register). Add a boolean variable so ops teams can set it to `true` in their `terraform.tfvars` when targeting RBAC-constrained subscriptions. This solves the current 403 case *and* documents the intent for future contributors. Decision filed in `.squad/decisions/inbox/carl-skip-provider-registration.md`.

---

## Learnings

### fabric_workspace identity block — native provider support (2026-07-25)

The `microsoft/fabric` Terraform provider supports workspace identity natively via an `identity` block on `fabric_workspace`:

```hcl
identity = {
  type = "SystemAssigned"
}
```

Read-only outputs: `identity.application_id`, `identity.service_principal_id`. This calls the Fabric REST API `POST /v1/workspaces/{id}/provisionIdentity` internally. No `azapi_resource_action` or `terraform_data` + `local-exec` fallback needed.

Available since provider ~v1.9.x. PR #932 on the provider repo ("Allow workspace identity without capacity_id") confirms active maintenance.

**Implication:** The rest-api-from-design skill is NOT needed for workspace identity provisioning. The provider handles it declaratively.

### fabric_lakehouse — first-class provider resource (2026-07-25)

`fabric_lakehouse` is GA in the `microsoft/fabric` provider. Required: `display_name`, `workspace_id`. Optional: `description`, `configuration.enable_schemas`, `definition`. OneLake-backed by default — no external storage config needed.

### Entra SP propagation timing for RBAC (2026-07-25)

Workspace identity provisioning: SP takes 30-60s to propagate in Entra. Mitigation: `time_sleep(60s)` + `principal_type = "ServicePrincipal"` on role assignment. General pattern for any freshly-created SP needing immediate RBAC.

### network_mode three-way conditional pattern (2026-07-25)

Three-way enum (`inbound_only`, `outbound_only`, `inbound_and_outbound`) cleaner than separate booleans. Avoids invalid "both false" state. Derived locals keep `count` expressions DRY.

---

