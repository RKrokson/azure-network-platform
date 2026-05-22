output "resource_group_id" {
  description = "The ID of the Fabric resource group"
  value       = azurerm_resource_group.rg_fabric00.id
}

output "fabric_capacity_id" {
  description = "The ID of the Fabric capacity"
  value       = azurerm_fabric_capacity.fabric_capacity.id
}

output "fabric_workspace_id" {
  description = "The ID of the Fabric workspace"
  value       = fabric_workspace.workspace.id
}

output "workspace_identity_application_id" {
  description = "Entra application ID of the workspace System-Assigned identity (always provisioned)"
  value       = fabric_workspace.workspace.identity.application_id
}

output "workspace_identity_service_principal_id" {
  description = "Entra service principal object ID of the workspace identity (always provisioned; used for Storage RBAC in outbound mode)"
  value       = fabric_workspace.workspace.identity.service_principal_id
}

output "storage_account_id" {
  description = "The ID of the lab storage account (null if network_mode excludes outbound)"
  value       = local.deploy_outbound ? azurerm_storage_account.lab_storage[0].id : null
}

output "sql_server_id" {
  description = "The ID of the lab SQL server (null if network_mode excludes outbound)"
  value       = local.deploy_outbound ? azurerm_mssql_server.lab_sql[0].id : null
}

output "sql_database_id" {
  description = "The ID of the lab SQL database (null if network_mode excludes outbound)"
  value       = local.deploy_outbound ? azurerm_mssql_database.lab_db[0].id : null
}

output "mpe_storage_id" {
  description = "The ID of the Storage blob MPE (null if network_mode excludes outbound)"
  value       = local.deploy_outbound ? fabric_workspace_managed_private_endpoint.mpe_storage[0].id : null
}

output "mpe_sql_id" {
  description = "The ID of the SQL Server MPE (null if network_mode excludes outbound)"
  value       = local.deploy_outbound ? fabric_workspace_managed_private_endpoint.mpe_sql[0].id : null
}

output "key_vault_id" {
  description = "The ID of the LZ-local Fabric Key Vault (null if network_mode excludes outbound)"
  value       = local.deploy_outbound ? azurerm_key_vault.fabric_kv[0].id : null
}

output "mpe_keyvault_id" {
  description = "The ID of the Key Vault MPE (null if network_mode excludes outbound)"
  value       = local.deploy_outbound ? fabric_workspace_managed_private_endpoint.mpe_keyvault[0].id : null
}

output "workspace_private_link_service_id" {
  description = "The ARM resource ID of the Fabric workspace private link service (null if network_mode excludes inbound)"
  value       = local.deploy_inbound ? azapi_resource.fabric_private_link_service[0].id : null
}

output "workspace_private_endpoint_id" {
  description = "The resource ID of the Fabric workspace private endpoint (null if network_mode excludes inbound)"
  value       = local.deploy_inbound ? azurerm_private_endpoint.pe_fabric_workspace[0].id : null
}

output "workspace_private_endpoint_ip" {
  description = "The private IP address assigned to the Fabric workspace private endpoint (null if network_mode excludes inbound)"
  value       = local.deploy_inbound ? azurerm_private_endpoint.pe_fabric_workspace[0].private_service_connection[0].private_ip_address : null
}
