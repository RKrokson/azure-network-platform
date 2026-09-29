########## Regional Foundry stack
##########

# Provider sources only. Versions are pinned by the root module config.tf.
terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}

## Create a resource group for AI Foundry resources
##
resource "azurerm_resource_group" "rg-ai00" {
  name     = "${var.resource_group_name_ai00}-${var.platform.region_abbr}-${var.name_suffix}"
  location = var.platform.resource_group_location
  tags     = var.common_tags
}
