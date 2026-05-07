# Katia — Validator (she/her)

- **Owner:** Ryan Krokson
- **Project:** Azure IaC demo/lab environments — Terraform modules for Azure vWAN, AI Foundry, networking
- **Stack:** Terraform (azurerm >= 4.0, azapi >= 2.0, random ~> 3.5), PowerShell, Azure CLI
- **Structure:** Three root modules — Networking (foundation), Foundry-byoVnet, Foundry-managedVnet linked via terraform_remote_state
- **Created:** 2026-03-27

## 2026-05-07 Charter Update

- Added pronouns (she/her) to Identity section per team directive: identity attributes live on charters, not in archived decisions.md.

## Current Status

✅ **Phase 1-4 Complete. All modules validated.**

- **terraform fmt -check:** PASS all 3 modules — zero formatting drift
- **terraform validate:** PASS all 3 modules — managedVnet has pre-existing `ignore_changes` warning (provider-side, not actionable)
- **VPN removal:** PASS — zero VPN references, zero s2s_ references
- **ALZ VNet migration:** PASS — create_ai_lz fully removed, Foundry modules have networking.tf, IP blocks non-overlapping
- **Regional child module:** PASS — 31 per-region resources encapsulated, no duplicates, outputs chain correctly
- **ContainerApps-byoVnet:** APPROVED — 38-check validation + post-fix revalidation, all checks pass
- **Security:** vm_admin_username marked sensitive, disableLocalAuth hardened, firewall warnings present

## Key Patterns

- All boolean toggles default to `false` (safe defaults)
- No invalid toggle combinations possible within single modules
- Child module boundary eliminates nested count-guard bugs (region 1's module-level count)
- Tags applied on all taggable resources via `local.common_tags`
- Firewall/NAT Gateway mutually exclusive (design constraint)
- App LZs consolidate platform resources (LAW, DNS zones, KV) instead of duplicating
- ACR DNS zone centralized in Networking AVM module — app LZs reference via output

## Known Observations (Non-Blocking)

- Foundry modules unconditionally consume `dns_resolver_policy00_id` (null if private DNS disabled) — user config error if this happens, but a precondition block would improve UX
- Foundry modules use `time_sleep` without explicit `hashicorp/time` in required_providers (works via implicit resolution, not pinned)
- Foundry-managedVnet has pre-existing `ignore_changes = [output]` warning (provider-side drift, not user-actionable)

## See Also

- **decisions.md** — Team approval decisions and architecture direction
- **history-archive.md** — Detailed validation checklists (March-August 2026)
- Donut, Carl, Mordecai, SystemAI histories for parallel work


---

## Cross-Agent Notice: REST API from Design Skill (2026-07-18)

**All agents:** A new skill .squad/skills/rest-api-from-design/SKILL.md has been created to prevent recurring REST implementation errors. This affects anyone writing REST calls in Terraform, GitHub Actions, or shell scripts.

**Trigger:** Apply when implementing a REST call whose method + URL appears in a design doc or vendor docs. Key rule: use on_failure = fail on all state-mutating calls (POST/PUT/PATCH/DELETE); never substitute your own HTTP conventions.

**Named prior failure:** Fabric workspace-policy.tf bug (commit 4171dc3) — used PATCH instead of PUT, wrong URL path, on_failure=continue masked the error.

For details, see .squad/skills/rest-api-from-design/SKILL.md.

---

## Cross-Agent Notice: Publish Workflow Shipped (2026-07-25)

**All agents:** Publish workflow completed and locked. Exclusion list finalized at 7 paths (`.squad/`, `.copilot/`, `.github/`, `.gitattributes`, `.squad-workstream`, `scripts/`, `docs/design/`). Allowlist available in script for future expansions (currently empty; all commented examples provided). Decision entries merged to decisions.md. Script ready for dry-run validation. History scrub deferred to post-merge (Item C).

**Impact:** Private remote stays clean (all dev work). Public mirror remains curated (manual publish-only model). Forces external contribution through issues path (acceptable for now — zero contributors today). Revisit allowlist if external users materialize.

For details, see:
- `.squad/decisions.md` — "Publish Script & History Scrub — Final Spec (Rev 4)" and "Publish Script Shipped"
- `.squad/log/20260505T173703Z-publish-script-rev4.md` — Session notes (scope expansion, dry-run numbers)
- `.squad/orchestration-log/20260505T173703Z-*.md` — Per-agent delivery summaries

