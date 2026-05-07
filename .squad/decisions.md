# Squad Decisions

## Reference

Decisions prior to 2026-07-18 (two-remote strategy) have been archived to `.squad/decisions-archive-2026-07-18.md`. This file contains the active decision log from 2026-07-18 onward.

---

## Active Decisions

### Adopt One-Repo, Two-Remote Strategy (Carl — Lead/Architect)

**Status:** Approved — governance updated, remotes configured  
**Date:** 2026-07-18  
**Branch:** chore/two-remote-strategy  
**Author:** Carl (Lead / Architect)  
**Type:** Infrastructure / Governance

**Decision:** Adopt a two-remote model:
- **`origin`** → `RKrokson/azure-network-platform-private` (PRIVATE) — working remote for all dev, `.squad/` memory, agent commits.
- **`public-readonly`** → `RKrokson/azure-network-platform` (PUBLIC) — curated customer-facing mirror. Push disabled via `no_push` URL guard.

Publishing from private to public happens exclusively via `scripts/publish-to-public.ps1` (throwaway-clone model, `--dry-run` support) under human direction. Agents must never push to `public-readonly`.

**Alternatives Rejected:**
1. Single public repo with `.gitignore` for `.squad/` — history already contains real Azure subscription IDs.
2. Encrypted `.squad/` — key management overhead, breaks plain-text workflows.
3. Separate repos (fork model) — divergent histories make syncing painful.

**Rationale:** `.squad/` files contain real Azure subscription IDs, tenant IDs, and resource GUIDs. A private remote makes cross-machine team context safe without encryption. Public repo serves as customer/contributor interface with deliberate publish step.

**Implementation (this PR):**
- [x] Remote renamed `public` → `public-readonly` with `no_push` URL guard
- [x] Squad governance updated (`.github/agents/squad.agent.md`)
- [x] Scribe charter updated with private-remote-only commit rule
- [x] `team.md` Issue Source section clarified

**Deferred:** Publish script, public repo history scrub (filter-repo + force-push).

**Affected Files:** `.github/agents/squad.agent.md`, `.squad/agents/scribe/charter.md`, `.squad/team.md`

---

## Active Decisions

### Microsoft Fabric Application Landing Zone — Architecture & Design (Carl — Lead)

**Status:** Approved — implementation complete on branch squad/fabric-alz-impl  
**Date:** 2026-07-15  
**Module name:** `Fabric-private`

**Summary:** ADR completed — items 2 (LZ-local KV + MPE repoint), 5 (rename Fabric-byoVnet → Fabric-private), and 6 (workspace public access toggle). Item 3 (tenant-level PL) deferred. Full details archived in decisions-archive-2026-07-18.md.

---

### Fabric workspace communicationPolicy REST fix (Donut — Infrastructure)

**Status:** Applied ✅  
**Date:** 2026-07-17  
**Author:** Donut (Infrastructure Dev)

**Bug:** `workspace-policy.tf` had two errors: HTTP method `PATCH` → `PUT` (correct), URL path missing `/networking/` segment, and `on_failure = continue` masking errors.

**Fix:** Both provisioners corrected; create-time changed to `on_failure = fail`. See `.squad/decisions-archive-2026-07-18.md` for full details.

**Lesson:** Never use `on_failure = continue` on state-mutating provisioners.

---

### REST API from Design Doc — Skill Capture (Carl — Lead/Architect)

**Status:** Approved — new skill  
**Date:** 2026-07-18  
**Author:** Carl (Lead/Architect)

**Summary:** Created `.squad/skills/rest-api-from-design/SKILL.md` to prevent implementers from substituting their own REST conventions for spec'd method + URL.

**Rules:** (1) Verbatim copy, (2) Comment-as-contract, (3) `on_failure = fail` on mutating calls, (4) Read-back validation, (5) Concrete failure citation. See `.squad/skills/rest-api-from-design/SKILL.md` for full details and named prior failure (Fabric workspace-policy.tf commit 4171dc3).

---

---

## Decision: Publish Script & History Scrub — Final Spec (Rev 4)

**Author:** Carl (Lead / Architect)  
**Date:** 2026-07-25 (Rev 4 — .github/ conflict resolved, all questions closed)  
**Status:** APPROVED — ready for Donut to implement  
**Parent:** "Adopt One-Repo, Two-Remote Strategy" decision (2026-07-18)

