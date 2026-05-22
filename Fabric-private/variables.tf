variable "resource_group_name" {
  description = "Resource group name prefix"
  type        = string
  default     = "rg-fabric00"
}

## Spoke VNet — Block 5 (172.20.80.0/20)
## See docs/ip-addressing.md for the full allocation table.
variable "fabric_vnet_name" {
  description = "Fabric spoke VNet name"
  type        = string
  default     = "fabric-vnet"
}

variable "fabric_vnet_address_space" {
  description = "Fabric spoke VNet address space (Block 5 — 172.20.80.0/20)"
  type        = list(string)
  default     = ["172.20.80.0/20"]
}

variable "pe_subnet_name" {
  description = "Private endpoint subnet name"
  type        = string
  default     = "private-endpoint-subnet"
}

variable "pe_subnet_address" {
  description = "Private endpoint subnet address prefix (/24 within Block 5)"
  type        = list(string)
  default     = ["172.20.80.0/24"]
}

## Fabric capacity
variable "fabric_capacity_sku" {
  description = "Fabric capacity SKU name (F2, F4, F8, etc.)"
  type        = string
  default     = "F2"
  validation {
    condition     = can(regex("^F(2|4|8|16|32|64|128|256|512|1024|2048)$", var.fabric_capacity_sku))
    error_message = "fabric_capacity_sku must be a valid Fabric F-SKU (F2, F4, F8, ...)."
  }
}

## Capacity admin identity
variable "capacity_admin_upn_list" {
  description = "List of UPNs to assign as Fabric Capacity admins. Either this OR capacity_admin_group_object_id must be set. Defaults to current Azure CLI signed-in user."
  type        = list(string)
  default     = []
}

variable "capacity_admin_group_object_id" {
  description = "Object ID of an Entra security group for Fabric Capacity admins. Takes precedence over capacity_admin_upn_list. Recommended for shared environments."
  type        = string
  default     = null
}

## Network connectivity mode
variable "network_mode" {
  description = <<-EOT
    Controls which private connectivity paths are deployed.
      inbound_only         — Workspace PE + deny-public-access policy. No MPEs, no storage account, no SQL, no KV. (Default)
      outbound_only        — MPEs + storage + SQL + KV. No workspace PE, no communication policy. Workspace is publicly reachable.
                             Use this when the Fabric tenant setting "Configure workspace-level inbound network rules" is not enabled,
                             or when the customer accepts public Fabric access but requires private data-plane connectivity to Azure
                             resources. This is a valid demo/POC pattern for outbound-only private networking.
      inbound_and_outbound — Both directions. Full private connectivity.
  EOT
  type        = string
  default     = "inbound_only"
  validation {
    condition     = contains(["inbound_only", "outbound_only", "inbound_and_outbound"], var.network_mode)
    error_message = "Allowed values: 'inbound_only', 'outbound_only', 'inbound_and_outbound'."
  }
}

## Workspace content
variable "workspace_content_mode" {
  description = "Sample content to deploy in the workspace. 'none' (default) ships an empty workspace. 'lakehouse' deploys a native OneLake-backed Lakehouse — opt in via tfvars."
  type        = string
  default     = "none"
  validation {
    condition     = contains(["none", "lakehouse"], var.workspace_content_mode)
    error_message = "Allowed values: 'none', 'lakehouse'."
  }
}
