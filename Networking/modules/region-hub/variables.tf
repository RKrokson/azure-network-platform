# ── Context (passed from root) ─────────────────────────────────

variable "resource_group_name" {
  description = "Name of the pre-existing resource group for this region"
  type        = string
}

variable "resource_group_location" {
  description = "Location of the resource group"
  type        = string
}

variable "resource_group_id" {
  description = "Full resource ID of the resource group (used as parent_id for AVM/azapi)"
  type        = string
}

variable "region_abbr" {
  description = "Short region abbreviation for naming (e.g. sece, cus)"
  type        = string
}

variable "suffix" {
  description = "Random numeric suffix for globally unique names"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to all taggable resources"
  type        = map(string)
}

variable "virtual_wan_id" {
  description = "ID of the parent Virtual WAN"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace for diagnostic settings"
  type        = string
}

variable "vm_admin_username" {
  description = "VM admin username (suffix is prepended inside the module)"
  type        = string
}

variable "vm_admin_password" {
  description = "VM admin password (from Key Vault)"
  type        = string
  sensitive   = true
}

# ── Hub ─────────────────────────────────────────────────────────

variable "hub_name" {
  description = "Virtual Hub name (region_abbr appended automatically)"
  type        = string
}

variable "hub_address_prefix" {
  description = "CIDR address prefix for the Virtual Hub"
  type        = string

  validation {
    condition     = can(cidrhost(var.hub_address_prefix, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "hub_route_pref" {
  description = "Hub routing preference (ExpressRoute, ASPath, VpnGateway)"
  type        = string
  default     = "ExpressRoute"
}

# ── Shared VNet ─────────────────────────────────────────────────

variable "shared_vnet_name" {
  description = "Shared spoke VNet name"
  type        = string
}

variable "shared_vnet_address_space" {
  description = "Shared spoke VNet address space"
  type        = list(string)
}

variable "shared_subnet_name" {
  description = "Shared subnet name"
  type        = string
}

variable "shared_subnet_address" {
  description = "Shared subnet address prefixes"
  type        = list(string)
}

variable "app_subnet_name" {
  description = "App subnet name"
  type        = string
}

variable "app_subnet_address" {
  description = "App subnet address prefixes"
  type        = list(string)
}

variable "bastion_subnet_address" {
  description = "Bastion subnet address prefixes"
  type        = list(string)
}

variable "hub_to_shared_connection_name" {
  description = "Name for the hub-to-shared-VNet connection"
  type        = string
}

# ── Firewall (conditional) ──────────────────────────────────────

variable "add_firewall" {
  description = "Deploy Azure Firewall in this region's hub"
  type        = bool
  default     = false
}

variable "firewall_name" {
  description = "Firewall name"
  type        = string
  default     = "firewall"
}

variable "firewall_sku_name" {
  description = "Firewall SKU name"
  type        = string
  default     = "AZFW_Hub"
}

variable "firewall_sku_tier" {
  description = "Firewall SKU tier"
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku_tier)
    error_message = "Firewall SKU tier must be one of: Standard, Premium."
  }
}

variable "firewall_availability_zones" {
  description = "Availability zones for Azure Firewall deployment"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "firewall_policy_name" {
  description = "Firewall policy name"
  type        = string
  default     = "firewall-policy"
}

variable "firewall_policy_rcg_name" {
  description = "Firewall policy rule collection group name"
  type        = string
  default     = "firewall-policy-rcg"
}

variable "firewall_logs_name" {
  description = "Firewall diagnostic setting name"
  type        = string
  default     = "firewall-logs"
}

# ── DNS (conditional) ───────────────────────────────────────────

variable "add_private_dns" {
  description = "Deploy Private DNS Resolver in this region"
  type        = bool
  default     = false
}

variable "dns_vnet_name" {
  description = "DNS resolver VNet name"
  type        = string
  default     = "dns-vnet"
}

variable "dns_vnet_address_space" {
  description = "DNS resolver VNet address space"
  type        = list(string)
}

variable "hub_to_dns_connection_name" {
  description = "Name for the hub-to-DNS-VNet connection"
  type        = string
}

variable "resolver_inbound_subnet_name" {
  description = "Inbound resolver subnet name"
  type        = string
  default     = "resolver-inbound-subnet"
}

variable "resolver_inbound_subnet_address" {
  description = "Inbound resolver subnet address prefixes"
  type        = list(string)
}

variable "resolver_inbound_endpoint_address" {
  description = "Static IP for the resolver inbound endpoint"
  type        = string
}

variable "resolver_outbound_subnet_name" {
  description = "Outbound resolver subnet name"
  type        = string
  default     = "resolver-outbound-subnet"
}

variable "resolver_outbound_subnet_address" {
  description = "Outbound resolver subnet address prefixes"
  type        = list(string)
}

variable "private_resolver_name" {
  description = "Private DNS Resolver resource name"
  type        = string
  default     = "resolver"
}

variable "dns_forwarder_ip" {
  description = "IP address of the external DNS forwarder used in DNS resolver forwarding rules"
  type        = string
  default     = "8.8.8.8"
}

# ── Compute ─────────────────────────────────────────────────────

variable "bastion_pip_name" {
  description = "Bastion public IP name"
  type        = string
  default     = "bastion-pip"
}

variable "bastion_host_name" {
  description = "Bastion Host name"
  type        = string
  default     = "bastion-host"
}

variable "bastion_host_sku" {
  description = "Bastion Host SKU"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Developer"], var.bastion_host_sku)
    error_message = "Bastion SKU must be one of: Basic, Standard, Developer."
  }
}

variable "vm_nic_name" {
  description = "VM NIC name"
  type        = string
  default     = "vm-nic"
}

variable "vm_name" {
  description = "VM name"
  type        = string
  default     = "vm"
}

variable "vm_size" {
  description = "VM size"
  type        = string
  default     = "Standard_B2s"
}
