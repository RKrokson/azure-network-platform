########## Fabric Capacity & Workspace
##########

resource "azurerm_fabric_capacity" "fabric_capacity" {
  name                = "fabriccap${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg_fabric00.name
  location            = azurerm_resource_group.rg_fabric00.location

  sku {
    name = var.fabric_capacity_sku
    tier = "Fabric"
  }

  administration_members = local.capacity_admins
  tags                   = local.common_tags
}

# The fabric_workspace resource requires the Fabric-side capacity UUID, not the ARM resource ID.
# This data source looks up the UUID by display_name (which matches the ARM resource name).
data "fabric_capacity" "this" {
  display_name = azurerm_fabric_capacity.fabric_capacity.name
  depends_on   = [azurerm_fabric_capacity.fabric_capacity]
}

resource "fabric_workspace" "workspace" {
  display_name = "fabric-workspace-${random_string.unique.result}"
  capacity_id  = data.fabric_capacity.this.id
  description  = "Fabric workspace for Private lab deployment"

  # System-Assigned identity is always provisioned — it's free and enables outbound RBAC
  # (Storage Blob Data Contributor on the lab storage account when deploy_outbound = true).
  identity = {
    type = "SystemAssigned"
  }
}

########## Fabric Lakehouse (optional — gated on workspace_content_mode = "lakehouse")
##########
# Deploys a native OneLake-backed Lakehouse in the workspace.
# Naming: lakehouse-{4-digit-suffix} (no region abbreviation — Fabric items are workspace-scoped,
# not region-scoped ARM resources).
# Default is 'none' — set workspace_content_mode = "lakehouse" in tfvars to opt in.
#
# NOTE: purge-soft-deleted.ps1 does not yet exist in this module.
# TODO (future purge script): When workspace_content_mode = "lakehouse" is active, add OneLake
# item purge logic — workspace soft-delete does not immediately purge OneLake data (90-day retention).
# See: https://learn.microsoft.com/en-us/fabric/onelake/onelake-disaster-recovery

resource "fabric_lakehouse" "lab_lakehouse" {
  count        = var.workspace_content_mode == "lakehouse" ? 1 : 0
  display_name = "Lakehouse_${random_string.unique.result}"
  workspace_id = fabric_workspace.workspace.id
  description  = "Lab Lakehouse — OneLake-backed, deployed by Fabric-private module"
}

########## Workspace-Level Private Endpoint (inbound gate)
##########
# Microsoft.Fabric/privateLinkServicesForFabric is a real ARM type (API 2024-06-01).
# It is workspace-scoped — completely distinct from the tenant-level
# Microsoft.PowerBI/privateLinkServicesForPowerBI type.
# Prerequisites (manual, out-of-band):
#   1. Fabric tenant setting "Configure workspace-level inbound network rules" enabled.
#   2. Microsoft.Fabric resource provider registered in the subscription.
#
# Gated on deploy_inbound: present in inbound_only and inbound_and_outbound modes.

resource "azapi_resource" "fabric_private_link_service" {
  count     = local.deploy_inbound ? 1 : 0 # inbound gate — workspace PE anchors the inbound private path
  type      = "Microsoft.Fabric/privateLinkServicesForFabric@2024-06-01"
  name      = "fabric-pls-${random_string.unique.result}"
  location  = "global"
  parent_id = azurerm_resource_group.rg_fabric00.id

  # Microsoft.Fabric/privateLinkServicesForFabric is not yet in the azapi provider's
  # bundled schema; disable local validation so azapi passes the request to ARM directly.
  schema_validation_enabled = false

  body = {
    properties = {
      tenantId    = data.azurerm_client_config.current.tenant_id
      workspaceId = fabric_workspace.workspace.id
    }
  }

  depends_on = [fabric_workspace.workspace]
}

resource "azurerm_private_endpoint" "pe_fabric_workspace" {
  count               = local.deploy_inbound ? 1 : 0 # inbound gate — workspace PE for private inbound connectivity
  name                = "fabric-workspace-pe-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg_fabric00.name
  location            = azurerm_resource_group.rg_fabric00.location
  subnet_id           = azurerm_subnet.pe_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "fabric-workspace-pe-connection"
    private_connection_resource_id = azapi_resource.fabric_private_link_service[0].id
    subresource_names              = ["workspace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "fabric-workspace-dns-config"
    private_dns_zone_ids = [
      data.terraform_remote_state.networking.outputs.dns_zone_fabric_id
    ]
  }
}
