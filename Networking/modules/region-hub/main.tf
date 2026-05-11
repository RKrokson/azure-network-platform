terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azapi = {
      source = "azure/azapi"
    }
  }
}

# ── Hub ─────────────────────────────────────────────────────────

resource "azurerm_virtual_hub" "hub" {
  name                   = "${var.hub_name}-${var.region_abbr}"
  resource_group_name    = var.resource_group_name
  location               = var.resource_group_location
  virtual_wan_id         = var.virtual_wan_id
  address_prefix         = var.hub_address_prefix
  hub_routing_preference = var.hub_route_pref
  tags                   = var.common_tags

  timeouts {
    create = "60m"
    delete = "60m"
  }
}

resource "azurerm_virtual_hub_routing_intent" "routing_intent" {
  count          = var.add_firewall ? 1 : 0
  name           = "routing-policy-${var.hub_name}-${var.region_abbr}"
  virtual_hub_id = azurerm_virtual_hub.hub.id
  routing_policy {
    name         = "InternetTrafficPolicy"
    destinations = ["Internet"]
    next_hop     = azurerm_firewall.fw[0].id
  }
  routing_policy {
    name         = "PrivateTrafficPolicy"
    destinations = ["PrivateTraffic"]
    next_hop     = azurerm_firewall.fw[0].id
  }
}

# Note: azurerm_monitor_diagnostic_setting is not supported for microsoft.network/virtualhubs.
# vHub metrics/logs are only available via the Azure Virtual WAN portal experience.

# ── Shared VNet & Subnets ──────────────────────────────────────

resource "azurerm_virtual_network" "shared_vnet" {
  name                = "${var.shared_vnet_name}-${var.region_abbr}"
  address_space       = var.shared_vnet_address_space
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  tags                = var.common_tags
}

resource "azurerm_subnet" "shared_subnet" {
  name                            = "${var.shared_subnet_name}-${var.shared_vnet_name}-${var.region_abbr}"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.shared_vnet.name
  address_prefixes                = var.shared_subnet_address
  default_outbound_access_enabled = !var.add_firewall
}

resource "azurerm_subnet" "app_subnet" {
  name                            = "${var.app_subnet_name}-${var.shared_vnet_name}-${var.region_abbr}"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.shared_vnet.name
  address_prefixes                = var.app_subnet_address
  default_outbound_access_enabled = !var.add_firewall
}

resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.shared_vnet.name
  address_prefixes     = var.bastion_subnet_address
}

resource "azurerm_virtual_hub_connection" "hub_connection_shared" {
  name                      = "${var.hub_to_shared_connection_name}-${var.region_abbr}"
  virtual_hub_id            = azurerm_virtual_hub.hub.id
  remote_virtual_network_id = azurerm_virtual_network.shared_vnet.id
  internet_security_enabled = var.add_firewall
}

# ── Firewall (conditional) ─────────────────────────────────────

resource "azurerm_firewall_policy" "fw_policy" {
  count               = var.add_firewall ? 1 : 0
  name                = "${var.firewall_policy_name}-${var.region_abbr}"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  sku                 = var.firewall_sku_tier
  tags                = var.common_tags

  dns {
    proxy_enabled = true
    servers       = var.add_private_dns ? [var.resolver_inbound_endpoint_address] : []
  }
}

resource "azurerm_firewall" "fw" {
  count               = var.add_firewall ? 1 : 0
  name                = "${var.firewall_name}-${var.region_abbr}"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  sku_name            = var.firewall_sku_name
  sku_tier            = var.firewall_sku_tier
  zones               = var.firewall_availability_zones
  tags                = var.common_tags
  virtual_hub {
    virtual_hub_id = azurerm_virtual_hub.hub.id
  }

  firewall_policy_id = azurerm_firewall_policy.fw_policy[0].id

  timeouts {
    create = "60m"
    delete = "60m"
  }
}

