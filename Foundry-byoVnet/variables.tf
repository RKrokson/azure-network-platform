variable "resource_group_name_ai00" {
  description = "Resource Group Name"
  type        = string
  default     = "rg-ai00"
}

## Spoke VNet variables
## WARNING: Default address spaces use Block 2 (172.20.32.0/20). Block 3 is reserved for Foundry-managedVnet.
## See docs/ip-addressing.md for the full allocation table.
variable "ai_vnet_name" {
  description = "AI spoke VNet name"
  type        = string
  default     = "ai-vnet"
}
variable "ai_vnet_address_space" {
  description = "AI spoke VNet address space (Block 2 — 172.20.32.0/20)"
  type        = list(string)
  default     = ["172.20.32.0/20"]
}
variable "ai_foundry_subnet_name" {
  description = "Foundry workload subnet name (Microsoft.App delegation)"
  type        = string
  default     = "ai-foundry-subnet"
}
variable "ai_foundry_subnet_address" {
  description = "Foundry workload subnet address prefix"
  type        = list(string)
  default     = ["172.20.32.0/26"]
}
variable "private_endpoint_subnet_name" {
  description = "Private endpoint subnet name"
  type        = string
  default     = "private-endpoint-subnet"
}
variable "private_endpoint_subnet_address" {
  description = "Private endpoint subnet address prefix"
  type        = list(string)
  default     = ["172.20.33.0/24"]
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
