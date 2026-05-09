# Pre-reqs and/or foundational resources
resource "random_string" "unique" {
  length      = 4
  min_numeric = 4
  numeric     = true
  special     = false
  lower       = true
  upper       = false
}
data "azurerm_client_config" "current" {
}
# Random password generator
resource "random_password" "vm_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}
resource "azurerm_resource_group" "rg-kv00" {
  name     = "${var.resource_group_name_kv}-${var.azure_region_0_abbr}-${local.suffix}"
  location = var.azure_region_0_name
  tags     = local.common_tags
}
resource "azurerm_key_vault" "kv00" {
  name                = "${var.kv_name}-${var.azure_region_0_abbr}-${local.suffix}"
  location            = azurerm_resource_group.rg-kv00.location
  resource_group_name = azurerm_resource_group.rg-kv00.name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.common_tags
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = ["Get", "Set", "List", "Delete", "Purge"]
  }
}
resource "azurerm_key_vault_secret" "vm_password" {
  name         = var.kv_secret_name
  value        = random_password.vm_password.result
  key_vault_id = azurerm_key_vault.kv00.id
}
data "azurerm_key_vault_secret" "vm_password" {
  key_vault_id = azurerm_key_vault.kv00.id
  name         = var.kv_secret_name
  depends_on   = [azurerm_key_vault_secret.vm_password]
}

resource "azurerm_monitor_diagnostic_setting" "kv_logs" {
  name               = "kv-logs-${var.azure_region_0_abbr}-${local.suffix}"
  target_resource_id = azurerm_key_vault.kv00.id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.law00.id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