# WARNING: Allow-all rule for non-production lab use only.
# In production, restrict source/destination to known address spaces.
resource "azurerm_firewall_policy_rule_collection_group" "fw_policy_rcg" {
  count              = var.add_firewall ? 1 : 0
  name               = "${var.firewall_policy_rcg_name}-${var.region_abbr}"
  firewall_policy_id = azurerm_firewall_policy.fw_policy[0].id
  priority           = 500
  network_rule_collection {
    name     = "network_rule_collection"
    priority = 400
    action   = "Allow"
    rule {
      name                  = "network_rule_collection_rule1"
      protocols             = ["TCP", "UDP", "ICMP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "fw_logs" {
  count              = var.add_firewall ? 1 : 0
  name               = "${var.firewall_logs_name}-${var.region_abbr}"
  target_resource_id = azurerm_firewall.fw[0].id

  log_analytics_workspace_id = var.log_analytics_workspace_id
  enabled_log {
    category = "AzureFirewallApplicationRule"
  }
  enabled_log {
    category = "AzureFirewallNetworkRule"
  }
  enabled_log {
    category = "AzureFirewallDnsProxy"
  }
  enabled_metric {
    category = "AllMetrics"
  }
}

# ── DNS (conditional) ──────────────────────────────────────────

resource "azurerm_virtual_network" "dns_vnet" {
  count               = var.add_private_dns ? 1 : 0
  name                = "${var.dns_vnet_name}-${var.region_abbr}"
  address_space       = var.dns_vnet_address_space
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  tags                = var.common_tags
}

resource "azurerm_subnet" "resolver_inbound_subnet" {
  count                = var.add_private_dns ? 1 : 0
  name                 = "${var.resolver_inbound_subnet_name}-${var.dns_vnet_name}-${var.region_abbr}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.dns_vnet[0].name
  address_prefixes     = var.resolver_inbound_subnet_address

  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.Network/dnsResolvers"
    }
  }
}

resource "azurerm_subnet" "resolver_outbound_subnet" {
  count                = var.add_private_dns ? 1 : 0
  name                 = "${var.resolver_outbound_subnet_name}-${var.dns_vnet_name}-${var.region_abbr}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.dns_vnet[0].name
  address_prefixes     = var.resolver_outbound_subnet_address

  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.Network/dnsResolvers"
    }
  }
}

module "private_dns" {
  count     = var.add_private_dns ? 1 : 0
  source    = "Azure/avm-ptn-network-private-link-private-dns-zones/azurerm"
  version   = "0.23.0"
  location  = var.resource_group_location
  parent_id = var.resource_group_id
  virtual_network_link_default_virtual_networks = {
    "dns_vnet" = {
      virtual_network_resource_id = azurerm_virtual_network.dns_vnet[0].id
      resolution_policy           = "NxDomainRedirect"
    }
  }
}

resource "azurerm_virtual_hub_connection" "hub_connection_dns" {
  count                     = var.add_private_dns ? 1 : 0
  name                      = "${var.hub_to_dns_connection_name}-${var.region_abbr}"
  virtual_hub_id            = azurerm_virtual_hub.hub.id
  remote_virtual_network_id = azurerm_virtual_network.dns_vnet[0].id
  internet_security_enabled = var.add_firewall
}

