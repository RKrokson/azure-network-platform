# Configure providers for Fabric private module
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.26.0"
    }

    azapi = {
      source  = "azure/azapi"
      version = "~> 2.3.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }

    fabric = {
      source  = "microsoft/fabric"
      version = "~> 1.9" # identity block + fabric_lakehouse require >= 1.9
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.12" # time_sleep for Entra ID propagation delay on identity RBAC
    }
  }
  required_version = ">= 1.11"
  # Uncomment to store state in Azure Storage
  # backend "azurerm" {}
}

provider "azurerm" {
  features {
    resource_group {
      # Disabled to allow clean terraform destroy in this non-production environment.
      prevent_deletion_if_contains_resources = false
    }
  }
  storage_use_azuread = true
}

provider "fabric" {
  # fabric_workspace_managed_private_endpoint requires preview opt-in (fabric provider >= 1.x)
  preview = true
}
