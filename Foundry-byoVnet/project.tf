########## Create the AI Foundry project, project connections, role assignments, and project-level capability host
##########

## Create AI Foundry project
##
resource "azapi_resource" "foundry_project" {
  depends_on = [
    azurerm_private_endpoint.pe-storage,
    azurerm_private_endpoint.pe-cosmosdb,
    azurerm_private_endpoint.pe-aisearch,
    azurerm_private_endpoint.pe-aifoundry
  ]

  type                      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name                      = "project${random_string.unique.result}"
  parent_id                 = azapi_resource.foundry.id
  location                  = azurerm_resource_group.rg-ai00.location
  schema_validation_enabled = false
  tags                      = local.common_tags

  body = {
    sku = {
      name = var.foundry_sku
    }
    identity = {
      type = "SystemAssigned"
    }

    properties = {
      displayName = "project"
      description = "A project for the AI Foundry account with network secured deployed Agent"
    }
  }

  response_export_values = [
    "identity.principalId",
    "properties.internalId"
  ]
}

# Wait duration from PG-validated reference implementation. Do not reduce without testing.
resource "time_sleep" "wait_project_identities" {
  depends_on = [
    azapi_resource.foundry_project
  ]
  create_duration = "10s"
}

## Create AI Foundry project connections
##
resource "azapi_resource" "conn_cosmosdb" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = azurerm_cosmosdb_account.cosmosdb.name
  parent_id                 = azapi_resource.foundry_project.id
  schema_validation_enabled = false

  body = {
    name = azurerm_cosmosdb_account.cosmosdb.name
    properties = {
      category = "CosmosDB"
      target   = azurerm_cosmosdb_account.cosmosdb.endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_cosmosdb_account.cosmosdb.id
        location   = azurerm_resource_group.rg-ai00.location
      }
    }
  }
}

## Create the AI Foundry project connection to Azure Storage Account
##
resource "azapi_resource" "conn_storage" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = azurerm_storage_account.storage_account.name
  parent_id                 = azapi_resource.foundry_project.id
  schema_validation_enabled = false

  body = {
    name = azurerm_storage_account.storage_account.name
    properties = {
      category = "AzureStorageAccount"
      target   = azurerm_storage_account.storage_account.primary_blob_endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_storage_account.storage_account.id
        location   = azurerm_resource_group.rg-ai00.location
      }
    }
  }

  response_export_values = [
    "identity.principalId"
  ]
}

## Create the AI Foundry project connection to AI Search
##
resource "azapi_resource" "conn_aisearch" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = azapi_resource.ai_search.name
  parent_id                 = azapi_resource.foundry_project.id
  schema_validation_enabled = false

  body = {
    name = azapi_resource.ai_search.name
    properties = {
      category = "CognitiveSearch"
      target   = "https://${azapi_resource.ai_search.name}.search.windows.net"
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ApiVersion = "2025-05-01-preview"
        ResourceId = azapi_resource.ai_search.id
        location   = azurerm_resource_group.rg-ai00.location
      }
    }
  }

  response_export_values = [
    "identity.principalId"
  ]
}

## Create workspace-based Application Insights for Foundry project tracing
##
resource "azurerm_application_insights" "foundry_appinsights" {
  name                = "appinsights-foundry-${random_string.unique.result}"
  location            = azurerm_resource_group.rg-ai00.location
  resource_group_name = azurerm_resource_group.rg-ai00.name
  application_type    = "web"
  workspace_id        = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id
  tags                = local.common_tags
}

## Create project connection to Application Insights
## category = "AppInsights" (not "ApplicationInsights") per ARM schema enum — Carl's v2 spec 2026-05-11
## authType = "ApiKey"; target = resource ID; credentials.key = connection string (via sensitive_body)
##
resource "azapi_resource" "conn_appinsights" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = azurerm_application_insights.foundry_appinsights.name
  parent_id                 = azapi_resource.foundry_project.id
  schema_validation_enabled = false

  body = {
    name = azurerm_application_insights.foundry_appinsights.name
    properties = {
      category      = "AppInsights"
      authType      = "ApiKey"
      target        = azurerm_application_insights.foundry_appinsights.id
      isSharedToAll = false
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_application_insights.foundry_appinsights.id
      }
    }
  }

  sensitive_body = {
    properties = {
      credentials = {
        key = azurerm_application_insights.foundry_appinsights.connection_string
      }
    }
  }
}

# Wait duration from PG-validated reference implementation. Do not reduce without testing.
resource "time_sleep" "wait_rbac" {
  depends_on = [
    azurerm_role_assignment.cosmosdb_operator_foundry_project,
    azurerm_role_assignment.storage_blob_data_contributor_foundry_project,
    azurerm_role_assignment.search_index_data_contributor_foundry_project,
    azurerm_role_assignment.search_service_contributor_foundry_project
  ]
  create_duration = "60s"
}

## Create the AI Foundry project capability host
##
resource "azapi_resource" "foundry_project_capability_host" {
  depends_on = [
    azapi_resource.conn_aisearch,
    azapi_resource.conn_cosmosdb,
    azapi_resource.conn_storage,
    azapi_resource.conn_appinsights,
    time_sleep.wait_rbac
  ]
  type                      = "Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview"
  name                      = "caphostproj"
  parent_id                 = azapi_resource.foundry_project.id
  schema_validation_enabled = false

  body = {
    properties = {
      capabilityHostKind = "Agents"
      vectorStoreConnections = [
        azapi_resource.ai_search.name
      ]
      storageConnections = [
        azurerm_storage_account.storage_account.name
      ]
      threadStorageConnections = [
        azurerm_cosmosdb_account.cosmosdb.name
      ]
    }
  }
}
