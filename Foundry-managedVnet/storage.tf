########## Create resources required to for agent data storage
##########

## Create a storage account for agent data
##
resource "azurerm_storage_account" "storage_account" {
  name                = "foundry${random_string.unique.result}storage01"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  ## Identity configuration
  shared_access_key_enabled = false

  # Ignore changes to queue/blob/file/table properties to avoid validation issues
  lifecycle {
    ignore_changes = [
      queue_properties,
      blob_properties,
      share_properties
    ]
  }

  ## Network access configuration
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.common_tags
  network_rules {
    default_action = "Deny"
    bypass = [
      "AzureServices"
    ]
  }
}

# Private Endpoint for Blob
resource "azurerm_private_endpoint" "pe-storage-blob" {
  # Sequential PE creation required — parallel creation causes subnet update races
  # and account provisioning timing issues on fresh deploys. PG-validated pattern.
  depends_on = [azurerm_private_endpoint.pe-cosmosdb]

  name                = "${azurerm_storage_account.storage_account.name}-pe-blob"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id
  tags                = local.common_tags
  private_service_connection {
    name                           = "${azurerm_storage_account.storage_account.name}-pe-blob-connection"
    private_connection_resource_id = azurerm_storage_account.storage_account.id
    subresource_names = [
      "blob"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azurerm_storage_account.storage_account.name}-blob-dns-group"
    private_dns_zone_ids = [
      data.terraform_remote_state.networking.outputs.dns_zone_blob_id
    ]
  }
}

# Private Endpoint for File
resource "azurerm_private_endpoint" "pe-storage_file" {
  depends_on = [azurerm_private_endpoint.pe-storage-blob]

  name                = "${azurerm_storage_account.storage_account.name}-pe-file"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${azurerm_storage_account.storage_account.name}-pe-file-connection"
    private_connection_resource_id = azurerm_storage_account.storage_account.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  private_dns_zone_group {
    name = "${azurerm_storage_account.storage_account.name}-file-dns-group"
    private_dns_zone_ids = [
      data.terraform_remote_state.networking.outputs.dns_zone_file_id
    ]
  }
}

# Private Endpoint for Table
resource "azurerm_private_endpoint" "pe-storage_table" {
  depends_on = [azurerm_private_endpoint.pe-storage_file]

  name                = "${azurerm_storage_account.storage_account.name}-pe-table"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${azurerm_storage_account.storage_account.name}-pe-table-connection"
    private_connection_resource_id = azurerm_storage_account.storage_account.id
    is_manual_connection           = false
    subresource_names              = ["table"]
  }

  private_dns_zone_group {
    name = "${azurerm_storage_account.storage_account.name}-table-dns-group"
    private_dns_zone_ids = [
      data.terraform_remote_state.networking.outputs.dns_zone_table_id
    ]
  }
}

# Private Endpoint for Queue
resource "azurerm_private_endpoint" "pe-storage_queue" {
  depends_on = [azurerm_private_endpoint.pe-storage_table]

  name                = "${azurerm_storage_account.storage_account.name}-pe-queue"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${azurerm_storage_account.storage_account.name}-pe-queue-connection"
    private_connection_resource_id = azurerm_storage_account.storage_account.id
    is_manual_connection           = false
    subresource_names              = ["queue"]
  }

  private_dns_zone_group {
    name = "${azurerm_storage_account.storage_account.name}-queue-dns-group"
    private_dns_zone_ids = [
      data.terraform_remote_state.networking.outputs.dns_zone_queue_id
    ]
  }
}

# Wait duration from PG-validated reference implementation. Do not reduce without testing.
resource "time_sleep" "wait_storage" {
  create_duration = "10m"

  depends_on = [
    azurerm_storage_account.storage_account,
    azurerm_private_endpoint.pe-storage-blob,
    azurerm_private_endpoint.pe-storage_file,
    azurerm_private_endpoint.pe-storage_table,
    azurerm_private_endpoint.pe-storage_queue
  ]
}
