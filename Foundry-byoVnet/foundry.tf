########## Create AI Foundry resource
##########

## Create the AI Foundry resource
##
resource "azapi_resource" "foundry" {
  type                      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name                      = "aifoundry${random_string.unique.result}"
  parent_id                 = azurerm_resource_group.rg-ai00.id
  location                  = azurerm_resource_group.rg-ai00.location
  schema_validation_enabled = false
  tags                      = local.common_tags

  body = {
    kind = "AIServices",
    sku = {
      name = var.foundry_sku
    }
    identity = {
      type = "SystemAssigned"
    }

    properties = {

      # Must remain false for BYO VNet — the Foundry Agent proxy requires local auth
      # for internal communication. See PG reference: 15b-private-network-standard-agent-setup-byovnet
      disableLocalAuth = false

      # Specifies that this is an AI Foundry resource
      allowProjectManagement = true

      # Set custom subdomain name for DNS names created for this Foundry resource
      customSubDomainName = "aifoundry${random_string.unique.result}"

      # Network-related controls
      # Disable public access but allow Trusted Azure Services exception
      publicNetworkAccess = "Disabled"
      # defaultAction must be "Allow" with publicNetworkAccess "Disabled" — this combo
      # blocks external callers while preserving internal first-party service access
      # required by the Foundry Agent proxy. See PG reference: 15b-private-network-standard-agent-setup-byovnet
      networkAcls = {
        defaultAction = "Allow"
      }

      # Enable VNet injection for Standard Agents
      networkInjections = [
        {
          scenario                   = "agent"
          subnetArmId                = azurerm_subnet.ai_foundry_subnet.id
          useMicrosoftManagedNetwork = false
        }
      ]
    }
  }
}

## Create a deployment for OpenAI's GPT-5.4 (2026-03-05) in the AI Foundry resource
##
resource "azurerm_cognitive_deployment" "aifoundry_deployment_gpt_4o" {
  name                 = var.gpt_model_deployment_name
  cognitive_account_id = azapi_resource.foundry.id

  sku {
    name     = var.gpt_model_sku_name
    capacity = var.gpt_model_capacity
  }

  model {
    format  = "OpenAI"
    name    = var.gpt_model_name
    version = var.gpt_model_version
  }
}

## Create Private Endpoint for AI Foundry (Cognitive Services)
##
resource "azurerm_private_endpoint" "pe-aifoundry" {
  depends_on = [azurerm_private_endpoint.pe-aisearch]

  name                = "${azapi_resource.foundry.name}-private-endpoint"
  resource_group_name = azurerm_resource_group.rg-ai00.name
  location            = azurerm_resource_group.rg-ai00.location
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${azapi_resource.foundry.name}-private-link-service-connection"
    private_connection_resource_id = azapi_resource.foundry.id
    subresource_names = [
      "account"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azapi_resource.foundry.name}-dns-config"
    private_dns_zone_ids = [
      data.terraform_remote_state.networking.outputs.dns_zone_cognitiveservices_id,
      data.terraform_remote_state.networking.outputs.dns_zone_services_ai_id,
      data.terraform_remote_state.networking.outputs.dns_zone_openai_id
    ]
  }
}
