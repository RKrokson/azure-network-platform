## Region 0 permanent resources
resource "azurerm_resource_group" "rg-net00" {
  name     = "${var.resource_group_name_net00}-${var.azure_region_0_abbr}-${local.suffix}"
  location = var.azure_region_0_name
  tags     = local.common_tags
}
resource "azurerm_log_analytics_workspace" "law00" {
  name                = "${var.log_analytics_workspace_name}-${var.azure_region_0_abbr}"
  resource_group_name = local.rg00_name
  location            = local.rg00_location
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_days
  tags                = local.common_tags
}
# Optional vHub 01 resources
resource "azurerm_resource_group" "rg-net01" {
  count    = var.create_vhub01 ? 1 : 0
  name     = "${var.resource_group_name_net01}-${var.azure_region_1_abbr}-${local.suffix}"
  location = var.azure_region_1_name
  tags     = local.common_tags
}

# ── Region Module Calls ────────────────────────────────────────

module "region0" {
  source = "./modules/region-hub"

  # Context
  resource_group_name        = azurerm_resource_group.rg-net00.name
  resource_group_location    = azurerm_resource_group.rg-net00.location
  resource_group_id          = azurerm_resource_group.rg-net00.id
  region_abbr                = var.azure_region_0_abbr
  suffix                     = local.suffix
  common_tags                = local.common_tags
  virtual_wan_id             = azurerm_virtual_wan.vwan.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law00.id
  vm_admin_username          = var.vm_admin_username
  vm_admin_password          = data.azurerm_key_vault_secret.vm_password.value

  # Hub
  hub_name           = var.azurerm_virtual_hub00_name
  hub_address_prefix = var.azurerm_vhub00_address_prefix
  hub_route_pref     = var.azurerm_vhub00_route_pref

  # Shared VNet
  shared_vnet_name              = var.shared_vnet_name00
  shared_vnet_address_space     = var.shared_vnet_address_space00
  shared_subnet_name            = var.shared_subnet_name00
  shared_subnet_address         = var.shared_subnet_address00
  app_subnet_name               = var.app_subnet_name00
  app_subnet_address            = var.app_subnet_address00
  bastion_subnet_address        = var.bastion_subnet_address00
  hub_to_shared_connection_name = var.azurerm_virtual_hub_connection_vhub00_to_shared00

  # Firewall
  add_firewall                = var.add_firewall00
  firewall_name               = var.firewall_name00
  firewall_sku_name           = var.firewall_sku_name00
  firewall_sku_tier           = var.firewall_sku_tier00
  firewall_availability_zones = var.firewall_availability_zones
  firewall_policy_name        = var.firewall_policy_name00
  firewall_policy_rcg_name    = var.firewall_policy_rcg_name00
  firewall_logs_name          = var.firewall_logs_name00

  # DNS
  add_private_dns                   = var.add_private_dns00
  dns_vnet_name                     = var.dns_vnet_name00
  dns_vnet_address_space            = var.dns_vnet_address_space00
  hub_to_dns_connection_name        = var.azurerm_virtual_hub_connection_vhub00_to_dns00
  resolver_inbound_subnet_name      = var.resolver_inbound_subnet_name00
  resolver_inbound_subnet_address   = var.resolver_inbound_subnet_address00
  resolver_inbound_endpoint_address = var.resolver_inbound_endpoint_address00
  resolver_outbound_subnet_name     = var.resolver_outbound_subnet_name00
  resolver_outbound_subnet_address  = var.resolver_outbound_subnet_address00
  private_resolver_name             = var.private_resolver_name00
  dns_forwarder_ip                  = var.dns_forwarder_ip

  # Compute
  bastion_pip_name  = var.bastion_pip_name00
  bastion_host_name = var.bastion_host_name00
  bastion_host_sku  = var.bastion_host_sku00
  vm_nic_name       = var.vm00_nic_name
  vm_name           = var.vm00_name
  vm_size           = var.vm00_size
}

module "region1" {
  count  = var.create_vhub01 ? 1 : 0
  source = "./modules/region-hub"

  # Context
  resource_group_name        = azurerm_resource_group.rg-net01[0].name
  resource_group_location    = azurerm_resource_group.rg-net01[0].location
  resource_group_id          = azurerm_resource_group.rg-net01[0].id
  region_abbr                = var.azure_region_1_abbr
  suffix                     = local.suffix
  common_tags                = local.common_tags
  virtual_wan_id             = azurerm_virtual_wan.vwan.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law00.id
  vm_admin_username          = var.vm_admin_username
  vm_admin_password          = data.azurerm_key_vault_secret.vm_password.value

  # Hub
  hub_name           = var.azurerm_virtual_hub01_name
  hub_address_prefix = var.azurerm_vhub01_address_prefix
  hub_route_pref     = var.azurerm_vhub01_route_pref

  # Shared VNet
  shared_vnet_name              = var.shared_vnet_name01
  shared_vnet_address_space     = var.shared_vnet_address_space01
  shared_subnet_name            = var.shared_subnet_name01
  shared_subnet_address         = var.shared_subnet_address01
  app_subnet_name               = var.app_subnet_name01
  app_subnet_address            = var.app_subnet_address01
  bastion_subnet_address        = var.bastion_subnet_address01
  hub_to_shared_connection_name = var.azurerm_virtual_hub_connection_vhub01_to_shared01

  # Firewall
  add_firewall                = var.add_firewall01
  firewall_name               = var.firewall_name01
  firewall_sku_name           = var.firewall_sku_name01
  firewall_sku_tier           = var.firewall_sku_tier01
  firewall_availability_zones = var.firewall_availability_zones
  firewall_policy_name        = var.firewall_policy_name01
  firewall_policy_rcg_name    = var.firewall_policy_rcg_name01
  firewall_logs_name          = var.firewall_logs_name01

  # DNS
  add_private_dns                   = var.add_private_dns01
  dns_vnet_name                     = var.dns_vnet_name01
  dns_vnet_address_space            = var.dns_vnet_address_space01
  hub_to_dns_connection_name        = var.azurerm_virtual_hub_connection_vhub01_to_dns01
  resolver_inbound_subnet_name      = var.resolver_inbound_subnet_name01
  resolver_inbound_subnet_address   = var.resolver_inbound_subnet_address01
  resolver_inbound_endpoint_address = var.resolver_inbound_endpoint_address01
  resolver_outbound_subnet_name     = var.resolver_outbound_subnet_name01
  resolver_outbound_subnet_address  = var.resolver_outbound_subnet_address01
  private_resolver_name             = var.private_resolver_name01
  dns_forwarder_ip                  = var.dns_forwarder_ip

  # Compute
  bastion_pip_name  = var.bastion_pip_name01
  bastion_host_name = var.bastion_host_name01
  bastion_host_sku  = var.bastion_host_sku01
  vm_nic_name       = var.vm01_nic_name
  vm_name           = var.vm01_name
  vm_size           = var.vm01_size
}

