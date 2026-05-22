## Create an AI Search instance that will be used to store vector embeddings
##
resource "azapi_resource" "ai_search" {
  type                      = "Microsoft.Search/searchServices@2024-06-01-preview"
  name                      = "aifoundry${random_string.unique.result}search"
  parent_id                 = azurerm_resource_group.rg-ai00.id
  location                  = azurerm_resource_group.rg-ai00.location
  schema_validation_enabled = true
  tags                      = local.common_tags

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
      publicNetworkAccess = "disabled"
      networkRuleSet = {
        bypass = "None"
      }
    }
  }
}

## Create Private Endpoint for AI Search
##
resource "azurerm_private_endpoint" "pe-aisearch" {
  depends_on = [azurerm_private_endpoint.pe-storage]

  name                = "${azapi_resource.ai_search.name}-private-endpoint"
  resource_group_name = azurerm_resource_group.rg-ai00.name
  location            = azurerm_resource_group.rg-ai00.location
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${azapi_resource.ai_search.name}-private-link-service-connection"
    private_connection_resource_id = azapi_resource.ai_search.id
    subresource_names = [
      "searchService"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azapi_resource.ai_search.name}-dns-config"
    private_dns_zone_ids = [
      data.terraform_remote_state.networking.outputs.dns_zone_search_id
    ]
  }
}
