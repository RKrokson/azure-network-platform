output "resource_group_id" {
  description = "The ID of the Foundry resource group"
  value       = azurerm_resource_group.rg-ai01.id
}

output "ai_foundry_id" {
  description = "The ID of the AI Foundry account"
  value       = azapi_resource.foundry.id
}

output "ai_foundry_project_id" {
  description = "The ID of the AI Foundry project"
  value       = azapi_resource.foundry_project.id
}

output "storage_account_id" {
  description = "The ID of the Storage Account"
  value       = azurerm_storage_account.storage_account.id
}

output "cosmosdb_account_id" {
  description = "The ID of the Cosmos DB account"
  value       = azurerm_cosmosdb_account.cosmosdb.id
}

output "ai_search_id" {
  description = "The ID of the AI Search service"
  value       = azapi_resource.ai_search.id
}
