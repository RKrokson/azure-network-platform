# Mordecai — Documentation Specialist

**Project:** Azure IaC demo/lab (Terraform modules)  
**Stack:** Markdown, technical documentation  
**Created:** 2026-03-27

## 2026-05-07 Charter Update

- Added pronouns (he/him) to Identity section per team directive: identity attributes live on charters, not in archived decisions.md.

## Most Recent Work (2026-07-18)

- **2026-07-18 (ssms-fqdn-clarity):** Improved SSMS connection section in `Fabric-private/README.md` to distinguish two FQDN families: control-plane API (`{workspaceid}.z{xy}.w.api.fabric.microsoft.com`) vs data-plane SQL endpoint (`{GUID}-{GUID}.z{xy}.datawarehouse.fabric.microsoft.com`). Added before/after FQDN example in Step 1 and clarified in Step 2 table that the `.datawarehouse.` FQDN goes into the SSMS "Server name" field. This prevents newcomer confusion about which FQDN to use for the SQL connection.

- **2026-07-18 (fabric-alz-diagram):** Created `Diagrams/fabric-alz.excalidraw` — full architecture diagram for the Fabric-private ALZ. Shows all three panels (Platform LZ, Fabric Spoke VNet, Microsoft-managed Fabric), inbound PE path (green solid arrows), outbound MPE path (purple dashed arrows), RBAC arrow (gray dashed), deny-public badge, Lakehouse optional dotted box, and mode legend. Added Architecture section to `Fabric-private/README.md` with `.png` reference (aspirational — export from Excalidraw) and `.excalidraw` source link. Diagram uses basic shapes with color coding (no icon library scripts needed — clean labels are more readable at README scale).

## Most Recent Work (2026-07-15)

- **2026-07-15 (fabric-prereq-rewrite):** Rewrote Fabric-private README Prerequisites section to document two silent-failure gates: (1) Entra directory role required (not Azure RBAC), (2) Tenant Fabric provisioning required (Free/trial/F-SKU). Each gate has verification step + clear error mode. Added links to Entra admin center. Gate order prevents troubleshooting dead-ends. Decision documented: Fabric Admin Access Model & Prerequisites Restructure. README updated, uncommitted per workflow.

- **2026-07-15 (gate-3-setting-name-update):** Donut corrected three Fabric Admin API setting names in configure-fabric-tenant-settings.ps1 (Round 2 fix). Updated README Gate 3 with verified API-to-portal mappings and clarified that "Microsoft Fabric" is a section header, not a distinct API setting. Coordinated via decision drop and SKILL.md.

## Career Summary

**Phase 1 — LZ Framing (March 2026):** Restructured root README as navigation hub. Renamed all module READMEs with landing zone titles (Platform LZ: Networking; Application LZ: Foundry/ContainerApps/Fabric). Standardized prerequisite sections per module. Removed VPN references.

**Phase 2 — Tables + Guides (March–April 2026):** Added Conditional Variables, Outputs, and Quick Start tables. Created docs/adding-application-landing-zone.md onboarding guide. Consolidated cleanup procedures. Fixed GitHub org references (azure-ai-foundry → microsoft-foundry). Verified all diagram references.

**Phase 3 — Diagram Normalization (April 2026):** Renamed Networking/diagrams/ → Networking/Diagrams/ (case-sensitive filesystem fix). Updated 14 image references. Removed duplicate PNGs. Added scenario descriptions above diagrams.

**Phase 4 — README Polish (April 2026):** Removed bloated 13–16 row variable tables. Replaced with focused 5-variable summaries + pointer to variables.tf. Tightened prose across all 4 READMEs: removed passive voice, cut redundant verbiage, streamlined Notes sections.

**Phase 5 — Application Module Docs (April 2026):** Created ContainerApps-byoVnet README following Foundry pattern. Documented three app modes (none/hello-world/mcp-toolbox). Updated root README with ACA reference. Added MCP Toolbox description.

**Phase 6 — Fabric-private Rewrite (July 2026):** Implemented Carl's 6-item ADR: removed redundant DNS prereq, rewrote security posture (Private Connectivity + Private-Only Access Optional + Tenant PL Out-of-Scope), documented estrict_workspace_public_access flag, removed orphaned KV PE cleanup section, renamed Fabric-byoVnet → Fabric-private (docs only; folder rename is Donut's git mv). Documented prerequisite gates in detail.

## Architectural Documentation Patterns

- **READMEs are entry points:** Summarize 5 critical variables; full config in variables.tf
- **Security notes:** Concrete behavior, no aspirational language
- **Module structure:** Clear "What It Deploys" with Block numbering
- **Cleanup gotchas:** Front-load warnings (soft-delete, purge protection) with links
- **Humanizer discipline:** Natural prose, no AI vocabulary, no rule-of-three, no em dash overuse
- **Diagram strategy:** Normalize paths, add scenario descriptions, verify cross-platform resolution

## Key Learnings

- Fabric Admin Access Model: Two independent gates (Entra role + tenant provisioning), both required
- Silent-failure debugging: Empty API responses indicate missing prerequisites, not bad credentials
- Lab environment design: Private-by-default contradicts module purpose; flip defaults
- Documentation ROI: 5-variable focus vs 13-row tables saves readers 80% cognitive load
- Excalidraw diagrams: Manual JSON (colored rectangles + arrows) outperforms icon-library scripts for architecture diagrams at README scale. Icons add noise; clear labels + color coding add signal. Use `fontFamily: 5` (Excalifont) on all text elements.
- Diagram README pattern: PNG reference (aspirational, export from Excalidraw) + `.excalidraw` source link + 5-line prose summary. Reuse for all future ALZ diagrams.
- Color convention for Azure diagrams: blue=networking, green=private endpoints, orange=data resources, purple=Fabric, red=deny-public policy, yellow=legend/callouts.
- **Fabric FQDN duality:** Private links transform TWO FQDN families, not one. Control-plane API (`w.api.fabric.microsoft.com` → `z{xy}.w.api.fabric.microsoft.com`) routes SSMS metadata calls; data-plane SQL endpoint (`.datawarehouse.fabric.microsoft.com` → `z{xy}.datawarehouse.fabric.microsoft.com`) is what users paste into the SSMS "Server name" field. Newcomers conflate them — lead with concrete before/after examples of the SQL FQDN.

## See Also

- **decisions.md** — Design decisions, naming conventions, module structure principles
- **history-archive.md** — Detailed early work (March 2026)
- Donut, Carl, Katia, SystemAI histories for parallel efforts


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