---

## Guiding Principle

**Private = dev surface.** How we build (agents, skills, CI, MCP, design docs).  
**Public = consumption surface.** What we built (Terraform modules, READMEs, diagrams, guides).

---

## Sequencing: B (Script) → C (Scrub)

Script defines the exclusion list. Scrub reuses it. Script is reversible; force-push isn't.

---

## Resolved Questions

| # | Question | Answer |
|---|----------|--------|
| 1 | Forks | 2 exist. Low-impact — force-push proceeds. |
| 2 | Credential rotation | No. Subscription IDs aren't secrets. |
| 3 | Post-scrub branches | `main` only on public. |
| 4 | Publish cadence | Manual. Mandatory `--dry-run` gate. |
| 5 | Script location | `scripts/publish-to-public.ps1`, self-excluding. |

---

## The `.github/` Conflict — Analysis and Resolution

### The Problem

Issues live on the **public** repo (per team.md Issue Source). Three workflows fire on issue events and depend on `.squad/team.md`:

| Workflow | Trigger | Reads `.squad/team.md`? | Reads `.squad/routing.md`? |
|----------|---------|------------------------|---------------------------|
| `sync-squad-labels.yml` | push to `.squad/team.md` | **YES** — iterates roster to create `squad:*` labels | No |
| `squad-triage.yml` | `squad` label added | **YES** — parses roster + roles for routing | **YES** |
| `squad-issue-assign.yml` | `squad:*` label added | **YES** — validates member name against roster | No |
| `squad-heartbeat.yml` | issue closed / labeled | Likely yes | Unknown |

**If `.github/workflows/` is excluded from public:** these workflows don't exist on public → issue automation breaks entirely. Labels must be managed manually, triage is manual, @copilot assignment is manual.

**If workflows ARE on public but `.squad/team.md` isn't:** workflows `checkout` the repo, look for `.squad/team.md`, find nothing, and gracefully degrade (all three have `if (!fs.existsSync(teamFile)) { return; }` guards). They'd fire but do nothing useful.

### Question (c): Has "issues live on public" aged well?

**My answer: No, it hasn't.** Here's why:

When we made that call, the rationale was "customers/contributors interact with public." But let's be honest about what actually happens:

1. **External contributions:** Zero so far. This is a demo/lab repo, not a popular OSS project. Nobody's filing issues on public except us.
2. **Squad agents work on private.** They commit to private, read memory from private, push to private. Issue-to-code flow crosses a boundary that adds friction.
3. **The workflow dependency chain is circular:** Workflows need `team.md` to function → `team.md` has PII/internal context → can't publish it → workflows fire but do nothing.

**However:** moving issues to private closes the door on *future* external contribution, which matters if this repo grows. And it's a bigger change than we need right now.

### My Decision: Option 1 + Accept the Cost

**Exclude all of `.github/` from public. Accept that squad automation only runs on private.**

Here's how issues work under this model:

| Action | Where | How |
|--------|-------|-----|
| External user files issue | Public repo | Works — issues page is always available regardless of `.github/` |
| Ryan triages it | Private repo (Copilot session) | Reads issue from public, decides action, works in private |
| Squad automation (labels, triage, assign) | **Private repo only** | Workflows fire on private-side issue mirrors or manual label application |
| @copilot picks up issue | Public repo | **Still works** — @copilot reads issue content directly, doesn't need `copilot-instructions.md` to function (it helps but isn't required) |

### Why not Option 2 or 3?

- **Option 2** (keep workflows, lose team.md): Workflows fire but all degrade to no-ops. Noise without value. Worse than not having them.
- **Option 3** (sanitized team.md): Ongoing maintenance burden to keep a "clean" copy in sync. One slip and internal context leaks. Not worth it for zero external contributors.

### What about `copilot-instructions.md`?

This is the one file that has a plausible case for public. It tells @copilot about the project structure when it picks up a public issue. **But:**

1. @copilot can infer project structure from READMEs and file layout without it.
2. The per-module READMEs are comprehensive.
3. Publishing it means maintaining it separately from the private copy (or accepting they drift).
4. It references internal patterns (module paths, provider versions) that are already in the public README.

