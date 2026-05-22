########## Outbound Resources — Storage, SQL, Key Vault, Identity RBAC
##########
# All resources in this file are gated on local.deploy_outbound.
# Present in outbound_only and inbound_and_outbound network_mode values.
# In inbound_only mode, none of these resources are deployed.

########## Local Key Vault (LZ-scoped, MPE target)
##########
# Lives in the Fabric LZ resource group so destroy doesn't leave orphaned PE
# connections on the shared Networking KV. Workspace reaches it via MPE 3.

resource "azurerm_key_vault" "fabric_kv" {
  count               = local.deploy_outbound ? 1 : 0 # outbound gate — KV is the MPE target, not needed for inbound-only
  name                = "kv-fabric-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg_fabric00.name
  location            = azurerm_resource_group.rg_fabric00.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization     = true
  public_network_access_enabled = false
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7

  tags = local.common_tags
}

resource "azurerm_private_endpoint" "pe_fabric_kv" {
  count               = local.deploy_outbound ? 1 : 0 # outbound gate — conventional ARM PE for KV, needed alongside MPE
  name                = "fabric-kv-pe-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg_fabric00.name
  location            = azurerm_resource_group.rg_fabric00.location
  subnet_id           = azurerm_subnet.pe_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "fabric-kv-pe-connection"
    private_connection_resource_id = azurerm_key_vault.fabric_kv[0].id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "fabric-kv-dns-config"
    private_dns_zone_ids = [
      data.terraform_remote_state.networking.outputs.dns_zone_vaultcore_id
    ]
  }
}

########## Lab Storage Account (ADLS Gen 2 — MPE blob target)
##########
# is_hns_enabled = true enables the hierarchical namespace (ADLS Gen 2 APIs).
# MPE target_subresource_type stays "blob" — Fabric uses the blob endpoint for ADLS Gen 2 access
# internally; the "dfs" subresource is not needed for the MPE.

resource "azurerm_storage_account" "lab_storage" {
  count               = local.deploy_outbound ? 1 : 0 # outbound gate — storage is the MPE target, not needed for inbound-only
  name                = "fabstor${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg_fabric00.name
  location            = azurerm_resource_group.rg_fabric00.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true # enables ADLS Gen 2 hierarchical namespace

  shared_access_key_enabled       = false
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  tags                            = local.common_tags

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

########## Lab Azure SQL Server & Database (MPE target — Entra-only auth)
##########

resource "azurerm_mssql_server" "lab_sql" {
  count                         = local.deploy_outbound ? 1 : 0 # outbound gate — SQL is the MPE target, not needed for inbound-only
  name                          = "fabsql${random_string.unique.result}"
  resource_group_name           = azurerm_resource_group.rg_fabric00.name
  location                      = azurerm_resource_group.rg_fabric00.location
  version                       = "12.0"
  public_network_access_enabled = false
  minimum_tls_version           = "1.2"
  tags                          = local.common_tags

  azuread_administrator {
    login_username              = local.capacity_admins[0]
    object_id                   = data.azurerm_client_config.current.object_id
    azuread_authentication_only = true
  }
}

resource "azurerm_mssql_database" "lab_db" {
  count     = local.deploy_outbound ? 1 : 0 # outbound gate — database only needed when SQL server is deployed
  name      = "fabdb${random_string.unique.result}"
  server_id = azurerm_mssql_server.lab_sql[0].id
  sku_name  = "Basic"
  tags      = local.common_tags
}

########## Workspace Identity → Storage RBAC
##########
# The workspace System-Assigned identity needs Storage Blob Data Contributor on the storage
# account to read/write data via the MPE path.
#
# A 60-second sleep guards against Entra ID propagation delay — a newly provisioned service
# principal may not be visible to Azure RBAC for up to ~60 seconds after identity creation.
# If azurerm_role_assignment fires immediately, ARM returns "principal not found" and fails.
#
# principal_type = "ServicePrincipal" is critical: it instructs ARM to skip the Graph lookup
# that would fail during the propagation window and assign directly by object ID instead.

resource "time_sleep" "wait_for_identity_propagation" {
  count           = local.deploy_outbound ? 1 : 0 # outbound gate — identity RBAC only needed when storage account exists
  create_duration = "60s"
  depends_on      = [fabric_workspace.workspace]

  triggers = {
    # Re-trigger the wait if the service principal ID changes (e.g., identity reprovisioned)
    sp_id = fabric_workspace.workspace.identity.service_principal_id
  }
}

resource "azurerm_role_assignment" "workspace_identity_storage" {
  count                = local.deploy_outbound ? 1 : 0 # outbound gate — RBAC only meaningful when the storage MPE path is active
  scope                = azurerm_storage_account.lab_storage[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = fabric_workspace.workspace.identity.service_principal_id
  # principal_type = "ServicePrincipal" bypasses ARM's Graph lookup during the propagation window.
  # Without it, role assignment can fail with "PrincipalNotFound" in the 0–60 s window post-identity creation.
  principal_type = "ServicePrincipal"
  depends_on     = [time_sleep.wait_for_identity_propagation]
}
