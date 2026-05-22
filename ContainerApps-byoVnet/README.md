# Application Landing Zone — Container Apps (BYO VNet)

This is an optional application landing zone. It deploys Azure Container Apps (ACA) with a Premium ACR and private endpoints into its own spoke VNet. The module creates the VNet, subnets, hub connection, DNS zones, and managed identity for image pulls. You do not need to deploy this to use the Networking module on its own.

The module uses an internal-only load balancer (no public endpoints) and defaults to Consumption workload profile with optional dedicated D4 profile via boolean toggle. A three-mode `app_mode` variable controls what gets deployed into the environment (see [App Modes](#app-modes) below).

All networking and container infrastructure resources are tagged per the team tagging strategy.

## Prerequisites

- All [platform landing zone prerequisites](../README.md#prerequisites)
- Platform Landing Zone (`Networking/`) applied first
- Private DNS zones enabled (`add_private_dns00 = true` in Networking)
- Azure region with Container Apps support

## Quick Start

```sh
cd ContainerApps-byoVnet
terraform init && terraform apply
```

**Prerequisites:** Networking module must be applied first with `add_private_dns00 = true`.

## Variables

This module creates its own VNet with subnets and hub connection. Customize networking names, workload profiles, and app deployment mode, or use defaults.

| Variable                         | Default              | Purpose                                                          |
| -------------------------------- | -------------------- | ---------------------------------------------------------------- |
| `app_mode`                       | `"hello-world"`      | Container app to deploy: `none`, `hello-world`, or `mcp-toolbox` |
| `mcp_dashboard_enabled`          | `false`              | Enable MCP Toolbox `/dashboard` and `/api/*` diagnostic endpoints |
| `resource_group_name`            | `"rg-aca00"`         | Resource group name                                              |
| `aca_vnet_address_space`         | `["172.20.64.0/20"]` | VNet address range (Block 4)                                     |
| `aca_subnet_address`             | `["172.20.64.0/27"]` | ACA environment subnet                                           |
| `add_dedicated_workload_profile` | `false`              | Optional D4 dedicated profile                                    |

For subnet addresses, ACR SKU, and other service config, see `variables.tf`.

## Outputs

| Output                           | Purpose                                                 |
| -------------------------------- | ------------------------------------------------------- |
| `aca_environment_id`             | Container Apps Environment ID                           |
| `aca_environment_default_domain` | Default domain for container apps                       |
| `aca_environment_static_ip`      | Static IP of internal load balancer                     |
| `acr_id`                         | Azure Container Registry ID                             |
| `acr_login_server`               | ACR login server URL                                    |
| `aca_identity_id`                | Managed identity for image pulls                        |
| `container_app_id`               | Deployed container app ID (null if `app_mode = "none"`) |
| `container_app_fqdn`             | Container app FQDN (null if `app_mode = "none"`)        |

## App Modes

The `app_mode` variable controls what runs in the ACA environment. The environment and ACR are always deployed regardless of mode.

| Mode                    | What it does                                                                                                                                                                                                             |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `none`                  | ACA environment and ACR only. No container app. Use this when you just need the infrastructure.                                                                                                                          |
| `hello-world` (default) | Deploys the MCR quickstart image (`mcr.microsoft.com/k8se/quickstart`) on port 80. Quick way to verify the environment works. No ACR pull needed.                                                                        |
| `mcp-toolbox`           | Clones the [MCP Toolkit](https://github.com/AiGhostMod/mcpToolkit) repo, builds it via `az acr build` (cloud build, no local Docker needed), and deploys the server on port 8080 with managed identity pulling from ACR. |

The MCP Toolbox container is useful for troubleshooting MCP connections from AI Foundry. It runs a lightweight MCP server inside the same private network, so you can verify connectivity and endpoint resolution without standing up a full application. The MCP server is unauthenticated and for testing purposes only. Source and docs are in the [MCP Toolkit repo](https://github.com/AiGhostMod/mcpToolkit).

To enable the diagnostic dashboard during demos, set `mcp_dashboard_enabled = true`. This exposes `/dashboard` and `/api/*` endpoints for inspecting recent MCP traffic. Off by default — the dashboard can reveal request headers and auth material, so keep it in trusted environments.

Set it in your tfvars or on the command line:

```sh
terraform apply -var 'app_mode=mcp-toolbox'
terraform apply -var 'app_mode=mcp-toolbox' -var 'mcp_dashboard_enabled=true'
```

## Architecture

The module deploys into Block 4 (172.20.64.0/20) of the IP address space. The ACA environment runs with an internal load balancer only (no public IP), and all inbound traffic routes through the virtual hub connection to the platform networking layer.

- **ACA Environment:** Internal-only load balancer, Consumption profile by default, optional dedicated D4 for non-Consumption workloads
- **Azure Container Registry:** Premium SKU (required for private endpoints), admin disabled, public access disabled
- **Managed Identity:** User-assigned identity with AcrPull role for ACA to pull from ACR
- **Private Endpoints:** ACR private endpoint with DNS zone integration
- **DNS:** ACR DNS zone (privatelink.azurecr.io) from platform DNS infrastructure; private endpoint records auto-register

## Firewall Notes

This module assumes **any/any firewall rules** on the platform Firewall (if deployed). If your Firewall is locked down, Container Apps requires outbound access to:

- **Microsoft Container Registry (MCR):** `*.azurecr.io`, `*.blob.core.windows.net` (MCR images)
- **Kubernetes Service dependencies:** `*.azmk8s.io` (AKS dependencies for workload profiles)
- **Azure service endpoints:** `*.servicebus.windows.net`, `*.table.core.windows.net` (internal ACA communication)
- **DNS:** Port 53 (UDP/TCP) to custom DNS servers via the platform resolver

If you are locking down firewall rules, create allow rules for these FQDNs or IP ranges. Consult the [Azure Container Apps networking documentation](https://learn.microsoft.com/en-us/azure/container-apps/networking) for the full list of egress requirements.

## Cleanup

After `terraform destroy`, the Container Apps environment and associated resources are deleted. Unlike AI Foundry, there is no soft-delete grace period or service association link, so the subnet will not be blocked.

```sh
cd ContainerApps-byoVnet
terraform destroy
```

Then destroy the platform:

```sh
cd ../Networking
terraform destroy
```

## Next Steps

- Push your own container images to ACR: `az acr build --registry <acr-name> --image myapp:latest .`
- Create additional container apps in the environment using the Azure CLI or Azure Portal
- Switch app modes any time: `terraform apply -var 'app_mode=none'` to remove the app while keeping the environment
- Enable the dedicated D4 workload profile for non-Consumption workloads via `add_dedicated_workload_profile = true`
