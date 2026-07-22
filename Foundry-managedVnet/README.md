# Application Landing Zone — Microsoft Foundry (Managed VNet)

This is an optional application landing zone. It deploys Microsoft Foundry with Agent Service and private endpoints in a Microsoft-managed VNet. You do not need to deploy this to use the Networking module on its own.

This module is based on the [Microsoft's Terraform sample](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-terraform/18-managed-virtual-network-preview), modified to pull network dependencies from the platform landing zone via `terraform_remote_state`.

The ALZ makes use of private endpoints. Local auth (API keys) is disabled on AI Search and Cognitive Services (`disableLocalAuth = true`). All access requires Entra ID authentication.

The template follows the [documented architecture](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/managed-virtual-network?view=foundry) for Microsoft Foundry Standard Setup with a managed network.

![managedVnetFoundry](../Diagrams/managedVnet-diagram.png)

## Prerequisites

- All [platform landing zone prerequisites](../README.md#prerequisites)
- Platform Landing Zone (`Networking/`) applied first
- Private DNS zones enabled (`add_private_dns00 = true` in Networking)
- Azure region with AI Foundry support and quota

## Quick Start

```sh
cd Foundry-managedVnet
terraform init && terraform apply
```

**Prerequisites:** Networking module must be applied first with `add_private_dns00 = true`.

## Variables

This module deploys Microsoft Foundry in a Microsoft-managed VNet. Customize the resource group name or use defaults.

| Variable                          | Default              | Purpose                                                    |
| --------------------------------- | -------------------- | ---------------------------------------------------------- |
| `resource_group_name_ai01`        | `"rg-ai01"`          | Resource group name                                        |
| `ai_vnet_address_space`           | `["172.20.48.0/20"]` | VNet address range                                         |
| `private_endpoint_subnet_address` | `["172.20.48.0/24"]` | Private endpoint subnet                                    |
| `foundry_mvnet_fw_aoao`           | `false`              | Use the managed firewall with Allow Only Approved Outbound |

For GPT deployment names, SKUs, and other service config, see `variables.tf`.

By default, the Microsoft-managed VNet uses Allow Internet Outbound without a managed firewall or outbound rules. Set `foundry_mvnet_fw_aoao = true` to deploy the managed firewall, switch to Allow Only Approved Outbound, and create the [documented outbound rules](https://learn.microsoft.com/azure/foundry/how-to/managed-virtual-network#required-outbound-rules) for Agents, evaluations and traces, and finetuning. The Storage, Cosmos DB, and AI Search private endpoint rules remain platform-managed.

## Outputs

| Output                  | Purpose               |
| ----------------------- | --------------------- |
| `resource_group_id`     | Resource group ID     |
| `ai_foundry_id`         | AI Foundry account ID |
| `ai_foundry_project_id` | AI Foundry project ID |
| `storage_account_id`    | Storage account ID    |
| `cosmosdb_account_id`   | Cosmos DB account ID  |
| `ai_search_id`          | AI Search service ID  |

## Cleanup

This module does not inject Foundry into the spoke VNet, so it does not create a service association link that requires manual subnet cleanup.

## Security & Privacy — Foundry Trace Logs

> ⚠️ **PII Risk in Agent Traces**
>
> The Foundry project diagnostic setting captures Trace Logs via the `allLogs` category group. Per [Microsoft's documentation](https://learn.microsoft.com/azure/foundry/observability/how-to/trace-agent-setup#security-and-privacy), these traces may contain user inputs, model outputs, and tool arguments — i.e., sensitive content and PII. All trace data flows into the Log Analytics workspace, where it is queryable by anyone with `Log Analytics Reader` role.
>
> Before graduating this lab to production, review your data handling requirements. If PII handling is critical, consider excluding `Trace Logs` from the project diagnostic setting or restricting Log Analytics access via Azure RBAC.
