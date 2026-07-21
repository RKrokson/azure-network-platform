locals {
  common_tags = {
    environment = "non-prod"
    managed_by  = "terraform"
    project     = "azure-infra-poc"
  }

  foundry_mvnet_fqdn_outbound_rules = [
    {
      name        = "agents-identity-azure-net"
      destination = "*.identity.azure.net"
    },
    {
      name        = "agents-login-microsoftonline"
      destination = "login.microsoftonline.com"
    },
    {
      name        = "agents-login-msonline-wild"
      destination = "*.login.microsoftonline.com"
    },
    {
      name        = "agents-login-microsoft-wild"
      destination = "*.login.microsoft.com"
    },
    {
      name        = "agents-mcr-microsoft"
      destination = "mcr.microsoft.com"
    },
    {
      name        = "traces-settings-monitor"
      destination = "settings.sdk.monitor.azure.com"
    },
    {
      name        = "traces-livediagnostics"
      destination = "*.livediagnostics.monitor.azure.com"
    },
    {
      name        = "traces-applicationinsights"
      destination = "*.in.applicationinsights.azure.com"
    },
    {
      name        = "finetune-githubusercontent"
      destination = "raw.githubusercontent.com"
    }
  ]

  foundry_mvnet_service_tag_outbound_rules = [
    {
      name        = "agents-aad-servicetag"
      service_tag = "AzureActiveDirectory"
    },
    {
      name        = "traces-azureml-servicetag"
      service_tag = "AzureMachineLearning"
    }
  ]

  project_id_guid = "${substr(azapi_resource.foundry_project.output.properties.internalId, 0, 8)}-${substr(azapi_resource.foundry_project.output.properties.internalId, 8, 4)}-${substr(azapi_resource.foundry_project.output.properties.internalId, 12, 4)}-${substr(azapi_resource.foundry_project.output.properties.internalId, 16, 4)}-${substr(azapi_resource.foundry_project.output.properties.internalId, 20, 12)}"
}