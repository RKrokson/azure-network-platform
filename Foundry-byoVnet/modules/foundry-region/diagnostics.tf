## Diagnostic settings — routes all Foundry-byoVnet resource logs to law00

resource "azurerm_monitor_diagnostic_setting" "diag_foundry" {
  name               = "diag-foundry-${var.name_suffix}"
  target_resource_id = azapi_resource.foundry.id

  log_analytics_workspace_id = var.log_analytics_workspace_id

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
  count = var.deploy_agent_data_services ? 1 : 0

  name               = "diag-aisearch-${var.name_suffix}"
  target_resource_id = azapi_resource.ai_search[0].id

  log_analytics_workspace_id = var.log_analytics_workspace_id

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
  count = var.deploy_agent_data_services ? 1 : 0

  name               = "diag-cosmosdb-${var.name_suffix}"
  target_resource_id = azurerm_cosmosdb_account.cosmosdb[0].id

  log_analytics_workspace_id = var.log_analytics_workspace_id
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
  count = var.deploy_agent_data_services ? 1 : 0

  name               = "diag-storage-blob-${var.name_suffix}"
  target_resource_id = "${azurerm_storage_account.storage_account[0].id}/blobServices/default"

  log_analytics_workspace_id = var.log_analytics_workspace_id

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
  count = var.deploy_agent_data_services ? 1 : 0

  name               = "diag-storage-file-${var.name_suffix}"
  target_resource_id = "${azurerm_storage_account.storage_account[0].id}/fileServices/default"

  log_analytics_workspace_id = var.log_analytics_workspace_id

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
  count = var.deploy_agent_data_services ? 1 : 0

  name               = "diag-storage-queue-${var.name_suffix}"
  target_resource_id = "${azurerm_storage_account.storage_account[0].id}/queueServices/default"

  log_analytics_workspace_id = var.log_analytics_workspace_id

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
  count = var.deploy_agent_data_services ? 1 : 0

  name               = "diag-storage-table-${var.name_suffix}"
  target_resource_id = "${azurerm_storage_account.storage_account[0].id}/tableServices/default"

  log_analytics_workspace_id = var.log_analytics_workspace_id

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
  count = var.deploy_agent_data_services ? 1 : 0

  name               = "diag-storage-account-${var.name_suffix}"
  target_resource_id = azurerm_storage_account.storage_account[0].id

  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "Transaction"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_foundry_project" {
  name               = "diag-project-${var.name_suffix}"
  target_resource_id = azapi_resource.foundry_project.id

  log_analytics_workspace_id = var.log_analytics_workspace_id

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
  name               = "diag-nsg-foundry-${var.name_suffix}"
  target_resource_id = azurerm_network_security_group.ai_foundry_subnet_nsg.id

  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }
}
