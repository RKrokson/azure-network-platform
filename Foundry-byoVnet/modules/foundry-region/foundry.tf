########## Create AI Foundry resource
##########

## Create the AI Foundry resource
##
resource "azapi_resource" "foundry" {
  type                      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name                      = local.account_name
  parent_id                 = azurerm_resource_group.rg-ai00.id
  location                  = azurerm_resource_group.rg-ai00.location
  schema_validation_enabled = false
  tags                      = var.common_tags

  body = {
    kind = "AIServices",
    sku = {
      name = var.foundry_sku
    }
    identity = {
      type = "SystemAssigned"
    }

    properties = {

      disableLocalAuth = true

      # Specifies that this is an AI Foundry resource
      allowProjectManagement = true

      # Set custom subdomain name for DNS names created for this Foundry resource
      customSubDomainName = local.account_name

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

  response_export_values = [
    "properties.endpoint"
  ]

}

moved {
  from = azurerm_cognitive_deployment.aifoundry_deployment_gpt_4o
  to   = azurerm_cognitive_deployment.aifoundry_deployment
}

## Create a deployment for the configured OpenAI model in the AI Foundry resource
##
resource "azurerm_cognitive_deployment" "aifoundry_deployment" {
  name                 = var.gpt_model_deployment_name
  cognitive_account_id = azapi_resource.foundry.id
  rai_policy_name      = "Microsoft.DefaultV2"

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

# The Foundry account reports a completed create while still in provisioning state
# "Accepted", and a private endpoint against it then fails with
# AccountProvisioningStateInvalid. The data service endpoint chain covers that window
# during initial creation, but not when the Foundry account is replaced. Keep the wait
# unconditional so both deployment modes cover initial creation and replacement.
resource "time_sleep" "wait_foundry_account" {
  depends_on = [
    azapi_resource.foundry
  ]
  create_duration = "180s"

  lifecycle {
    replace_triggered_by = [
      azapi_resource.foundry
    ]
  }
}

## Create Private Endpoint for AI Foundry (Cognitive Services)
##
resource "azurerm_private_endpoint" "pe-aifoundry" {
  depends_on = [
    azurerm_private_endpoint.pe-aisearch,
    time_sleep.wait_foundry_account
  ]

  name                = "${azapi_resource.foundry.name}-private-endpoint"
  resource_group_name = azurerm_resource_group.rg-ai00.name
  location            = azurerm_resource_group.rg-ai00.location
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id
  tags                = var.common_tags

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
      var.platform.private_dns_zone_ids.cognitiveservices,
      var.platform.private_dns_zone_ids.services_ai,
      var.platform.private_dns_zone_ids.openai
    ]
  }
}
