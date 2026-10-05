## Create an AI Search instance that will be used to store vector embeddings
##
resource "azapi_resource" "ai_search" {
  count = var.deploy_agent_data_services ? 1 : 0

  type                      = "Microsoft.Search/searchServices@2024-06-01-preview"
  name                      = "${local.account_name}search"
  parent_id                 = azurerm_resource_group.rg-ai00.id
  location                  = azurerm_resource_group.rg-ai00.location
  schema_validation_enabled = true
  tags                      = var.common_tags

  body = {
    sku = {
      name = var.ai_search_sku
    }

    identity = {
      type = "SystemAssigned"
    }

    properties = {

      # Search-specific properties
      replicaCount   = 1
      partitionCount = 1
      hostingMode    = "default"
      semanticSearch = "disabled"

      # Identity-related controls
      disableLocalAuth = true

      # Networking-related controls
      publicNetworkAccess = "Disabled"
      networkRuleSet = {
        bypass = "None"
      }
    }
  }
}

## Create Private Endpoint for AI Search
##
resource "azurerm_private_endpoint" "pe-aisearch" {
  count = var.deploy_agent_data_services ? 1 : 0

  depends_on = [azurerm_private_endpoint.pe-storage]

  name                = "${azapi_resource.ai_search[0].name}-private-endpoint"
  resource_group_name = azurerm_resource_group.rg-ai00.name
  location            = azurerm_resource_group.rg-ai00.location
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id
  tags                = var.common_tags

  private_service_connection {
    name                           = "${azapi_resource.ai_search[0].name}-private-link-service-connection"
    private_connection_resource_id = azapi_resource.ai_search[0].id
    subresource_names = [
      "searchService"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azapi_resource.ai_search[0].name}-dns-config"
    private_dns_zone_ids = [
      var.platform.private_dns_zone_ids.search
    ]
  }
}
