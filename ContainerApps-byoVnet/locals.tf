locals {
  common_tags = {
    environment = "non-prod"
    managed_by  = "terraform"
    project     = "azure-infra-poc"
  }
}
