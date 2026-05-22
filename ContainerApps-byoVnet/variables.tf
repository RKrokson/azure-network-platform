variable "resource_group_name" {
  description = "Resource group name for Container Apps landing zone"
  type        = string
  default     = "rg-aca00"
}

## Spoke VNet variables
## WARNING: Default address spaces use Block 4 (172.20.64.0/20).
## See docs/ip-addressing.md for the full allocation table.
variable "aca_vnet_name" {
  description = "ACA spoke VNet name"
  type        = string
  default     = "aca-vnet"
}
variable "aca_vnet_address_space" {
  description = "ACA spoke VNet address space (Block 4 — 172.20.64.0/20)"
  type        = list(string)
  default     = ["172.20.64.0/20"]
}
variable "aca_subnet_name" {
  description = "Container Apps Environment subnet name (delegated to Microsoft.App/environments)"
  type        = string
  default     = "aca-subnet"
}
variable "aca_subnet_address" {
  description = "Container Apps Environment subnet address prefix (/27 minimum for workload profiles)"
  type        = list(string)
  default     = ["172.20.64.0/27"]
}
variable "pe_subnet_name" {
  description = "Private endpoint subnet name"
  type        = string
  default     = "private-endpoint-subnet"
}
variable "pe_subnet_address" {
  description = "Private endpoint subnet address prefix"
  type        = list(string)
  default     = ["172.20.65.0/24"]
}

## Container Apps Environment variables
variable "aca_environment_name" {
  description = "Container Apps Environment name"
  type        = string
  default     = "aca-env"
}
variable "add_dedicated_workload_profile" {
  description = "Deploy an optional D4 dedicated workload profile alongside the default Consumption profile"
  type        = bool
  default     = false
}

## Azure Container Registry variables
variable "acr_name" {
  description = "Azure Container Registry name (alphanumeric only, must be globally unique — suffix is appended)"
  type        = string
  default     = "acr"
}
variable "acr_sku" {
  description = "ACR SKU (must be Premium for private endpoints)"
  type        = string
  default     = "Premium"
  validation {
    condition     = lower(var.acr_sku) == "premium"
    error_message = "acr_sku must be set to \"Premium\" because this module always creates an ACR private endpoint."
  }
}

## Container app deployment mode
variable "app_mode" {
  description = "Container app deployment mode: 'none' (environment only), 'hello-world' (quickstart verification), or 'mcp-toolbox' (MCP Toolkit server)"
  type        = string
  default     = "hello-world"
  validation {
    condition     = contains(["none", "hello-world", "mcp-toolbox"], var.app_mode)
    error_message = "app_mode must be 'none', 'hello-world', or 'mcp-toolbox'."
  }
}

variable "mcp_dashboard_enabled" {
  description = "Enable the MCP Toolbox diagnostic dashboard and /api/* endpoints (exposes recent request data — use only in trusted lab environments)"
  type        = bool
  default     = false
}
