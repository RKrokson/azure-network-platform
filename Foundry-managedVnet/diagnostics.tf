## Diagnostic settings — routes all Foundry-managedVnet resource logs to law00

resource "azurerm_monitor_diagnostic_setting" "diag_foundry" {
  name               = "diag-foundry-${random_string.unique.result}"
  target_resource_id = azapi_resource.foundry.id

  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id

  enabled_log {
    category = "Audit"
  }
  enabled_log {
    category = "RequestResponse"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_aisearch" {
  name               = "diag-aisearch-${random_string.unique.result}"
  target_resource_id = azapi_resource.ai_search.id

  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id

  enabled_log {
    category = "OperationLogs"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_cosmosdb" {
  name               = "diag-cosmosdb-${random_string.unique.result}"
  target_resource_id = azurerm_cosmosdb_account.cosmosdb.id

  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id

  enabled_log {
    category = "DataPlaneRequests"
  }
  enabled_log {
    category = "QueryRuntimeStatistics"
  }

  metric {
    category = "AllMetrics"
  }
}

# All four storage sub-services get individual diag settings per Ryan's directive

resource "azurerm_monitor_diagnostic_setting" "diag_storage_blob" {
  name               = "diag-storage-blob-${random_string.unique.result}"
  target_resource_id = "${azurerm_storage_account.storage_account.id}/blobServices/default"

  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }
  enabled_log {
    category = "StorageWrite"
  }
  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_storage_file" {
  name               = "diag-storage-file-${random_string.unique.result}"
  target_resource_id = "${azurerm_storage_account.storage_account.id}/fileServices/default"

  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }
  enabled_log {
    category = "StorageWrite"
  }
  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_storage_table" {
  name               = "diag-storage-table-${random_string.unique.result}"
  target_resource_id = "${azurerm_storage_account.storage_account.id}/tableServices/default"

  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }
  enabled_log {
    category = "StorageWrite"
  }
  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_storage_queue" {
  name               = "diag-storage-queue-${random_string.unique.result}"
  target_resource_id = "${azurerm_storage_account.storage_account.id}/queueServices/default"

  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }
  enabled_log {
    category = "StorageWrite"
  }
  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "AllMetrics"
  }
}
