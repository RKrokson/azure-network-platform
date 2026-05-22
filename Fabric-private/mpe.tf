########## Managed Private Endpoints — Fabric workspace → shared resources
##########
# Fabric MPEs always land in "Pending" on the target resource.
# No platform auto-approval exists — Terraform must approve each one.
# Pattern: create MPE → list target PE connections → filter by PE resource ID → PUT to Approved.
#
# All MPE resources are gated on local.deploy_outbound — they are only deployed in
# outbound_only and inbound_and_outbound network_mode values.

# ─────────────────────────────────────────────
# MPE 1: Fabric → Lab Storage Account (blob)
# ─────────────────────────────────────────────

resource "fabric_workspace_managed_private_endpoint" "mpe_storage" {
  count                           = local.deploy_outbound ? 1 : 0 # outbound gate
  workspace_id                    = fabric_workspace.workspace.id
  name                            = "mpe-storage-blob-${random_string.unique.result}"
  target_private_link_resource_id = azurerm_storage_account.lab_storage[0].id
  target_subresource_type         = "blob"
  request_message                 = "Auto-created by Fabric-private Terraform module"
}

data "azapi_resource_list" "storage_pe_connections" {
  count      = local.deploy_outbound ? 1 : 0 # outbound gate
  type       = "Microsoft.Storage/storageAccounts/privateEndpointConnections@2023-05-01"
  parent_id  = azurerm_storage_account.lab_storage[0].id
  depends_on = [fabric_workspace_managed_private_endpoint.mpe_storage]
}

resource "azapi_resource_action" "approve_mpe_storage" {
  count       = local.deploy_outbound ? 1 : 0 # outbound gate
  type        = "Microsoft.Storage/storageAccounts/privateEndpointConnections@2023-05-01"
  resource_id = "${azurerm_storage_account.lab_storage[0].id}/privateEndpointConnections/${local.storage_pe_conn_name}"
  method      = "PUT"

  body = {
    properties = {
      privateLinkServiceConnectionState = {
        status      = "Approved"
        description = "Auto-approved by Fabric-private Terraform module"
      }
    }
  }
}

# ─────────────────────────────────────────────
# MPE 2: Fabric → Lab SQL Server
# ─────────────────────────────────────────────

resource "fabric_workspace_managed_private_endpoint" "mpe_sql" {
  count                           = local.deploy_outbound ? 1 : 0 # outbound gate
  workspace_id                    = fabric_workspace.workspace.id
  name                            = "mpe-sql-${random_string.unique.result}"
  target_private_link_resource_id = azurerm_mssql_server.lab_sql[0].id
  target_subresource_type         = "sqlServer"
  request_message                 = "Auto-created by Fabric-private Terraform module"
}

data "azapi_resource_list" "sql_pe_connections" {
  count      = local.deploy_outbound ? 1 : 0 # outbound gate
  type       = "Microsoft.Sql/servers/privateEndpointConnections@2023-08-01-preview"
  parent_id  = azurerm_mssql_server.lab_sql[0].id
  depends_on = [fabric_workspace_managed_private_endpoint.mpe_sql]
}

resource "azapi_resource_action" "approve_mpe_sql" {
  count       = local.deploy_outbound ? 1 : 0 # outbound gate
  type        = "Microsoft.Sql/servers/privateEndpointConnections@2023-08-01-preview"
  resource_id = "${azurerm_mssql_server.lab_sql[0].id}/privateEndpointConnections/${local.sql_pe_conn_name}"
  method      = "PUT"

  body = {
    properties = {
      privateLinkServiceConnectionState = {
        status      = "Approved"
        description = "Auto-approved by Fabric-private Terraform module"
      }
    }
  }
}

# ─────────────────────────────────────────────
# MPE 3: Fabric → Local Key Vault (LZ-scoped)
# The KV lives in the Fabric LZ RG (azurerm_key_vault.fabric_kv).
# Strict ID-filter lookup is preserved for parity with the storage/SQL MPEs.
# ─────────────────────────────────────────────

resource "fabric_workspace_managed_private_endpoint" "mpe_keyvault" {
  count                           = local.deploy_outbound ? 1 : 0 # outbound gate
  workspace_id                    = fabric_workspace.workspace.id
  name                            = "mpe-keyvault-${random_string.unique.result}"
  target_private_link_resource_id = azurerm_key_vault.fabric_kv[0].id
  target_subresource_type         = "vault"
  request_message                 = "Auto-created by Fabric-private Terraform module"
}

data "azapi_resource_list" "kv_pe_connections" {
  count      = local.deploy_outbound ? 1 : 0 # outbound gate
  type       = "Microsoft.KeyVault/vaults/privateEndpointConnections@2023-07-01"
  parent_id  = azurerm_key_vault.fabric_kv[0].id
  depends_on = [fabric_workspace_managed_private_endpoint.mpe_keyvault]
}

resource "azapi_resource_action" "approve_mpe_keyvault" {
  count       = local.deploy_outbound ? 1 : 0 # outbound gate
  type        = "Microsoft.KeyVault/vaults/privateEndpointConnections@2023-07-01"
  resource_id = "${azurerm_key_vault.fabric_kv[0].id}/privateEndpointConnections/${local.kv_pe_conn_name}"
  method      = "PUT"

  body = {
    properties = {
      privateLinkServiceConnectionState = {
        status      = "Approved"
        description = "Auto-approved by Fabric-private Terraform module"
      }
    }
  }
}

