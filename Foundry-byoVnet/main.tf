########## Create infrastructure resources
##########

## Create a random string shared by every region
##
resource "random_string" "unique" {
  length      = 4
  min_numeric = 4
  numeric     = true
  special     = false
  lower       = true
  upper       = false
}

## Data imports from Networking
##

data "terraform_remote_state" "networking" {
  backend = "local"
  config = {
    path = "../Networking/terraform.tfstate"
  }
}

## Deploy one independent Foundry stack per selected region
## Prerequisites are enforced by variable validation in this module and in modules/foundry-region.
##
module "foundry_region" {
  for_each = local.selected_regions
  source   = "./modules/foundry-region"

  region_key                 = each.key
  platform                   = each.value
  network                    = var.regional_networks[each.key]
  name_suffix                = random_string.unique.result
  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id
  common_tags                = local.common_tags

  resource_group_name_ai00     = var.resource_group_name_ai00
  ai_vnet_name                 = var.ai_vnet_name
  ai_foundry_subnet_name       = var.ai_foundry_subnet_name
  private_endpoint_subnet_name = var.private_endpoint_subnet_name

  gpt_model_deployment_name = var.gpt_model_deployment_name
  gpt_model_name            = var.gpt_model_name
  gpt_model_version         = var.gpt_model_version
  gpt_model_sku_name        = var.gpt_model_sku_name
  gpt_model_capacity        = var.gpt_model_capacity

  ai_search_sku              = var.ai_search_sku
  foundry_sku                = var.foundry_sku
  deploy_agent_data_services = var.deploy_agent_data_services
}
