########## Create infrastructure resources
##########

## Create a random string
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

# Precondition: Private DNS must be deployed in the Networking module
# The Foundry ALZ requires DNS zone IDs and resolver policy for private endpoint resolution
check "dns_prerequisite" {
  assert {
    condition     = data.terraform_remote_state.networking.outputs.dns_server_ip00 != null
    error_message = "Private DNS must be enabled in the Networking module (add_private_dns00 = true) before deploying this landing zone. DNS zones and resolver are required for private endpoint resolution."
  }
}

## Create a resource group for AI Foundry resources
##
resource "azurerm_resource_group" "rg-ai00" {
  name     = "${var.resource_group_name_ai00}-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  location = data.terraform_remote_state.networking.outputs.rg_net00_location
  tags     = local.common_tags
}