# ─────────────────────────────────────────────
# PE connection name lookup — filter by MPE resource ID (M2 requirement)
# NEVER filter by "first Pending", name pattern, or state alone.
#
# Safe access pattern: one(resource[*].attribute) returns null when count=0 (no [0] indexing).
# try() catches null-dereference on one(data_source[*]).output.value when data source has count=0.
# ─────────────────────────────────────────────

locals {
  # Safe MPE name access — null when the resource has count=0
  _mpe_storage_name  = one(fabric_workspace_managed_private_endpoint.mpe_storage[*].name)
  _mpe_sql_name      = one(fabric_workspace_managed_private_endpoint.mpe_sql[*].name)
  _mpe_keyvault_name = one(fabric_workspace_managed_private_endpoint.mpe_keyvault[*].name)

  # Safe PE connection list access — [] when the data source has count=0
  # try() catches the null-dereference on one([]).output (one([]) returns null)
  _storage_pe_conns = try(one(data.azapi_resource_list.storage_pe_connections[*]).output.value, [])
  _sql_pe_conns     = try(one(data.azapi_resource_list.sql_pe_connections[*]).output.value, [])
  _kv_pe_conns      = try(one(data.azapi_resource_list.kv_pe_connections[*]).output.value, [])

  # Fabric names the managed PE as "{workspace_id}.{mpe_name}" in the Fabric-managed subscription.
  # The ARM PE connection object's privateEndpoint.id ends with that string.
  # We match by suffix — never by Fabric resource UUID (which is not an ARM ID).
  storage_pe_conn_name = one([
    for conn in local._storage_pe_conns :
    conn.name
    if endswith(
      lower(try(conn.properties.privateEndpoint.id, "")),
      lower("${fabric_workspace.workspace.id}.${coalesce(local._mpe_storage_name, "")}")
    )
  ])

  sql_pe_conn_name = one([
    for conn in local._sql_pe_conns :
    conn.name
    if endswith(
      lower(try(conn.properties.privateEndpoint.id, "")),
      lower("${fabric_workspace.workspace.id}.${coalesce(local._mpe_sql_name, "")}")
    )
  ])

  kv_pe_conn_name = one([
    for conn in local._kv_pe_conns :
    conn.name
    if endswith(
      lower(try(conn.properties.privateEndpoint.id, "")),
      lower("${fabric_workspace.workspace.id}.${coalesce(local._mpe_keyvault_name, "")}")
    )
  ])

  # Safe storage/SQL/KV IDs for check block data sources — null when resource has count=0
  _lab_storage_id = one(azurerm_storage_account.lab_storage[*].id)
  _lab_sql_id     = one(azurerm_mssql_server.lab_sql[*].id)
  _lab_kv_id      = one(azurerm_key_vault.fabric_kv[*].id)
}

# ─────────────────────────────────────────────
# Post-apply assertions — verify each MPE reached Approved state
# check {} blocks re-evaluate at end of apply; silent Pending is the failure mode.
#
# Assertions use !local.deploy_outbound short-circuit so they always pass in inbound_only mode.
# Data source resource_id falls back to a placeholder when the resource has count=0 — the
# data lookup will fail gracefully (warning only) and the assertion short-circuits to pass.
# ─────────────────────────────────────────────

check "mpe_storage_approved" {
  data "azapi_resource" "mpe_storage_conn" {
    type = "Microsoft.Storage/storageAccounts/privateEndpointConnections@2023-05-01"
    resource_id = local._lab_storage_id != null ? (
      "${local._lab_storage_id}/privateEndpointConnections/${coalesce(local.storage_pe_conn_name, "placeholder")}"
    ) : "placeholder-not-deployed"
    response_export_values = ["properties.privateLinkServiceConnectionState.status"]
  }
  assert {
    condition     = !local.deploy_outbound || data.azapi_resource.mpe_storage_conn.output.properties.privateLinkServiceConnectionState.status == "Approved"
    error_message = "MPE to Storage (blob) is not Approved after auto-approval. Run: az network private-endpoint-connection approve"
  }
}

check "mpe_sql_approved" {
  data "azapi_resource" "mpe_sql_conn" {
    type = "Microsoft.Sql/servers/privateEndpointConnections@2023-08-01-preview"
    resource_id = local._lab_sql_id != null ? (
      "${local._lab_sql_id}/privateEndpointConnections/${coalesce(local.sql_pe_conn_name, "placeholder")}"
    ) : "placeholder-not-deployed"
    response_export_values = ["properties.privateLinkServiceConnectionState.status"]
  }
  assert {
    condition     = !local.deploy_outbound || data.azapi_resource.mpe_sql_conn.output.properties.privateLinkServiceConnectionState.status == "Approved"
    error_message = "MPE to SQL Server is not Approved after auto-approval. Run: az network private-endpoint-connection approve"
  }
}

check "mpe_keyvault_approved" {
  data "azapi_resource" "mpe_kv_conn" {
    type = "Microsoft.KeyVault/vaults/privateEndpointConnections@2023-07-01"
    resource_id = local._lab_kv_id != null ? (
      "${local._lab_kv_id}/privateEndpointConnections/${coalesce(local.kv_pe_conn_name, "placeholder")}"
    ) : "placeholder-not-deployed"
    response_export_values = ["properties.privateLinkServiceConnectionState.status"]
  }
  assert {
    condition     = !local.deploy_outbound || data.azapi_resource.mpe_kv_conn.output.properties.privateLinkServiceConnectionState.status == "Approved"
    error_message = "MPE to Key Vault is not Approved after auto-approval. Run: az network private-endpoint-connection approve"
  }
}

