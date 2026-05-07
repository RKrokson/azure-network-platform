# Configure the AzApi and AzureRM providers
terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.3.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.26.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  required_version = ">= 1.8.3"
  # Uncomment to store state in Azure Storage
  # backend "azurerm" {}
}
# Setup providers
provider "azurerm" {
  features {
    resource_group {
      # Disabled to allow clean terraform destroy in this non-production environment.
      # In production, set to true to prevent accidental deletion of RGs with resources.
      prevent_deletion_if_contains_resources = false
    }
  }
  storage_use_azuread = true
}