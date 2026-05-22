########## Container Apps Environment
##########

# Container Apps Environment — internal load balancer, workload profiles enabled
resource "azurerm_container_app_environment" "aca_env" {
  name                           = "${var.aca_environment_name}-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  location                       = azurerm_resource_group.rg_aca00.location
  resource_group_name            = azurerm_resource_group.rg_aca00.name
  log_analytics_workspace_id     = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id
  infrastructure_subnet_id       = azurerm_subnet.aca_subnet.id
  internal_load_balancer_enabled = true
  zone_redundancy_enabled        = false
  tags                           = local.common_tags

  # Consumption profile enables workload profiles mode
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  # Optional dedicated D4 workload profile
  dynamic "workload_profile" {
    for_each = var.add_dedicated_workload_profile ? [1] : []
    content {
      name                  = "dedicated-d4"
      workload_profile_type = "D4"
      minimum_count         = 0
      maximum_count         = 3
    }
  }

  lifecycle {
    ignore_changes = [infrastructure_resource_group_name]
  }
}