**Verdict:** Not worth the maintenance. @copilot handles public issues fine without it. If we ever see @copilot struggling on public issues, we can add it to the allowlist as a 1-line change.

### The "Future External Contributors" Escape Hatch

If this repo ever gets real external traffic:
1. Add `copilot-instructions.md` to allowlist (1 line)
2. Add `ISSUE_TEMPLATE/` to allowlist (1 line)  
3. Consider a `terraform-validate.yml` that's Squad-independent (no team.md dependency)

All of these are additive — the default-exclude rule stays clean.

---

## docs/ Partition (unchanged from Rev 3)

**Keep (consumption surface):** `adding-application-landing-zone.md`, `ip-addressing.md`, `landing-zone-model.svg`, `landing-zone-model.excalidraw`  
**Move to `docs/design/` (dev surface):** `nat-gateway-design.md`, `region-module-design.md`

README.md hard-links to `docs/` files — cannot exclude the directory. Partition is the clean answer. New convention: future design docs go in `docs/design/`.

---

## Final Exclusion List (7 entries)

| # | Pattern | Type | Reason |
|---|---------|------|--------|
| 1 | `.squad/` | Directory | Agent memory, real GUIDs, orchestration |
| 2 | `.copilot/` | Directory | MCP config, 30 agent skills |
| 3 | `.github/` | Directory | Agent def, copilot instructions, squad workflows |
| 4 | `.gitattributes` | File | Squad merge strategies |
| 5 | `.squad-workstream` | File | Squad activation file |
| 6 | `scripts/` | Directory | Publish script, dev tooling |
| 7 | `docs/design/` | Directory | Internal design proposals |

### Allowlist (empty today — future escape hatch)

```powershell
$AllowFromExcluded = @(
    # ".github/ISSUE_TEMPLATE/**"
    # ".github/copilot-instructions.md"
    # ".github/workflows/terraform-validate.yml"
)
```

### What Remains in Public

```
├── ContainerApps-byoVnet/
├── Diagrams/
├── Fabric-private/
├── Foundry-byoVnet/
├── Foundry-managedVnet/
├── Networking/
├── docs/
│   ├── adding-application-landing-zone.md
│   ├── ip-addressing.md
│   ├── landing-zone-model.excalidraw
│   └── landing-zone-model.svg
├── LICENSE
├── README.md
└── setSubscription.ps1
```

---

## Publish Script Spec

### Interface

```powershell
.\scripts\publish-to-public.ps1                 # ERROR: must specify --dry-run or --confirm
.\scripts\publish-to-public.ps1 --dry-run       # Shows diff summary, no push
.\scripts\publish-to-public.ps1 --confirm       # Pushes (with interactive confirmation prompt)
.\scripts\publish-to-public.ps1 --verbose       # Lists every excluded file
```

**Mandatory gate:** Script REQUIRES either `--dry-run` or `--confirm`. No default action. `--confirm` still shows a Y/N prompt before pushing. No silent operation possible.

### Behavior

```
1. Clone origin (private) into throwaway directory
2. Remove all paths in exclusion list (#1–#7)
3. Re-add any allowlist paths (currently empty)
4. If --dry-run:
   - Print: files removed, files remaining, commit count
   - Print: diff summary vs current public/main
   - Exit 0
5. If --confirm:
   - Print same summary as dry-run
   - Prompt: "Push to https://github.com/RKrokson/azure-network-platform main? [y/N]"
   - On 'y': force-push filtered tree via direct HTTPS URL
   - On anything else: abort
```

### Safety

- Lives in `scripts/` → excluded from own output
- Uses direct HTTPS URL (bypasses `no_push` remote guard)
- Human-only — agents banned per squad governance
- No `--force` / `--yes` / `--skip-prompt` flags. Ever.

---

## History Scrub Spec (Item C — after B ships)

```bash
# Fresh clone of PUBLIC repo
git filter-repo \
  --path .squad/ --invert-paths \
  --path .copilot/ --invert-paths \
  --path .github/ --invert-paths \
  --path .gitattributes --invert-paths \
  --path .squad-workstream --invert-paths \
  --path scripts/ --invert-paths \
  --path docs/design/ --invert-paths

# Verify:
git log --all --name-only | grep -E '^\.(squad|copilot|github)|^scripts/|^\.gitattributes|^\.squad-workstream|^docs/design/'
# Should be empty

# Check for real GUIDs:
git log --all -p | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | sort -u
# Only 00000000-0000-0000-0000-000000000002 (CosmosDB) should remain

# Force-push (2 forks become stale — accepted):
git push --force --all origin
git push origin --delete <non-main-branches>
```

