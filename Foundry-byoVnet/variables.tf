variable "resource_group_name_ai00" {
  description = "Resource Group Name"
  type        = string
  default     = "rg-ai00"
}

## Spoke VNet variables
## WARNING: Defaults use Block 2 (172.20.32.0/20). Block 3 is reserved for Foundry-managedVnet.
## See docs/ip-addressing.md for the full allocation table.
variable "regional_networks" {
  description = "Spoke VNet and subnet address prefixes keyed by alz_regions key. Overriding one region requires supplying the whole map."
  type = map(object({
    vnet_address_space              = list(string)
    foundry_subnet_address          = list(string)
    private_endpoint_subnet_address = list(string)
  }))
  default = {
    region0 = {
      vnet_address_space              = ["172.20.32.0/20"]
      foundry_subnet_address          = ["172.20.32.0/26"]
      private_endpoint_subnet_address = ["172.20.33.0/24"]
    }
  }

  validation {
    condition     = contains(keys(var.regional_networks), "region0")
    error_message = "regional_networks must contain region0."
  }

  validation {
    condition     = alltrue([for key in keys(var.regional_networks) : contains(["region0", "region1"], key)])
    error_message = "regional_networks keys must be region0 or region1. Unknown keys: ${join(", ", [for key in keys(var.regional_networks) : key if !contains(["region0", "region1"], key)])}."
  }
}

variable "ai_vnet_name" {
  description = "AI spoke VNet name"
  type        = string
  default     = "ai-vnet"
}
variable "ai_foundry_subnet_name" {
  description = "Foundry workload subnet name (Microsoft.App delegation)"
  type        = string
  default     = "ai-foundry-subnet"
}
variable "private_endpoint_subnet_name" {
  description = "Private endpoint subnet name"
  type        = string
  default     = "private-endpoint-subnet"
}
## GPT model deployment variables
variable "gpt_model_deployment_name" {
  description = "Name of the GPT model deployment in AI Foundry"
  type        = string
  default     = "gpt-5.4"
}
variable "gpt_model_name" {
  description = "GPT model name"
  type        = string
  default     = "gpt-5.4"
}
variable "gpt_model_version" {
  description = "GPT model version"
  type        = string
  default     = "2026-03-05"
}
variable "gpt_model_sku_name" {
  description = "SKU name for the GPT model deployment"
  type        = string
  default     = "GlobalStandard"
}
variable "gpt_model_capacity" {
  description = "Capacity units for the GPT model deployment"
  type        = number
  default     = 1
}

## Service SKU variables
variable "ai_search_sku" {
  description = "SKU for the AI Search service"
  type        = string
  default     = "standard"
}
variable "foundry_sku" {
  description = "SKU for the AI Foundry (Cognitive Services) account and project"
  type        = string
  default     = "S0"
}

## Agent data services
variable "deploy_agent_data_services" {
  description = "Deploy BYO agent data services (Storage, Cosmos DB, AI Search) with their private endpoints, project connections, role assignments, and diagnostics. When false, Foundry Agent Service uses Microsoft-managed storage for agent data."
  type        = bool
  default     = true
}
