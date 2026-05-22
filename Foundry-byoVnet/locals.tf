locals {
  common_tags = {
    environment = "non-prod"
    managed_by  = "terraform"
    project     = "azure-infra-poc"
  }

  project_id_guid = "${substr(azapi_resource.foundry_project.output.properties.internalId, 0, 8)}-${substr(azapi_resource.foundry_project.output.properties.internalId, 8, 4)}-${substr(azapi_resource.foundry_project.output.properties.internalId, 12, 4)}-${substr(azapi_resource.foundry_project.output.properties.internalId, 16, 4)}-${substr(azapi_resource.foundry_project.output.properties.internalId, 20, 12)}"
}