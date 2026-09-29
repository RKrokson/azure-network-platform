locals {
  # Globally unique base name for the Foundry account and its data services
  account_name = "aifoundry${var.platform.region_abbr}${var.name_suffix}"

  # vhub00 for region0, vhub01 for region1
  hub_label = "vhub0${trimprefix(var.region_key, "region")}"

  project_id_guid = "${substr(azapi_resource.foundry_project.output.properties.internalId, 0, 8)}-${substr(azapi_resource.foundry_project.output.properties.internalId, 8, 4)}-${substr(azapi_resource.foundry_project.output.properties.internalId, 12, 4)}-${substr(azapi_resource.foundry_project.output.properties.internalId, 16, 4)}-${substr(azapi_resource.foundry_project.output.properties.internalId, 20, 12)}"
}
