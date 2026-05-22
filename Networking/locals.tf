locals {
  suffix        = random_string.unique.id
  rg00_name     = azurerm_resource_group.rg-net00.name
  rg00_location = azurerm_resource_group.rg-net00.location

  common_tags = {
    environment = "non-prod"
    managed_by  = "terraform"
    project     = "azure-infra-poc"
  }
}
