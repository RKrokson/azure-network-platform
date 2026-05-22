########## Application Landing Zone — Spoke VNet & Connectivity
##########

# AI spoke VNet for this Foundry module
resource "azurerm_virtual_network" "ai_vnet" {
  name                = "${var.ai_vnet_name}-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  address_space       = var.ai_vnet_address_space
  location            = azurerm_resource_group.rg-ai01.location
  resource_group_name = azurerm_resource_group.rg-ai01.name
  tags                = local.common_tags
}

# Foundry workload subnet (Microsoft.App delegation — reserved for future use with managed VNet)
resource "azurerm_subnet" "ai_foundry_subnet" {
  name                 = "${var.ai_foundry_subnet_name}-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}"
  resource_group_name  = azurerm_resource_group.rg-ai01.name
  virtual_network_name = azurerm_virtual_network.ai_vnet.name
  address_prefixes     = var.ai_foundry_subnet_address

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
  name                            = "${var.private_endpoint_subnet_name}-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}"
  resource_group_name             = azurerm_resource_group.rg-ai01.name
  virtual_network_name            = azurerm_virtual_network.ai_vnet.name
  address_prefixes                = var.private_endpoint_subnet_address
  default_outbound_access_enabled = !data.terraform_remote_state.networking.outputs.add_firewall00
}

# NSG for private endpoint subnet (default-deny inbound)
resource "azurerm_network_security_group" "pe_subnet_nsg" {
  name                = "${var.private_endpoint_subnet_name}-nsg-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  location            = azurerm_resource_group.rg-ai01.location
  resource_group_name = azurerm_resource_group.rg-ai01.name
  tags                = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "pe_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.private_endpoint_subnet.id
  network_security_group_id = azurerm_network_security_group.pe_subnet_nsg.id
}

# NSG for Foundry subnet — empty per Ryan's directive (vWAN firewall handles egress)
resource "azurerm_network_security_group" "ai_foundry_subnet_nsg" {
  name                = "nsg-foundry-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  location            = azurerm_resource_group.rg-ai01.location
  resource_group_name = azurerm_resource_group.rg-ai01.name
  tags                = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "ai_foundry_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.ai_foundry_subnet.id
  network_security_group_id = azurerm_network_security_group.ai_foundry_subnet_nsg.id
}

# Connect AI spoke VNet to vHub
resource "azurerm_virtual_hub_connection" "vhub_connection_to_ai" {
  name                      = "vhub00-to-${var.ai_vnet_name}-${random_string.unique.result}"
  virtual_hub_id            = data.terraform_remote_state.networking.outputs.vhub00_id
  remote_virtual_network_id = azurerm_virtual_network.ai_vnet.id
  internet_security_enabled = data.terraform_remote_state.networking.outputs.add_firewall00
}

# Custom DNS servers on VNet — platform decides the IP (firewall or resolver)
resource "azurerm_virtual_network_dns_servers" "ai_vnet_dns" {
  virtual_network_id = azurerm_virtual_network.ai_vnet.id
  dns_servers        = [data.terraform_remote_state.networking.outputs.dns_server_ip00]
}

# Link VNet to DNS resolver policy
resource "azapi_resource" "dns_security_policy_ai_vnet_link" {
  type      = "Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks@2023-07-01-preview"
  name      = "vnet-link-to-dns-policy-${var.ai_vnet_name}-${random_string.unique.result}"
  parent_id = data.terraform_remote_state.networking.outputs.dns_resolver_policy00_id
  location  = azurerm_resource_group.rg-ai01.location

  body = {
    properties = {
      virtualNetwork = {
        id = azurerm_virtual_network.ai_vnet.id
      }
    }
  }
}

########## Managed Network Configuration
##########

# Managed Network Configuration
resource "azapi_resource" "managed_network" {
  type      = "Microsoft.CognitiveServices/accounts/managedNetworks@2025-10-01-preview"
  name      = "default"
  parent_id = azapi_resource.foundry.id

  schema_validation_enabled = false

  body = {
    properties = {
      managedNetwork = {
        isolationMode       = "AllowInternetOutbound"
        managedNetworkKind  = "V2"
        provisionNetworkNow = true
      }
    }
  }
  depends_on = [
    azurerm_role_assignment.foundry_network_connection_approver
  ]
}

# Managed Network Outbound Rule for Storage Account
resource "azapi_resource" "storage_outbound_rule" {
  type      = "Microsoft.CognitiveServices/accounts/managedNetworks/outboundRules@2025-10-01-preview"
  name      = "storage-blob-rule"
  parent_id = azapi_resource.managed_network.id

  schema_validation_enabled = false

  body = {
    properties = {
      type = "PrivateEndpoint"
      destination = {
        serviceResourceId = azurerm_storage_account.storage_account.id
        subresourceTarget = "blob"
      }
      category = "UserDefined"
    }
  }

  depends_on = [
    time_sleep.wait_storage,
    azurerm_role_assignment.foundry_network_connection_approver,
    azurerm_role_assignment.foundry_storage_blob,
    azurerm_role_assignment.foundry_storage_contributor
  ]
}

# Managed Network Outbound Rule for Cosmos DB Account
resource "azapi_resource" "cosmos_outbound_rule" {
  type      = "Microsoft.CognitiveServices/accounts/managedNetworks/outboundRules@2025-10-01-preview"
  name      = "cosmos-sql-rule"
  parent_id = azapi_resource.managed_network.id

  schema_validation_enabled = false

  body = {
    properties = {
      type = "PrivateEndpoint"
      destination = {
        serviceResourceId = azurerm_cosmosdb_account.cosmosdb.id
        subresourceTarget = "Sql"
      }
      category = "UserDefined"
    }
  }

  depends_on = [
    time_sleep.wait_cosmos,
    azurerm_role_assignment.foundry_network_connection_approver,
    azurerm_role_assignment.foundry_cosmos_contributor,
    azurerm_role_assignment.cosmosdb_reader_foundry_project,
    azurerm_role_assignment.cosmosdb_operator_foundry_project
  ]
}

# Managed Network Outbound Rule for AI Search Service
resource "azapi_resource" "aisearch_outbound_rule" {
  type      = "Microsoft.CognitiveServices/accounts/managedNetworks/outboundRules@2025-10-01-preview"
  name      = "aisearch-rule"
  parent_id = azapi_resource.managed_network.id

  schema_validation_enabled = false

  body = {
    properties = {
      type = "PrivateEndpoint"
      destination = {
        serviceResourceId = azapi_resource.ai_search.id
        subresourceTarget = "searchService"
      }
      category = "UserDefined"
    }
  }

  depends_on = [
    time_sleep.wait_aisearch,
    azurerm_role_assignment.foundry_network_connection_approver,
    azurerm_role_assignment.search_index_data_contributor_foundry_project,
    azurerm_role_assignment.search_service_contributor_foundry_project
  ]
}
