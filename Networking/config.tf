terraform {
  required_version = ">= 1.8.3"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # Wider range than Foundry modules (~> 4.26.0) is intentional —
      # this platform module should accept any 4.x provider without
      # forcing lockstep upgrades across all consumers.
      version = ">= 4.0, < 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.5"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.0, < 3.0"
    }
  }
}
provider "azurerm" {
  features {
    resource_group {
      # Disabled to allow clean terraform destroy in this non-production environment.
      # In production, set to true to prevent accidental deletion of RGs with resources.
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy          = true
      recover_soft_deleted_key_vaults       = false
      purge_soft_deleted_secrets_on_destroy = true
      recover_soft_deleted_secrets          = false
    }
  }
}
