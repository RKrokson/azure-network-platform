########## Application Landing Zone — Spoke VNet & Connectivity
##########

# Fabric spoke VNet (Block 5)
resource "azurerm_virtual_network" "fabric_vnet" {
  name                = "${var.fabric_vnet_name}-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  address_space       = var.fabric_vnet_address_space
  location            = azurerm_resource_group.rg_fabric00.location
  resource_group_name = azurerm_resource_group.rg_fabric00.name
  tags                = local.common_tags
}

# PE subnet — hosts the workspace-level private endpoint
resource "azurerm_subnet" "pe_subnet" {
  name                            = "${var.pe_subnet_name}-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}"
  resource_group_name             = azurerm_resource_group.rg_fabric00.name
  virtual_network_name            = azurerm_virtual_network.fabric_vnet.name
  address_prefixes                = var.pe_subnet_address
  default_outbound_access_enabled = !data.terraform_remote_state.networking.outputs.add_firewall00
}

# NSG for PE subnet — explicit allow rules (M4 security requirement)
# No Fabric delegation subnet exists — Fabric MPEs live in Fabric's managed network,
# not our VNet. This NSG applies ONLY to the PE subnet.
resource "azurerm_network_security_group" "pe_subnet_nsg" {
  name                = "${var.pe_subnet_name}-nsg-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  location            = azurerm_resource_group.rg_fabric00.location
  resource_group_name = azurerm_resource_group.rg_fabric00.name
  tags                = local.common_tags

  # Inbound: allow HTTPS (443) from VNet — covers Fabric workspace PE, Storage blob, KV
  security_rule {
    name                       = "AllowVNet443Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Inbound: allow SQL (1433) from VNet — covers Azure SQL PE
  security_rule {
    name                       = "AllowVNet1433Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Inbound: deny all other traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Outbound: allow VNet to VNet
  security_rule {
    name                       = "AllowVNetOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Outbound: deny all other traffic
  security_rule {
    name                       = "DenyAllOutbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "pe_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.pe_subnet.id
  network_security_group_id = azurerm_network_security_group.pe_subnet_nsg.id
}

# Connect Fabric spoke VNet to vHub
resource "azurerm_virtual_hub_connection" "vhub_connection_to_fabric" {
  name                      = "vhub00-to-${var.fabric_vnet_name}-${random_string.unique.result}"
  virtual_hub_id            = data.terraform_remote_state.networking.outputs.vhub00_id
  remote_virtual_network_id = azurerm_virtual_network.fabric_vnet.id
  internet_security_enabled = data.terraform_remote_state.networking.outputs.add_firewall00
}

# Custom DNS servers on VNet — platform decides the IP (firewall or resolver)
resource "azurerm_virtual_network_dns_servers" "fabric_vnet_dns" {
  virtual_network_id = azurerm_virtual_network.fabric_vnet.id
  dns_servers        = [data.terraform_remote_state.networking.outputs.dns_server_ip00]
}

# Link VNet to DNS resolver policy
resource "azapi_resource" "dns_resolver_policy_fabric_vnet_link" {
  type      = "Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks@2023-07-01-preview"
  name      = "vnet-link-to-dns-policy-${var.fabric_vnet_name}-${random_string.unique.result}"
  parent_id = data.terraform_remote_state.networking.outputs.dns_resolver_policy00_id
  location  = azurerm_resource_group.rg_fabric00.location

  body = {
    properties = {
      virtualNetwork = {
        id = azurerm_virtual_network.fabric_vnet.id
      }
    }
  }
}
