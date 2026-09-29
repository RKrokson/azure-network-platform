locals {
  alz_regions = data.terraform_remote_state.networking.outputs.alz_regions

  selected_regions = {
    region0 = local.alz_regions.region0
  }

  common_tags = {
    environment = "non-prod"
    managed_by  = "terraform"
    project     = "azure-infra-poc"
  }
}