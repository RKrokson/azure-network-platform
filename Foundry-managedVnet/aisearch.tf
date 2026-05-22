## Create an AI Search instance that will be used to store vector embeddings
##
resource "azapi_resource" "ai_search" {
  type                      = "Microsoft.Search/searchServices@2025-02-01-preview"
  name                      = "foundry${random_string.unique.result}search"
  parent_id                 = azurerm_resource_group.rg-ai01.id
  location                  = azurerm_resource_group.rg-ai01.location
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

resource "azurerm_private_endpoint" "pe-aisearch" {
  depends_on = [azurerm_private_endpoint.pe-storage_queue]

  name                = "${azapi_resource.ai_search.name}-private-endpoint"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location
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

# Wait duration from PG-validated reference implementation. Do not reduce without testing.
resource "time_sleep" "wait_aisearch" {
  create_duration = "10m"

  depends_on = [
    azapi_resource.ai_search,
    azurerm_private_endpoint.pe-aisearch
  ]
}