---

## Pre-requisites Before Script Build

1. **Move design docs:** `git mv docs/nat-gateway-design.md docs/design/` and `git mv docs/region-module-design.md docs/design/` (small commit on private)
2. **Create `scripts/` directory** with the publish script

Both are safe, incremental commits on private. No public impact until the script is actually run with `--confirm`.

---

## Superseded Decision: "Issues Live on Public"

The "issues live on public" model from team.md remains **technically valid** — external users CAN still file issues on the public repo. But squad automation (triage, label sync, auto-assign) will only function on private. This is an acceptable tradeoff for a repo with zero external contributors today.

If external contribution grows, revisit by:
1. Adding consumer-facing files to the allowlist
2. Creating Squad-independent workflows (no team.md dependency)
3. Or moving to a "public issues → private working branch → publish results" flow

---

## Decision: Publish Script Shipped — donut-publish-script

**Author:** Donut (Infrastructure Dev)  
**Date:** 2026-07-25  
**Status:** SHIPPED ✅  
**Branch:** chore/two-remote-strategy  
**Parent spec:** `.squad/decisions/inbox/carl-publish-scope.md` (Rev 4)

---

## Summary

`scripts/publish-to-public.ps1` is live on the branch. Implements Carl's Rev 4 publish
workflow end-to-end: throwaway-clone → exclusion filter → squashed commit → dry-run
summary or interactive force-push.

---

## Exclusion List (locked — 7 paths)

