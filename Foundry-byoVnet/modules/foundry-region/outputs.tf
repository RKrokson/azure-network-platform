output "foundry_region" {
  description = "Regional Foundry contract entry published in the root foundry_regions output"
  value = {
    region_name            = var.platform.region_name
    region_abbr            = var.platform.region_abbr
    resource_group_id      = azurerm_resource_group.rg-ai00.id
    foundry_id             = azapi_resource.foundry.id
    foundry_endpoint       = azapi_resource.foundry.output.properties.endpoint
    project_id             = azapi_resource.foundry_project.id
    model_deployment_names = [azurerm_cognitive_deployment.aifoundry_deployment_gpt_4o.name]
    storage_account_id     = one(azurerm_storage_account.storage_account[*].id)
    cosmosdb_account_id    = one(azurerm_cosmosdb_account.cosmosdb[*].id)
    ai_search_id           = one(azapi_resource.ai_search[*].id)
  }
}
