########## Application Landing Zone — Spoke VNet & Connectivity
##########

# ACA spoke VNet
resource "azurerm_virtual_network" "aca_vnet" {
  name                = "${var.aca_vnet_name}-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  address_space       = var.aca_vnet_address_space
  location            = azurerm_resource_group.rg_aca00.location
  resource_group_name = azurerm_resource_group.rg_aca00.name
  tags                = local.common_tags
}

# ACA infrastructure subnet — delegated to Microsoft.App/environments
resource "azurerm_subnet" "aca_subnet" {
  name                 = "${var.aca_subnet_name}-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}"
  resource_group_name  = azurerm_resource_group.rg_aca00.name
  virtual_network_name = azurerm_virtual_network.aca_vnet.name
  address_prefixes     = var.aca_subnet_address

  delegation {
    name = "Microsoft.App"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Private endpoint subnet
resource "azurerm_subnet" "pe_subnet" {
  name                            = "${var.pe_subnet_name}-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}"
  resource_group_name             = azurerm_resource_group.rg_aca00.name
  virtual_network_name            = azurerm_virtual_network.aca_vnet.name
  address_prefixes                = var.pe_subnet_address
  default_outbound_access_enabled = !data.terraform_remote_state.networking.outputs.add_firewall00
}

# NSG for private endpoint subnet (no custom rules; Azure default rules apply)
resource "azurerm_network_security_group" "pe_subnet_nsg" {
  name                = "${var.pe_subnet_name}-nsg-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  location            = azurerm_resource_group.rg_aca00.location
  resource_group_name = azurerm_resource_group.rg_aca00.name
  tags                = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "pe_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.pe_subnet.id
  network_security_group_id = azurerm_network_security_group.pe_subnet_nsg.id
}

# NSG for ACA subnet — empty per Ryan's directive (vWAN firewall handles egress)
resource "azurerm_network_security_group" "aca_subnet_nsg" {
  name                = "nsg-aca-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  location            = azurerm_resource_group.rg_aca00.location
  resource_group_name = azurerm_resource_group.rg_aca00.name
  tags                = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "aca_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.aca_subnet.id
  network_security_group_id = azurerm_network_security_group.aca_subnet_nsg.id
}

resource "azurerm_monitor_diagnostic_setting" "diag_nsg_aca" {
  name               = "diag-nsg-aca-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  target_resource_id = azurerm_network_security_group.aca_subnet_nsg.id

  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }
}

# Connect ACA spoke VNet to vHub
resource "azurerm_virtual_hub_connection" "vhub_connection_to_aca" {
  name                      = "vhub00-to-${var.aca_vnet_name}-${random_string.unique.result}"
  virtual_hub_id            = data.terraform_remote_state.networking.outputs.vhub00_id
  remote_virtual_network_id = azurerm_virtual_network.aca_vnet.id
  internet_security_enabled = data.terraform_remote_state.networking.outputs.add_firewall00
}

# Custom DNS servers on VNet — platform decides the IP (firewall or resolver)
resource "azurerm_virtual_network_dns_servers" "aca_vnet_dns" {
  virtual_network_id = azurerm_virtual_network.aca_vnet.id
  dns_servers        = [data.terraform_remote_state.networking.outputs.dns_server_ip00]
}

# Link VNet to DNS resolver policy
resource "azapi_resource" "dns_security_policy_aca_vnet_link" {
  type      = "Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks@2023-07-01-preview"
  name      = "vnet-link-to-dns-policy-${var.aca_vnet_name}-${random_string.unique.result}"
  parent_id = data.terraform_remote_state.networking.outputs.dns_resolver_policy00_id
  location  = azurerm_resource_group.rg_aca00.location

  body = {
    properties = {
      virtualNetwork = {
        id = azurerm_virtual_network.aca_vnet.id
      }
    }
  }
}
