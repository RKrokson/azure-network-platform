########## Fabric private — Core resources & preconditions
##########

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

data "azurerm_client_config" "current" {}

# Resolve current user UPN when neither admin input is set (zero-config first run)
data "external" "current_user_upn" {
  count   = (length(var.capacity_admin_upn_list) == 0 && var.capacity_admin_group_object_id == null) ? 1 : 0
  program = ["pwsh", "-NoProfile", "-Command", "az ad signed-in-user show --query '{upn:userPrincipalName}' -o json"]
}

## Resource group
##

resource "azurerm_resource_group" "rg_fabric00" {
  name     = "${var.resource_group_name}-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  location = data.terraform_remote_state.networking.outputs.rg_net00_location
  tags     = local.common_tags
}

## Precondition checks
##

check "dns_prerequisite" {
  assert {
    condition     = data.terraform_remote_state.networking.outputs.dns_server_ip00 != null
    error_message = "Private DNS must be enabled in the Networking module (add_private_dns00 = true) before deploying this landing zone."
  }
}

check "fabric_dns_zone_present" {
  assert {
    condition     = data.terraform_remote_state.networking.outputs.dns_zone_fabric_id != null
    error_message = "dns_zone_fabric_id is null in Networking remote state. Ensure the Networking module exposes privatelink.fabric.microsoft.com zone output."
  }
}

check "sql_dns_zone_present" {
  assert {
    condition     = data.terraform_remote_state.networking.outputs.dns_zone_sql_id != null
    error_message = "dns_zone_sql_id is null in Networking remote state. Ensure the Networking module exposes privatelink.database.windows.net zone output."
  }
}

check "vhub_present" {
  assert {
    condition     = data.terraform_remote_state.networking.outputs.vhub00_id != null
    error_message = "vhub00_id is null — Virtual Hub must be deployed in the Networking module."
  }
}

check "exactly_one_admin_source" {
  assert {
    condition     = !(length(var.capacity_admin_upn_list) > 0 && var.capacity_admin_group_object_id != null)
    error_message = "Set either capacity_admin_upn_list OR capacity_admin_group_object_id, not both."
  }
}