| # | Path | Files removed (origin/main, 2026-07-25) |
|---|------|-----------------------------------------|
| 1 | `.squad/` | 939 |
| 2 | `.copilot/` | 34 |
| 3 | `.github/` | 13 |
| 4 | `.gitattributes` | 1 |
| 5 | `.squad-workstream` | 0 (file doesn't exist yet — excluded for future use) |
| 6 | `scripts/` | 0 (not on main yet — will appear post-merge) |
| 7 | `docs/design/` | 0 (not on main yet — will appear post-merge) |

**Total removed:** 987 files  
**Total remaining:** 90 files

Note: paths 5–7 showing 0 is expected — the dry-run clones `origin/main`, and this
chore branch hasn't merged yet. After merge those counts will be non-zero.

---

## Dry-Run Output (2026-07-25)

```
==> Checking prerequisites...
    origin  : https://github.com/RKrokson/azure-network-platform-private.git
    target  : https://github.com/RKrokson/azure-network-platform.git
    branch  : main
==> Source commit: bff3b138f2d2012eabc54fe78038a7f9c3fb05dd
==> Cloning origin into temp directory...
    source SHA : 1204f56e2a5ffc55543ea5a7c9c2395120a782d3

══════════════════════════════════════════════════════
  PUBLISH DRY-RUN SUMMARY
══════════════════════════════════════════════════════
  Source SHA  : 1204f56e2a5ffc55543ea5a7c9c2395120a782d3
  Target URL  : https://github.com/RKrokson/azure-network-platform.git
  Target Branch: main

  Files removed by exclusion path:
    .copilot                              34 file(s)
    .gitattributes                         1 file(s)
    .github                              13 file(s)
    .squad                              939 file(s)

  Total removed : 987
  Total remaining : 90
══════════════════════════════════════════════════════

DRY-RUN complete. Nothing was pushed.
Run with -Confirm to actually publish.
==> Cleaned up temp directory.
```

---

## Deviations from Carl's Rev 4 Spec

| Deviation | Rationale |
|-----------|-----------|
| Temp dir uses `[System.IO.Path]::GetTempPath()` + GUID (not `New-TemporaryFile` pattern) | `New-TemporaryFile` creates a file, not a directory. GUID-named subdir under `GetTempPath()` is the idiomatic PowerShell pattern for throwaway clone directories. |
| Two commits instead of one (script commit + clone-bug fix commit) | Dry-run caught that `git clone origin` fails — needs resolved URL via `git remote get-url origin`. Fix was one-line, committed separately for clean history. |
| `--Verbose` uses `$VerbosePreference` check (standard PS pattern) | Carl's spec said `-verbose` flag. PowerShell's `[switch]$Verbose` conflicts with the built-in `-Verbose` common parameter. Implemented via `$VerbosePreference -eq 'Continue'` which is triggered by `-Verbose` on the command line — behaviorally identical. |

---

## Notes for Future Readers

- **Before running `--confirm`:** Always run dry-run first. Verify source SHA matches what you expect to ship.
- **History scrub (Item C):** The `filter-repo` command in carl-publish-scope.md uses the same 7-path exclusion list. Run it against a fresh clone of the public repo.
- **Allowlist:** `$AllowFromExcluded = @()` is defined at the top of the script. Add paths there (with restore logic in `New-FilteredClone`) if a future spec needs to punch through an excluded parent directory.

---

## Decision: Skip Provider Registration — Conditional Variable (2026-05-07)

**Author:** Carl (Lead Architect)  
**Status:** APPROVED  
**Date:** 2026-05-07  
**Related:** Donut's first deploy attempt on managed subscription (403 on `Microsoft.Compute/registerAction`)

---

### Summary

Donut added `skip_provider_registration = true` to both Networking and Foundry-byoVnet to work around a 403 error in a managed subscription where Ryan's account lacks provider registration RBAC. Carl reviewed and delivered verdict: **revert + variable wrapper**.

### Decision: Revert to default, add conditional variable

1. Remove `skip_provider_registration = true` from both `config.tf` files (revert to default `false`)
2. Add `variable "skip_provider_registration"` to both `variables.tf` files with `default = false`
3. Update `config.tf` to use `skip_provider_registration = var.skip_provider_registration`
4. Document in README: set via `terraform.tfvars` if account lacks provider registration permission

### Rationale

- **Demo/lab environment:** Default should be auto-register (simpler, more transparent). Conditional flag preserves solution for 403 case.
- **Networking remains self-sufficient:** Platform LZ doesn't hide its dependencies behind a blanket flag.
- **Documents intent:** Variable with comments makes RBAC constraint explicit — not a default config choice.
- **User override:** Ryan sets `skip_provider_registration = true` in `terraform.tfvars` only when needed for managed subscription.

### What Needs to Happen

Add to `variables.tf`:
```hcl
variable "skip_provider_registration" {
  type        = bool
  default     = false
  description = "Set to true only if your service principal lacks Microsoft.ProviderHub/registerAction permission."
}
```

Update `config.tf`:
```hcl
skip_provider_registration = var.skip_provider_registration
```

---

## Decision: No Over-Engineering — Lab/Demo First (2026-05-07)

**Author:** Ryan Krokson (User Directive)  
**Status:** ACTIVE  
**Date:** 2026-05-07 16:42:49Z

---

### Directive

This is a demo/lab repo. Do not introduce variables, toggles, or knobs to handle hypothetical environments. If a setting isn't needed by THIS repo's intent (demo/lab in a sub where Ryan has admin rights), just remove it — don't wrap it in a variable "for flexibility." Keep configs minimal and intent-revealing.

### Scope

Applies to all future Terraform / config / module changes.

### Rationale

Over-engineering is a smell. Conditional features should have a concrete use case *in this repo* — not theoretical future-proofing.

---

## Decision: Agent Identity Attributes on Charters (2026-05-07)

**Author:** Ryan Krokson (User Directive)  
**Status:** ACTIVE  
**Date:** 2026-05-07 16:46:31Z

---

### Directive

Pronouns and other agent identity attributes (name, role, expertise, style) belong in each agent's `.squad/agents/{name}/charter.md` under the `## Identity` section — NOT in `decisions.md`. The decisions ledger is for scope/architecture/process decisions and gets archived after 30 days; identity attributes need to persist forever.

### Current Pronoun State (now lives on charters)

- Carl: he/him
- Donut: she/her
- Mordecai: he/him
- Katia: she/her
- SystemAI: it/its

### Coordinator Rule

When the user mentions an agent attribute (pronouns, role, style preference, naming), update the agent's charter — don't just write a decision. Decisions.md is for things the team decides about the work, not about the team itself.

---

