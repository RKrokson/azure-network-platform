## Regional context
variable "region_key" {
  description = "alz_regions key for this stack: region0 or region1"
  type        = string

  validation {
    condition     = contains(["region0", "region1"], var.region_key)
    error_message = "region_key must be region0 or region1."
  }
}

variable "platform" {
  description = "Networking alz_regions entry for this region"
  type = object({
    region_name             = string
    region_abbr             = string
    resource_group_location = string
    vhub_id                 = string
    firewall_enabled        = bool
    dns_server_ip           = string
    dns_resolver_policy_id  = string
    private_dns_zone_ids    = map(string)
  })

  validation {
    condition     = can(regex("^[a-z0-9]{1,9}$", var.platform.region_abbr))
    error_message = "Networking ${var.region_key} region_abbr must be 1 to 9 lowercase letters or digits so the Storage account name stays within 24 characters (got \"${coalesce(var.platform.region_abbr, "null")}\")."
  }

  validation {
    condition     = var.platform.vhub_id != null
    error_message = "Networking ${var.region_key} has no virtual hub. Apply Networking with create_vhub01 = true before deploying region1."
  }

  validation {
    condition     = var.platform.dns_server_ip != null && var.platform.dns_resolver_policy_id != null
    error_message = "Networking ${var.region_key} has no Private DNS. Apply Networking with add_private_dns0${trimprefix(var.region_key, "region")} = true before deploying this landing zone."
  }

  validation {
    condition     = alltrue([for zone in ["cognitiveservices", "services_ai", "openai"] : try(var.platform.private_dns_zone_ids[zone], null) != null])
    error_message = "Networking ${var.region_key} is missing Foundry Private DNS zone IDs: ${join(", ", [for zone in ["cognitiveservices", "services_ai", "openai"] : zone if try(var.platform.private_dns_zone_ids[zone], null) == null])}."
  }

  validation {
    condition     = !var.deploy_agent_data_services || alltrue([for zone in ["blob", "documents", "search"] : try(var.platform.private_dns_zone_ids[zone], null) != null])
    error_message = "Networking ${var.region_key} is missing agent data service Private DNS zone IDs: ${join(", ", [for zone in ["blob", "documents", "search"] : zone if try(var.platform.private_dns_zone_ids[zone], null) == null])}."
  }
}

variable "network" {
  description = "Address prefixes for this region's spoke VNet"
  type = object({
    vnet_address_space              = list(string)
    foundry_subnet_address          = list(string)
    private_endpoint_subnet_address = list(string)
  })
}

variable "name_suffix" {
  description = "Random suffix shared by every region"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Shared platform Log Analytics workspace ID"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to taggable resources"
  type        = map(string)
}

## Names
variable "resource_group_name_ai00" {
  description = "Resource group base name"
  type        = string
}

variable "ai_vnet_name" {
  description = "AI spoke VNet base name"
  type        = string
}

variable "ai_foundry_subnet_name" {
  description = "Foundry workload subnet base name"
  type        = string
}

variable "private_endpoint_subnet_name" {
  description = "Private endpoint subnet base name"
  type        = string
}

## Model deployment
variable "gpt_model_deployment_name" {
  description = "Name of the GPT model deployment"
  type        = string
}

variable "gpt_model_name" {
  description = "GPT model name"
  type        = string
}

variable "gpt_model_version" {
  description = "GPT model version"
  type        = string
}

variable "gpt_model_sku_name" {
  description = "SKU name for the GPT model deployment"
  type        = string
}

variable "gpt_model_capacity" {
  description = "Capacity units for the GPT model deployment"
  type        = number
}

## Service SKUs
variable "ai_search_sku" {
  description = "SKU for the AI Search service"
  type        = string
}

variable "foundry_sku" {
  description = "SKU for the Foundry account and project"
  type        = string
}

## Agent data services
variable "deploy_agent_data_services" {
  description = "Deploy BYO agent data services (Storage, Cosmos DB, AI Search) and their dependents"
  type        = bool
}