resource "azurerm_private_dns_resolver" "resolver" {
  count               = var.add_private_dns ? 1 : 0
  name                = "${var.private_resolver_name}-${var.region_abbr}"
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location
  virtual_network_id  = azurerm_virtual_network.dns_vnet[0].id
  tags                = var.common_tags
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "resolver_inbound" {
  count                   = var.add_private_dns ? 1 : 0
  name                    = "${var.private_resolver_name}-inbound00-${var.region_abbr}"
  private_dns_resolver_id = azurerm_private_dns_resolver.resolver[0].id
  location                = var.resource_group_location
  tags                    = var.common_tags
  ip_configurations {
    private_ip_allocation_method = "Static"
    subnet_id                    = azurerm_subnet.resolver_inbound_subnet[0].id
    private_ip_address           = var.resolver_inbound_endpoint_address
  }
}

resource "azurerm_virtual_network_dns_servers" "shared_vnet_dns" {
  count              = var.add_private_dns ? 1 : 0
  virtual_network_id = azurerm_virtual_network.shared_vnet.id
  dns_servers        = var.add_firewall ? [azurerm_firewall.fw[0].virtual_hub[0].private_ip_address] : [var.resolver_inbound_endpoint_address]

  depends_on = [
    azurerm_subnet.resolver_inbound_subnet[0],
    azurerm_subnet.resolver_outbound_subnet[0]
  ]
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "resolver_outbound" {
  count                   = var.add_private_dns ? 1 : 0
  name                    = "${var.private_resolver_name}-outbound00-${var.region_abbr}"
  private_dns_resolver_id = azurerm_private_dns_resolver.resolver[0].id
  location                = var.resource_group_location
  subnet_id               = azurerm_subnet.resolver_outbound_subnet[0].id
  tags                    = var.common_tags
}

resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "forwarding_ruleset" {
  count                                      = var.add_private_dns ? 1 : 0
  name                                       = "${var.private_resolver_name}-ruleset00-${var.region_abbr}"
  resource_group_name                        = var.resource_group_name
  location                                   = var.resource_group_location
  private_dns_resolver_outbound_endpoint_ids = [azurerm_private_dns_resolver_outbound_endpoint.resolver_outbound[0].id]
  tags                                       = var.common_tags
}

resource "azurerm_private_dns_resolver_forwarding_rule" "forwarding_rule" {
  count                     = var.add_private_dns ? 1 : 0
  name                      = "${var.private_resolver_name}-rule00-${var.region_abbr}"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.forwarding_ruleset[0].id
  domain_name               = "."
  enabled                   = true
  target_dns_servers {
    ip_address = var.dns_forwarder_ip
    port       = 53
  }
}

resource "azurerm_private_dns_resolver_virtual_network_link" "forwarding_ruleset_dns_vnet_link" {
  count                     = var.add_private_dns ? 1 : 0
  name                      = "${var.private_resolver_name}-dnsvnetlink00-${var.region_abbr}"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.forwarding_ruleset[0].id
  virtual_network_id        = azurerm_virtual_network.dns_vnet[0].id
}

resource "azapi_resource" "dns_security_policy" {
  count     = var.add_private_dns ? 1 : 0
  type      = "Microsoft.Network/dnsResolverPolicies@2023-07-01-preview"
  name      = "myDnsSecurityPolicy-${var.region_abbr}"
  parent_id = var.resource_group_id
  location  = var.resource_group_location
  tags      = var.common_tags

  body = {
    properties = {
    }
  }
}

resource "azapi_resource" "dns_policy_shared_vnet_link" {
  count     = var.add_private_dns ? 1 : 0
  type      = "Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks@2023-07-01-preview"
  name      = "vnet-link-to-dns-policy-shared-vnet"
  parent_id = azapi_resource.dns_security_policy[0].id
  location  = var.resource_group_location

  body = {
    properties = {
      virtualNetwork = {
        id = azurerm_virtual_network.shared_vnet.id
      }
    }
  }
}

resource "azapi_resource" "dns_policy_dns_vnet_link" {
  count     = var.add_private_dns ? 1 : 0
  type      = "Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks@2023-07-01-preview"
  name      = "vnet-link-to-dns-policy-dns-vnet"
  parent_id = azapi_resource.dns_security_policy[0].id
  location  = var.resource_group_location

  body = {
    properties = {
      virtualNetwork = {
        id = azurerm_virtual_network.dns_vnet[0].id
      }
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "dns_policy_logs" {
  count              = var.add_private_dns ? 1 : 0
  name               = "dns-policy-logs-${var.region_abbr}"
  target_resource_id = azapi_resource.dns_security_policy[0].id

  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "DnsResponse"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# ── Compute ────────────────────────────────────────────────────

resource "azurerm_public_ip" "bastion_pip" {
  name                = "${var.bastion_pip_name}-${var.region_abbr}"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.common_tags
}

resource "azurerm_bastion_host" "bastion" {
  name                = "${var.bastion_host_name}-${var.region_abbr}"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  sku                 = var.bastion_host_sku
  tags                = var.common_tags

  # Requires Standard SKU. Enables native client support (az network bastion tunnel/rdp/ssh).
  tunneling_enabled = true

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }
}

resource "azurerm_monitor_diagnostic_setting" "bastion_logs" {
  name               = "bastion-logs-${var.region_abbr}"
  target_resource_id = azurerm_bastion_host.bastion.id

  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "audit"
  }
  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_network_interface" "vm_nic" {
  name                = "${var.vm_nic_name}-${var.region_abbr}"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  tags                = var.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.shared_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = "${var.vm_name}-${var.region_abbr}"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = "${var.suffix}${var.vm_admin_username}"
  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]
  admin_password                                         = var.vm_admin_password
  patch_mode                                             = "AutomaticByPlatform"
  bypass_platform_safety_checks_on_user_schedule_enabled = true
  tags                                                   = var.common_tags
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "vm_post_deploy" {
  name                 = "post-deploy-config"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  tags                 = var.common_tags

  protected_settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -Command \"Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Active Setup\\Installed Components\\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}' -Name 'IsInstalled' -Value 0; Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Active Setup\\Installed Components\\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}' -Name 'IsInstalled' -Value 0; ipconfig /renew\""
  })

  depends_on = [azurerm_virtual_network_dns_servers.shared_vnet_dns]
}
