## Diagnostic settings — routes all Foundry-byoVnet resource logs to law00

resource "azurerm_monitor_diagnostic_setting" "diag_foundry" {
  name               = "diag-foundry-${random_string.unique.result}"
  target_resource_id = azapi_resource.foundry.id

  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id

  enabled_log {
    category_group = "audit"
  }
  enabled_log {
    category_group = "allLogs"
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
    category_group = "audit"
  }
  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_cosmosdb" {
  name               = "diag-cosmosdb-${random_string.unique.result}"
  target_resource_id = azurerm_cosmosdb_account.cosmosdb.id

  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id
  # Dedicated = Resource-specific schema (not legacy AzureDiagnostics) — required for Cosmos per portal finding #6
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "audit"
  }
  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_storage_blob" {
  name               = "diag-storage-blob-${random_string.unique.result}"
  target_resource_id = "${azurerm_storage_account.storage_account.id}/blobServices/default"

  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id

  enabled_log {
    category_group = "audit"
  }
  enabled_log {
    category_group = "allLogs"
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
    category_group = "audit"
  }
  enabled_log {
    category_group = "allLogs"
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
    category_group = "audit"
  }
  enabled_log {
    category_group = "allLogs"
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
    category_group = "audit"
  }
  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
  }
}

# Storage account parent — metrics only. No log categories exist at parent level; logs live at sub-service tier.
# Azure only exposes the Transaction metric at Microsoft.Storage/storageAccounts parent scope.
resource "azurerm_monitor_diagnostic_setting" "diag_storage_account" {
  name               = "diag-storage-account-${random_string.unique.result}"
  target_resource_id = azurerm_storage_account.storage_account.id

  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id

  metric {
    category = "Transaction"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_foundry_project" {
  name               = "diag-project-${random_string.unique.result}"
  target_resource_id = azapi_resource.foundry_project.id

  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id

  enabled_log {
    category_group = "audit"
  }
  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_nsg_foundry" {
  name               = "diag-nsg-foundry-${random_string.unique.result}"
  target_resource_id = azurerm_network_security_group.ai_foundry_subnet_nsg.id

  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }
}
