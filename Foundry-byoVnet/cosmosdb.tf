## Create the Cosmos DB account to store agent threads
##
resource "azurerm_cosmosdb_account" "cosmosdb" {
  name                = "aifoundry${random_string.unique.result}cosmosdb"
  resource_group_name = azurerm_resource_group.rg-ai00.name
  location            = azurerm_resource_group.rg-ai00.location

  # General settings
  offer_type        = "Standard"
  kind              = "GlobalDocumentDB"
  free_tier_enabled = false

  # Set security-related settings
  local_authentication_disabled = true
  public_network_access_enabled = false

  # Set high availability and failover settings
  automatic_failover_enabled       = false
  multiple_write_locations_enabled = false
  tags                             = local.common_tags

  # Configure consistency settings
  consistency_policy {
    consistency_level = "Session"
  }

  # Configure single location with no zone redundancy to reduce costs
  geo_location {
    location          = azurerm_resource_group.rg-ai00.location
    failover_priority = 0
    zone_redundant    = false
  }
}

## Create Private Endpoint for Cosmos DB
##
resource "azurerm_private_endpoint" "pe-cosmosdb" {
  name                = "${azurerm_cosmosdb_account.cosmosdb.name}-private-endpoint"
  resource_group_name = azurerm_resource_group.rg-ai00.name
  location            = azurerm_resource_group.rg-ai00.location
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${azurerm_cosmosdb_account.cosmosdb.name}-private-link-service-connection"
    private_connection_resource_id = azurerm_cosmosdb_account.cosmosdb.id
    subresource_names = [
      "Sql"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azurerm_cosmosdb_account.cosmosdb.name}-dns-config"
    private_dns_zone_ids = [
      data.terraform_remote_state.networking.outputs.dns_zone_documents_id
    ]
  }
}
