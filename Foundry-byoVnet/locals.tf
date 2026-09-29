locals {
  alz_regions = data.terraform_remote_state.networking.outputs.alz_regions

  # region0 always deploys. region1 deploys only when this module asks for it and Networking provides it.
  selected_regions = {
    for key, region in local.alz_regions : key => region
    if key == "region0" || (key == "region1" && var.deploy_region1 && region.enabled)
  }

  common_tags = {
    environment = "non-prod"
    managed_by  = "terraform"
    project     = "azure-infra-poc"
  }
}