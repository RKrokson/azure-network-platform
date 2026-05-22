########## Create Foundry resource
##########

## Create the Foundry resource
##
resource "azapi_resource" "foundry" {
  type      = "Microsoft.CognitiveServices/accounts@2025-10-01-preview"
  name      = "foundry${random_string.unique.result}"
  parent_id = azurerm_resource_group.rg-ai01.id
  location  = azurerm_resource_group.rg-ai01.location

  schema_validation_enabled = false
  tags                      = local.common_tags

  response_export_values = [
    "identity.principalId"
  ]

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices",
    sku = {
      name = var.foundry_sku
    }
    properties = {

      # Support Entra ID and disable API Key authentication for underlining Cognitive Services account
      disableLocalAuth = true

      # Specifies that this is a Foundry resource
      allowProjectManagement = true

      # Set custom subdomain name for DNS names created for this Foundry resource
      customSubDomainName = "foundry${random_string.unique.result}"

      # Network-related controls
      # Disable public access but allow Trusted Azure Services exception
      publicNetworkAccess = "Disabled"
      networkAcls = {
        defaultAction       = "Deny"
        virtualNetworkRules = []
        ipRules             = []
      }

      # Enable VNet injection for Standard Agents
      networkInjections = [
        {
          scenario                   = "agent"
          subnetArmId                = ""
          useMicrosoftManagedNetwork = true
        }
      ]
      userOwnedStorage = [
        {
          resourceId = azurerm_storage_account.storage_account.id
        }
      ]
      userOwnedCosmosDB = [
        {
          resourceId = azurerm_cosmosdb_account.cosmosdb.id
        }
      ]
      userOwnedSearch = [
        {
          resourceId = azapi_resource.ai_search.id
        }
      ]
    }
  }

  lifecycle {
    ignore_changes = [
      body["properties"]["restore"],
      output
    ]
  }
}

# Create Private Endpoints for foundry

resource "azurerm_private_endpoint" "pe-foundry" {
  depends_on = [
    azurerm_private_endpoint.pe-aisearch
  ]

  name                = "${azapi_resource.foundry.name}-private-endpoint"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location
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

## Create a deployment for OpenAI's GPT-5.4 (2026-03-05) in the Foundry resource
##
resource "azurerm_cognitive_deployment" "foundry_deployment_gpt_4o" {
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
