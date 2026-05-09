########## Azure Container Registry — Private with Managed Identity
##########

# User-assigned managed identity for ACA to pull from ACR
resource "azurerm_user_assigned_identity" "aca_identity" {
  name                = "id-aca-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  location            = azurerm_resource_group.rg_aca00.location
  resource_group_name = azurerm_resource_group.rg_aca00.name
  tags                = local.common_tags
}

# Azure Container Registry (Premium required for private endpoints)
resource "azurerm_container_registry" "acr" {
  name                          = "${var.acr_name}${random_string.unique.result}"
  resource_group_name           = azurerm_resource_group.rg_aca00.name
  location                      = azurerm_resource_group.rg_aca00.location
  sku                           = var.acr_sku
  admin_enabled                 = false
  public_network_access_enabled = var.app_mode == "mcp-toolbox" ? true : false
  tags                          = local.common_tags
}

# Grant AcrPull to the managed identity
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aca_identity.principal_id
}

# Private endpoint for ACR
# DNS zone (privatelink.azurecr.io) is owned by the Networking module's AVM private DNS —
# PE records auto-register there via the dns_zone_group.
resource "azurerm_private_endpoint" "acr_pe" {
  name                = "pe-acr-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  location            = azurerm_resource_group.rg_aca00.location
  resource_group_name = azurerm_resource_group.rg_aca00.name
  subnet_id           = azurerm_subnet.pe_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "psc-acr-${random_string.unique.result}"
    private_connection_resource_id = azurerm_container_registry.acr.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [data.terraform_remote_state.networking.outputs.dns_zone_acr_id]
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_acr" {
  name               = "diag-acr-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  target_resource_id = azurerm_container_registry.acr.id

  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }
  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  metric {
    category = "AllMetrics"
  }
}
