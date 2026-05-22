# IP Address Space Allocation

This document is the **IP address authority** for this repository. Any new application landing zone must pick the next free block number.

## Allocation Scheme

Each region uses a `/16` supernet divided into `/20` blocks. Region 0 uses `172.20.x.x`, Region 1 uses `172.21.x.x`.

### Region 0 (`172.20.0.0/16`)

| Block # | CIDR | Assigned To | Subnets |
|---------|------|-------------|---------|
| 0 | `172.20.0.0/20` | Platform — Shared spoke VNet | See `Networking/variables.tf` |
| 1 | `172.20.16.0/20` | Platform — DNS VNet | See `Networking/variables.tf` |
| 2 | `172.20.32.0/20` | App LZ — **Foundry-byoVnet** | `172.20.32.0/26` (AI Foundry), `172.20.33.0/24` (Private Endpoints) |
| 3 | `172.20.48.0/20` | App LZ — **Foundry-managedVnet** | `172.20.48.0/26` (AI Foundry), `172.20.49.0/24` (Private Endpoints) |
| 4 | `172.20.64.0/20` | App LZ — **ContainerApps-byoVnet** | `172.20.64.0/27` (ACA Environment), `172.20.65.0/24` (Private Endpoints) |
| 5 | `172.20.80.0/20` | App LZ — **Fabric-private** | `172.20.80.0/24` (Private Endpoints — workspace PE). Claimed 2026-04-26. |
| 6–15 | `172.20.96.0/20` – `172.20.240.0/20` | **Unassigned** (future app LZs) | — |

### Region 1 (`172.21.0.0/16`)

| Block # | CIDR | Assigned To | Subnets |
|---------|------|-------------|---------|
| 0 | `172.21.0.0/20` | Platform — Shared spoke VNet | See `Networking/variables.tf` |
| 1 | `172.21.16.0/20` | Platform — DNS VNet | See `Networking/variables.tf` |
| 2 | `172.21.32.0/20` | Reserved — Foundry-byoVnet (region 1, future) | — |
| 3 | `172.21.48.0/20` | Reserved — Foundry-managedVnet (region 1, future) | — |
| 4 | `172.21.64.0/20` | Reserved — ContainerApps-byoVnet (region 1, future) | — |
| 5 | `172.21.80.0/20` | Reserved — Fabric-private (region 1, future) | — |
| 6–15 | `172.21.96.0/20` – `172.21.240.0/20` | **Unassigned** (future app LZs) | — |

## Rules

1. Each application landing zone gets its own `/20` block per region.
2. Blocks are assigned sequentially — pick the next free number.
3. Subnets are carved from within the assigned block (no cross-block addressing).
4. Default CIDRs are hardcoded per module. Users may override via `terraform.tfvars` but must avoid collisions.
5. Both Foundry modules can be deployed simultaneously against the same vHub without CIDR overlap.

## vHub Address Prefixes

Virtual Hub address prefixes use a separate `172.30.x.x/23` range and do not conflict with spoke VNet addressing.
