########## Application Landing Zone — Spoke VNet & Connectivity
##########

# AI spoke VNet for this Foundry module
resource "azurerm_virtual_network" "ai_vnet" {
  name                = "${var.ai_vnet_name}-${var.platform.region_abbr}-${var.name_suffix}"
  address_space       = var.network.vnet_address_space
  location            = azurerm_resource_group.rg-ai00.location
  resource_group_name = azurerm_resource_group.rg-ai00.name
  tags                = var.common_tags
}

# Foundry workload subnet (Microsoft.App delegation for container app VNet injection)
resource "azurerm_subnet" "ai_foundry_subnet" {
  name                 = "${var.ai_foundry_subnet_name}-${var.platform.region_abbr}"
  resource_group_name  = azurerm_resource_group.rg-ai00.name
  virtual_network_name = azurerm_virtual_network.ai_vnet.name
  address_prefixes     = var.network.foundry_subnet_address

  delegation {
    name = "Microsoft.App"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Private endpoint subnet
resource "azurerm_subnet" "private_endpoint_subnet" {
  name                            = "${var.private_endpoint_subnet_name}-${var.platform.region_abbr}"
  resource_group_name             = azurerm_resource_group.rg-ai00.name
  virtual_network_name            = azurerm_virtual_network.ai_vnet.name
  address_prefixes                = var.network.private_endpoint_subnet_address
  default_outbound_access_enabled = !var.platform.firewall_enabled
}

# NSG for private endpoint subnet (default-deny inbound)
resource "azurerm_network_security_group" "pe_subnet_nsg" {
  name                = "${var.private_endpoint_subnet_name}-nsg-${var.platform.region_abbr}-${var.name_suffix}"
  location            = azurerm_resource_group.rg-ai00.location
  resource_group_name = azurerm_resource_group.rg-ai00.name
  tags                = var.common_tags
}

resource "azurerm_subnet_network_security_group_association" "pe_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.private_endpoint_subnet.id
  network_security_group_id = azurerm_network_security_group.pe_subnet_nsg.id
}

# NSG for Foundry subnet — empty per Ryan's directive (vWAN firewall handles egress)
resource "azurerm_network_security_group" "ai_foundry_subnet_nsg" {
  name                = "nsg-foundry-${var.platform.region_abbr}-${var.name_suffix}"
  location            = azurerm_resource_group.rg-ai00.location
  resource_group_name = azurerm_resource_group.rg-ai00.name
  tags                = var.common_tags
}

resource "azurerm_subnet_network_security_group_association" "ai_foundry_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.ai_foundry_subnet.id
  network_security_group_id = azurerm_network_security_group.ai_foundry_subnet_nsg.id
}

# Connect AI spoke VNet to vHub
resource "azurerm_virtual_hub_connection" "vhub_connection_to_ai" {
  name                      = "${local.hub_label}-to-${var.ai_vnet_name}-${var.name_suffix}"
  virtual_hub_id            = var.platform.vhub_id
  remote_virtual_network_id = azurerm_virtual_network.ai_vnet.id
  internet_security_enabled = var.platform.firewall_enabled
}

# Custom DNS servers on VNet — platform decides the IP (firewall or resolver)
resource "azurerm_virtual_network_dns_servers" "ai_vnet_dns" {
  virtual_network_id = azurerm_virtual_network.ai_vnet.id
  dns_servers        = [var.platform.dns_server_ip]
}

# Link VNet to DNS resolver policy
resource "azapi_resource" "dns_security_policy_ai_vnet_link" {
  type      = "Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks@2023-07-01-preview"
  name      = "vnet-link-to-dns-policy-${var.ai_vnet_name}-${var.name_suffix}"
  parent_id = var.platform.dns_resolver_policy_id
  location  = azurerm_resource_group.rg-ai00.location

  body = {
    properties = {
      virtualNetwork = {
        id = azurerm_virtual_network.ai_vnet.id
      }
    }
  }
}
