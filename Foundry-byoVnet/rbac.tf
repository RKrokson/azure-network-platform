## Create the necessary role assignments for the AI Foundry project over the resources used to store agent data
##
resource "azurerm_role_assignment" "cosmosdb_operator_foundry_project" {
  depends_on = [
    resource.time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${azurerm_resource_group.rg-ai00.name}cosmosdboperator")
  scope                = azurerm_cosmosdb_account.cosmosdb.id
  role_definition_name = "Cosmos DB Operator"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "storage_blob_data_contributor_foundry_project" {
  depends_on = [
    resource.time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${azurerm_storage_account.storage_account.name}storageblobdatacontributor")
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "search_index_data_contributor_foundry_project" {
  depends_on = [
    resource.time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${azapi_resource.ai_search.name}searchindexdatacontributor")
  scope                = azapi_resource.ai_search.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "search_service_contributor_foundry_project" {
  depends_on = [
    resource.time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${azapi_resource.ai_search.name}searchservicecontributor")
  scope                = azapi_resource.ai_search.id
  role_definition_name = "Search Service Contributor"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
}

## Create the necessary data plane role assignments to the CosmosDb databases created by the AI Foundry Project
##
resource "azurerm_cosmosdb_sql_role_assignment" "cosmosdb_db_sql_role_aifp" {
  depends_on = [
    azapi_resource.foundry_project_capability_host
  ]
  name                = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}cosmosdb_dbsqlrole")
  resource_group_name = azurerm_resource_group.rg-ai00.name
  account_name        = azurerm_cosmosdb_account.cosmosdb.name
  scope               = azurerm_cosmosdb_account.cosmosdb.id
  role_definition_id  = "${azurerm_cosmosdb_account.cosmosdb.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azapi_resource.foundry_project.output.identity.principalId
}

## Create the necessary data plane role assignments to the Azure Storage Account containers created by the AI Foundry Project
##
resource "azurerm_role_assignment" "storage_blob_data_owner_foundry_project" {
  depends_on = [
    azapi_resource.foundry_project_capability_host
  ]
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${azurerm_storage_account.storage_account.name}storageblobdataowner")
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
  condition_version    = "2.0"
  condition            = <<-EOT
  (
    (
      !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/read'})  
      AND  !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/filter/action'}) 
      AND  !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/write'}) 
    ) 
    OR 
    (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringStartsWithIgnoreCase '${local.project_id_guid}' 
    AND @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringLikeIgnoreCase '*-azureml-agent')
  )
  EOT
}
