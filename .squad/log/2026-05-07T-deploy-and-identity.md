# Session Log: 2026-05-07 — Deploy + Identity Directives

**Date:** 2026-05-07  
**Coordinator:** Ryan Krokson (user)  
**Agent Spawns:** 4 (donut, carl, donut-1, coordinator inline)

---

## Session Arc

### 10:38–11:30 | Donut (first attempt) — FAILED
Networking + Foundry-byoVnet deploy hit:
- Wrong subscription (403)
- Provider registration RBAC missing on managed subscription

**Workaround applied:** `skip_provider_registration = true` (hardcoded)

### 11:36 | Carl (sync) — ARCHITECTURAL REVIEW
Reviewed Donut's `skip_provider_registration = true` as blanket setting.

**Verdict:** REVERT + conditional variable
- Remove hardcoded `true` (demo/lab should auto-register by default)
- Add `variable "skip_provider_registration"` with `default = false` to both modules
- Documented in decision: `.squad/decisions/inbox/carl-skip-provider-registration.md`

**User override:** Ryan accepted Carl's verdict (variable approach) but rejected the variable part — stated: **"Don't wrap it in a variable 'for flexibility.' Keep configs minimal."** This triggered a team-wide directive capture (see below).

### 11:46–12:52 | Donut-1 (second attempt) — SUCCESS ✅
- **Phase 1:** Reverted workaround per Carl's verdict (commit 2537ef9)
- **Phase 2:** Full deploy with corrected auth
  - Networking: 579 resources / 35 min
  - Foundry-byoVnet: 32 resources / 25 min
  - **Total:** 611 resources / 60 min
  - **Retries:** 0
  - **Result:** Zero errors, production-ready

### 16:42 | User Directive — "No Over-Engineering"
Ryan captured team directive: lab/demo repo, don't introduce variables for hypothetical environments. Keep configs minimal and intent-revealing. *Applies to all future Terraform changes.*

### 16:46 | User Directive — "Identity on Charters"
Ryan redirected agent identity attributes (pronouns, roles, style) to charter documents instead of time-archived decisions. Updated all agent charters with pronouns:
- Carl: he/him
- Donut: she/her
- Mordecai: he/him
- Katia: she/her
- SystemAI: it/its

---

## Decisions Captured

| Document | Status |
|----------|--------|
| `.squad/decisions/inbox/carl-skip-provider-registration.md` | Merged → decisions.md |
| `.squad/decisions/inbox/donut-deploy-success-2026-05-07.md` | Merged → decisions.md |
| `.squad/decisions/inbox/copilot-directive-2026-05-07-no-over-engineering.md` | Merged → decisions.md |
| `.squad/decisions/inbox/copilot-charter-identity-2026-05-07.md` | Merged → decisions.md |

---

## Team-Wide Directives (Now in Effect)

### 1. No Over-Engineering (2026-05-07)
Demo/lab repo. Remove unnecessary settings; don't wrap in variables "for flexibility." Settings should have concrete use cases in *this* repo.

### 2. Identity on Charters (2026-05-07)
Agent pronouns, roles, and style live on each agent's `charter.md` (`## Identity` section), not in decisions.md. Charters are source-of-truth; decisions.md is time-limited.

### 3. Coordinator Rule
When user mentions agent attributes → update charter. Don't write a decision. Decisions are about *work*; charters are about *team*.

---

## Charter Updates (Coordinator)

Added `Pronouns:` line to Identity section:
- `.squad/agents/carl/charter.md`
- `.squad/agents/donut/charter.md`
- `.squad/agents/mordecai/charter.md`
- `.squad/agents/katia/charter.md`
- `.squad/agents/systemai/charter.md` (already had it)

---

## Infrastructure State (End of Session)

| Module | Status | Region | Resources |
|--------|--------|--------|-----------|
| Networking | DEPLOYED | swedencentral | 579 |
| Foundry-byoVnet | DEPLOYED | swedencentral | 32 |
| Foundry-managedVnet | Ready | — | — |
| ContainerApps-byoVnet | Ready | — | — |
| Fabric-private | Ready | — | — |

---
