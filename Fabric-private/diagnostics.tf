## Diagnostic settings — routes Fabric-private resource logs to law00.
## All resources here are gated on local.deploy_outbound to match their parent resources.

resource "azurerm_monitor_diagnostic_setting" "diag_fabric_kv" {
  count              = local.deploy_outbound ? 1 : 0
  name               = "diag-fabric-kv-${random_string.unique.result}"
  target_resource_id = azurerm_key_vault.fabric_kv[0].id

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

resource "azurerm_monitor_diagnostic_setting" "diag_lab_storage_blob" {
  count              = local.deploy_outbound ? 1 : 0
  name               = "diag-lab-storage-blob-${random_string.unique.result}"
  target_resource_id = "${azurerm_storage_account.lab_storage[0].id}/blobServices/default"

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

resource "azurerm_monitor_diagnostic_setting" "diag_lab_sql_db" {
  count              = local.deploy_outbound ? 1 : 0
  name               = "diag-lab-sql-db-${random_string.unique.result}"
  target_resource_id = azurerm_mssql_database.lab_db[0].id

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
