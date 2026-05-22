/* Define variables for region 0 and region 1 using the region map. Here are common region pairs.
"centralus" = "cus"
"eastus2" = "eus2"
"westus" = "wus"
"eastus" = "eus"
"northcentralus" = "ncus"
"southcentralus" = "scus"
"westcentralus" = "wcus"
"westus2" = "wus2"
"westus3" = "wus3"
"westeurope" = "weu"
"northeurope" = "neu"
"swedencentral" = "sece"
*/
variable "azure_region_0_abbr" {
  description = "Azure Region 0 Abbreviation"
  type        = string
  default     = "sece"
}
variable "azure_region_0_name" {
  description = "Azure Region 0 Name"
  type        = string
  default     = "swedencentral"
}
variable "azure_region_1_abbr" {
  description = "Azure Region 1 Abbreviation"
  type        = string
  default     = "cus"
}
variable "azure_region_1_name" {
  description = "Azure Region 1 Name"
  type        = string
  default     = "centralus"
}
# KV variables
variable "kv_name" {
  description = "Key Vault Name"
  type        = string
  default     = "kv00"
}
variable "resource_group_name_kv" {
  description = "Resource Group Name for Key Vault"
  type        = string
  default     = "rg-kv00"
}
variable "kv_secret_name" {
  description = "Secret Name"
  type        = string
  default     = "kvsecret-vmpassword"
}
# Region 0 permanent resources
variable "resource_group_name_net00" {
  description = "Resource Group Name for Region 0 Networking"
  type        = string
  default     = "rg-net00"
}
variable "azurerm_virtual_wan_name" {
  description = "Virtual WAN Name"
  type        = string
  default     = "vwan"
}
variable "azurerm_virtual_hub00_name" {
  description = "Virtual Hub 00 Name"
  type        = string
  default     = "vhub00"
}
variable "azurerm_vhub00_address_prefix" {
  description = "Address prefix for Virtual Hub 00"
  type        = string
  default     = "172.30.0.0/23"

  validation {
    condition     = can(cidrhost(var.azurerm_vhub00_address_prefix, 0))
    error_message = "Must be a valid CIDR block."
  }
}
variable "azurerm_vhub00_route_pref" {
  description = "Route preference for Virtual Hub 00"
  type        = string
  default     = "ExpressRoute"
}
variable "log_analytics_workspace_name" {
  description = "Log Analytics Workspace Name"
  type        = string
  default     = "law00"
}
variable "log_analytics_sku" {
  description = "SKU for the Log Analytics workspace"
  type        = string
  default     = "PerGB2018"
}
variable "log_analytics_retention_days" {
  description = "Retention period in days for the Log Analytics workspace"
  type        = number
  default     = 30
}
variable "shared_vnet_name00" {
  description = "Shared VNet name for Region 0"
  type        = string
  default     = "shared-vnet00"
}
variable "shared_vnet_address_space00" {
  description = "Shared VNet address space for Region 0"
  type        = list(string)
  default     = ["172.20.0.0/20"]
}
variable "azurerm_virtual_hub_connection_vhub00_to_shared00" {
  description = "Virtual Hub Connection from vhub00 to shared vnet00"
  type        = string
  default     = "vhub00-to-shared00"
}
variable "shared_subnet_name00" {
  description = "Virtual Network Shared Subnet Name"
  type        = string
  default     = "shared-subnet00"
}
variable "shared_subnet_address00" {
  description = "Virtual Network Shared Subnet Address Spaces"
  type        = list(string)
  default     = ["172.20.5.0/24"]
}
variable "app_subnet_name00" {
  description = "Virtual Network App Subnet Name"
  type        = string
  default     = "app-subnet00"
}
variable "app_subnet_address00" {
  description = "Virtual Network App Subnet Address Spaces"
  type        = list(string)
  default     = ["172.20.6.0/24"]
}
variable "dns_vnet_name00" {
  description = "DNS resolver VNet name for Region 0"
  type        = string
  default     = "dns-vnet00"
}
variable "dns_vnet_address_space00" {
  description = "DNS resolver VNet address space for Region 0"
  type        = list(string)
  default     = ["172.20.16.0/20"]
}
variable "azurerm_virtual_hub_connection_vhub00_to_dns00" {
  description = "Virtual Hub Connection from vhub00 to dns vnet00"
  type        = string
  default     = "vhub00-to-dns00"
}
variable "resolver_inbound_subnet_name00" {
  description = "Virtual Network Private Resolver Inbound Subnet Name"
  type        = string
  default     = "resolver-inbound-subnet00"
}
variable "resolver_inbound_subnet_address00" {
  description = "Virtual Network Private Resolver Inbound Subnet Address Spaces"
  type        = list(string)
  default     = ["172.20.16.0/28"]
}
variable "resolver_inbound_endpoint_address00" {
  description = "Virtual Network Private Resolver Inbound Endpoint Address"
  type        = string
  default     = "172.20.16.4"
}
variable "resolver_outbound_subnet_name00" {
  description = "Virtual Network Private Resolver Outbound Subnet Name"
  type        = string
  default     = "resolver-outbound-subnet00"
}
variable "resolver_outbound_subnet_address00" {
  description = "Virtual Network Private Resolver Outbound Subnet Address Spaces"
  type        = list(string)
  default     = ["172.20.16.16/28"]
}
variable "bastion_pip_name00" {
  description = "Bastion Public IP Name"
  type        = string
  default     = "bastion-pip00"
}
variable "bastion_host_name00" {
  description = "Bastion Host Name"
  type        = string
  default     = "bastion-host00"
}
variable "bastion_host_sku00" {
  description = "Bastion Host 00 SKU"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Developer"], var.bastion_host_sku00)
    error_message = "Bastion SKU must be one of: Basic, Standard, Developer."
  }
}
variable "bastion_subnet_address00" {
  description = "Virtual Network Bastion Subnet Address Spaces"
  type        = list(string)
  default     = ["172.20.0.0/24"]
}
variable "vm00_nic_name" {
  description = "Virtual Machine 00 NIC Name"
  type        = string
  default     = "vm00-nic"
}
variable "vm00_name" {
  description = "Virtual Machine 00 Name"
  type        = string
  default     = "vm00"
}
variable "vm00_size" {
  description = "Virtual Machine Size"
  type        = string
  default     = "Standard_B2s"
}
variable "vm_admin_username" {
  description = "Virtual Machine Admin Username"
  type        = string
  default     = "adminuser"
}
## Firewall variables for region 0
variable "add_firewall00" {
  description = "Add Firewall 00"
  type        = bool
  default     = false
}
variable "firewall_availability_zones" {
  description = "Availability zones for Azure Firewall deployment"
  type        = list(string)
  default     = ["1", "2", "3"]
}
variable "dns_forwarder_ip" {
  description = "IP address of the external DNS forwarder used in DNS resolver forwarding rules"
  type        = string
  default     = "8.8.8.8"
}
variable "firewall_name00" {
  description = "Firewall 00 Name"
  type        = string
  default     = "firewall00"
}
variable "firewall_sku_name00" {
  description = "Firewall 00 SKU Name"
  type        = string
  default     = "AZFW_Hub"
}
variable "firewall_sku_tier00" {
  description = "Firewall 00 SKU Tier"
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku_tier00)
    error_message = "Firewall SKU tier must be one of: Standard, Premium."
  }
}
variable "firewall_policy_name00" {
  description = "Firewall 00 Policy Name"
  type        = string
  default     = "firewall00-policy"
}
variable "firewall_policy_rcg_name00" {
  description = "Firewall 00 Policy Rule Collection Group Name"
  type        = string
  default     = "policy00-firewall00-rcg"
}
variable "firewall_logs_name00" {
  description = "Firewall 00 Diagnostic Logs Name"
  type        = string
  default     = "firewall00-logs"
}
variable "add_private_dns00" {
  description = "Add Private DNS 00"
  type        = bool
  default     = false
}
variable "private_resolver_name00" {
  description = "Private DNS Resolver Name for Region 0"
  type        = string
  default     = "resolver00"
}
# Region 1 conditional resources
variable "create_vhub01" {
  description = "Create Virtual Hub 01"
  type        = bool
  default     = false
}
variable "resource_group_name_net01" {
  description = "Resource Group Name for Region 1 Networking"
  type        = string
  default     = "rg-net01"
}
variable "resource_group_location01" {
  description = "Region in which Azure Resources to be created"
  type        = string
  default     = "eastus2"
}
variable "azurerm_virtual_hub01_name" {
  description = "Virtual Hub 01 Name"
  type        = string
  default     = "vhub01"
}
variable "azurerm_vhub01_address_prefix" {
  description = "Address prefix for Virtual Hub 01"
  type        = string
  default     = "172.30.2.0/23"

  validation {
    condition     = can(cidrhost(var.azurerm_vhub01_address_prefix, 0))
    error_message = "Must be a valid CIDR block."
  }
}
variable "azurerm_vhub01_route_pref" {
  description = "Route preference for Virtual Hub 01"
  type        = string
  default     = "ExpressRoute"
}
variable "shared_vnet_name01" {
  description = "Shared VNet name for Region 1"
  type        = string
  default     = "shared-vnet01"
}
variable "dns_vnet_name01" {
  description = "DNS resolver VNet name for Region 1"
  type        = string
  default     = "dns-vnet01"
}
variable "shared_vnet_address_space01" {
  description = "Shared VNet address space for Region 1"
  type        = list(string)
  default     = ["172.21.0.0/20"]
}
variable "dns_vnet_address_space01" {
  description = "DNS resolver VNet address space for Region 1"
  type        = list(string)
  default     = ["172.21.16.0/20"]
}
variable "shared_subnet_name01" {
  description = "Virtual Network Shared Subnet Name"
  type        = string
  default     = "shared-subnet01"
}
variable "shared_subnet_address01" {
  description = "Virtual Network Shared Subnet Address Spaces"
  type        = list(string)
  default     = ["172.21.5.0/24"]
}
variable "app_subnet_name01" {
  description = "Virtual Network App Subnet Name"
  type        = string
  default     = "app-subnet01"
}
variable "app_subnet_address01" {
  description = "Virtual Network App Subnet Address Spaces"
  type        = list(string)
  default     = ["172.21.6.0/24"]
}
variable "azurerm_virtual_hub_connection_vhub01_to_shared01" {
  description = "Virtual Hub Connection from vhub01 to shared vnet01"
  type        = string
  default     = "vhub01-to-shared01"
}
variable "azurerm_virtual_hub_connection_vhub01_to_dns01" {
  description = "Virtual Hub Connection from vhub01 to dns vnet01"
  type        = string
  default     = "vhub01-to-dns01"
}
## DNS conditional variables for region 1
variable "resolver_inbound_subnet_name01" {
  description = "Virtual Network Private Resolver Inbound Subnet Name"
  type        = string
  default     = "resolver-inbound-subnet01"
}
variable "resolver_inbound_subnet_address01" {
  description = "Virtual Network Private Resolver Inbound Subnet Address Spaces"
  type        = list(string)
  default     = ["172.21.16.0/28"]
}
variable "resolver_inbound_endpoint_address01" {
  description = "Virtual Network Private Resolver Inbound Endpoint Address"
  type        = string
  default     = "172.21.16.4"
}
variable "resolver_outbound_subnet_name01" {
  description = "Virtual Network Private Resolver Outbound Subnet Name"
  type        = string
  default     = "resolver-outbound-subnet01"
}
variable "resolver_outbound_subnet_address01" {
  description = "Virtual Network Private Resolver Outbound Subnet Address Spaces"
  type        = list(string)
  default     = ["172.21.16.16/28"]
}
## Bastion conditional variables for region 1
variable "bastion_pip_name01" {
  description = "Bastion Public IP Name"
  type        = string
  default     = "bastion-pip01"
}
variable "bastion_host_name01" {
  description = "Bastion Host Name"
  type        = string
  default     = "bastion-host01"
}
variable "bastion_host_sku01" {
  description = "Bastion Host 01 SKU"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Developer"], var.bastion_host_sku01)
    error_message = "Bastion SKU must be one of: Basic, Standard, Developer."
  }
}
variable "bastion_subnet_address01" {
  description = "Virtual Network Bastion Subnet Address Spaces"
  type        = list(string)
  default     = ["172.21.0.0/24"]
}
variable "add_firewall01" {
  description = "Add Firewall 01"
  type        = bool
  default     = false
}
variable "firewall_name01" {
  description = "Firewall 01 Name"
  type        = string
  default     = "firewall01"
}
variable "firewall_sku_name01" {
  description = "Firewall 01 SKU Name"
  type        = string
  default     = "AZFW_Hub"
}
variable "firewall_sku_tier01" {
  description = "Firewall 01 SKU Tier"
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku_tier01)
    error_message = "Firewall SKU tier must be one of: Standard, Premium."
  }
}
variable "firewall_policy_name01" {
  description = "Firewall 01 Policy Name"
  type        = string
  default     = "firewall01-policy"
}
variable "firewall_logs_name01" {
  description = "Firewall 01 Diagnostic Logs Name"
  type        = string
  default     = "firewall01-logs"
}
variable "firewall_policy_rcg_name01" {
  description = "Firewall 01 Policy Rule Collection Group Name"
  type        = string
  default     = "firewall01-policy-rcg"
}
variable "add_private_dns01" {
  description = "Add Private DNS 01"
  type        = bool
  default     = false
}
variable "private_resolver_name01" {
  description = "Private DNS Resolver Name for Region 1"
  type        = string
  default     = "resolver01"
}
variable "vm01_nic_name" {
  description = "Virtual Machine 01 NIC Name"
  type        = string
  default     = "vm01-nic"
}
variable "vm01_name" {
  description = "Virtual Machine 01 Name"
  type        = string
  default     = "vm01"
}
variable "vm01_size" {
  description = "Virtual Machine Size"
  type        = string
  default     = "Standard_B2s"
}