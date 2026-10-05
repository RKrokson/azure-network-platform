########## Create resources required to for agent data storage
##########

## Create a storage account for agent data
##
resource "azurerm_storage_account" "storage_account" {
  count = var.deploy_agent_data_services ? 1 : 0

  name                = "${local.account_name}st"
  resource_group_name = azurerm_resource_group.rg-ai00.name
  location            = azurerm_resource_group.rg-ai00.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  ## Identity configuration
  shared_access_key_enabled = false

  ## Network access configuration
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = var.common_tags
  network_rules {
    default_action = "Deny"
    bypass = [
      "AzureServices"
    ]
  }

  # Tenant governance policy (Modify effect) can disable public network access at create time.
  lifecycle {
    ignore_changes = [
      public_network_access_enabled
    ]
  }
}

## Create Private Endpoint for storage
##
resource "azurerm_private_endpoint" "pe-storage" {
  count = var.deploy_agent_data_services ? 1 : 0

  # Sequential PE creation required — parallel creation causes subnet update races
  # and account provisioning timing issues on fresh deploys. PG-validated pattern.
  depends_on = [azurerm_private_endpoint.pe-cosmosdb]

  name                = "${azurerm_storage_account.storage_account[0].name}-private-endpoint"
  resource_group_name = azurerm_resource_group.rg-ai00.name
  location            = azurerm_resource_group.rg-ai00.location
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id
  tags                = var.common_tags
  private_service_connection {
    name                           = "${azurerm_storage_account.storage_account[0].name}-private-link-service-connection"
    private_connection_resource_id = azurerm_storage_account.storage_account[0].id
    subresource_names = [
      "blob"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azurerm_storage_account.storage_account[0].name}-dns-config"
    private_dns_zone_ids = [
      var.platform.private_dns_zone_ids.blob
    ]
  }
}
