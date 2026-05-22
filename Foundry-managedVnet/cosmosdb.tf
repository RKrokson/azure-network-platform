## Create the Cosmos DB account to store agent threads
##
resource "azurerm_cosmosdb_account" "cosmosdb" {
  name                = "foundry${random_string.unique.result}cosmosdb"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location

  # General settings
  offer_type        = "Standard"
  kind              = "GlobalDocumentDB"
  free_tier_enabled = false

  # Set security-related settings
  local_authentication_disabled         = true
  public_network_access_enabled         = false
  network_acl_bypass_for_azure_services = false

  # Set high availability and failover settings
  automatic_failover_enabled       = false
  multiple_write_locations_enabled = false
  tags                             = local.common_tags

  # Configure consistency settings
  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  # Configure single location with no zone redundancy to reduce costs
  geo_location {
    location          = azurerm_resource_group.rg-ai01.location
    failover_priority = 0
    zone_redundant    = false
  }
}

resource "azurerm_private_endpoint" "pe-cosmosdb" {
  name                = "${azurerm_cosmosdb_account.cosmosdb.name}-private-endpoint"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${azurerm_cosmosdb_account.cosmosdb.name}-pe-connection"
    private_connection_resource_id = azurerm_cosmosdb_account.cosmosdb.id
    subresource_names = [
      "Sql"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azurerm_cosmosdb_account.cosmosdb.name}-dns-group"
    private_dns_zone_ids = [
      data.terraform_remote_state.networking.outputs.dns_zone_documents_id
    ]
  }
}

# Wait duration from PG-validated reference implementation. Do not reduce without testing.
resource "time_sleep" "wait_cosmos" {
  create_duration = "10m"

  depends_on = [
    azurerm_cosmosdb_account.cosmosdb,
    azurerm_private_endpoint.pe-cosmosdb
  ]
}
