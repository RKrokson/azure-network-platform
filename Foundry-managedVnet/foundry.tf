########## Create Foundry resource
##########

## Create the Foundry resource
##
resource "azapi_resource" "foundry" {
  type      = "Microsoft.CognitiveServices/accounts@2026-03-01"
  name      = "foundry${random_string.unique.result}"
  parent_id = azurerm_resource_group.rg-ai01.id
  location  = azurerm_resource_group.rg-ai01.location

  schema_validation_enabled = false
  tags                      = local.common_tags

  response_export_values = [
    "identity.principalId"
  ]

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices",
    sku = {
      name = var.foundry_sku
    }
    properties = {

      # Support Entra ID and disable API Key authentication for underlining Cognitive Services account
      disableLocalAuth       = true
      apiProperties          = {}
      allowProjectManagement = true
      customSubDomainName    = "foundry${random_string.unique.result}"
      # Network-related controls
      # Disable public access but allow Trusted Azure Services exception
      publicNetworkAccess = "Disabled"
      networkAcls = {
        defaultAction       = "Deny"
        virtualNetworkRules = []
        ipRules             = []
      }

      # Enable VNet injection for Standard Agents
      networkInjections = [
        {
          scenario                   = "agent"
          subnetArmId                = ""
          useMicrosoftManagedNetwork = true
        }
      ]
      userOwnedStorage = [
        {
          resourceId = azurerm_storage_account.storage_account.id
        }
      ]
      userOwnedCosmosDB = [
        {
          resourceId = azurerm_cosmosdb_account.cosmosdb.id
        }
      ]
      userOwnedSearch = [
        {
          resourceId = azapi_resource.ai_search.id
        }
      ]
    }
  }

  lifecycle {
    ignore_changes = [
      body["properties"]["restore"],
    ]
  }

  depends_on = [
    azurerm_storage_account.storage_account,
    azurerm_cosmosdb_account.cosmosdb,
    azapi_resource.ai_search
  ]
}

# Create Private Endpoints for foundry

resource "azurerm_private_endpoint" "pe-foundry" {
  depends_on = [
    azurerm_private_endpoint.pe-aisearch
  ]

  name                = "${azapi_resource.foundry.name}-private-endpoint"
  resource_group_name = azurerm_resource_group.rg-ai01.name
  location            = azurerm_resource_group.rg-ai01.location
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${azapi_resource.foundry.name}-private-link-service-connection"
    private_connection_resource_id = azapi_resource.foundry.id
    subresource_names = [
      "account"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azapi_resource.foundry.name}-dns-config"
    private_dns_zone_ids = [
      data.terraform_remote_state.networking.outputs.dns_zone_cognitiveservices_id,
      data.terraform_remote_state.networking.outputs.dns_zone_services_ai_id,
      data.terraform_remote_state.networking.outputs.dns_zone_openai_id
    ]
  }
}

## Create a deployment for OpenAI's GPT-5.4 (2026-03-05) in the Foundry resource
##
resource "azurerm_cognitive_deployment" "foundry_deployment_gpt_4o" {
  name                 = var.gpt_model_deployment_name
  cognitive_account_id = azapi_resource.foundry.id

  sku {
    name     = var.gpt_model_sku_name
    capacity = var.gpt_model_capacity
  }

  model {
    format  = "OpenAI"
    name    = var.gpt_model_name
    version = var.gpt_model_version
  }
}

########## Managed Network Configuration
##########

# Managed Network Configuration

# Allow Internet Outbound is the default managed VNet mode and does not use these resources.
# This readiness gate is created only when Allow Only Approved Outbound is enabled.
# When the account is created with networkInjections[].useMicrosoftManagedNetwork = true,
# the platform provisions managedNetworks/default and the userOwned-resource PE outbound
# rules automatically (Terraform does not declare or own them). This polls that GET until
# provisioningState = Succeeded AND all auto-created PE rules are Active, so the capability
# host can safely depend on it.
# NOTE: accounts/managedNetworks is a preview-only child type (no GA api-version), so this
# read pins the latest preview (2026-03-15-preview) even though the account itself uses GA
# 2026-03-01.
# NOTE: uses PowerShell + az CLI; intended for Windows. On Linux/macOS, swap the
# interpreter to ["/bin/bash","-c"] and port the script.
resource "terraform_data" "managed_network_ready" {
  count = var.foundry_mvnet_fw_aoao ? 1 : 0

  triggers_replace = [azapi_resource.foundry.id]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = "Stop"
      $uri = "https://management.azure.com${azapi_resource.foundry.id}/managedNetworks/default?api-version=2026-03-15-preview"
      $expected = 3
      $deadline = (Get-Date).AddMinutes(30)
      while ($true) {
        $state = "Pending"
        $activeCount = 0
        try {
          $resp = az rest --method get --url $uri 2>&1 | ConvertFrom-Json
          $state = $resp.properties.provisioningState
          $rules = $resp.properties.managedNetwork.outboundRules
          if ($rules) {
            $names = @($rules.PSObject.Properties.Name)
            $activeCount = @($names | Where-Object { $rules.$_.status -eq 'Active' }).Count
          }
        } catch {
          $state = "Pending"
          Write-Host "managedNetworks/default: query failed: $($_.Exception.Message)"
        }
        Write-Host "managedNetworks/default: provisioningState=$state activePErules=$activeCount/$expected"
        if ($state -eq "Succeeded" -and $activeCount -ge $expected) { break }
        if ((Get-Date) -gt $deadline) { throw "Timed out waiting for managed network (state=$state activePErules=$activeCount/$expected)" }
        Start-Sleep -Seconds 15
      }
      Write-Host "Managed network ready."
    EOT
  }

  depends_on = [
    azapi_resource.foundry,
    azurerm_role_assignment.foundry_network_connection_approver
  ]
}

resource "terraform_data" "managed_network_isolation" {
  count = var.foundry_mvnet_fw_aoao ? 1 : 0

  triggers_replace = [azapi_resource.foundry.id]

  input = {
    cognitive_account_id = azapi_resource.foundry.id
    isolation_mode       = "AllowOnlyApprovedOutbound"
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = "Stop"
      $uri = "https://management.azure.com${azapi_resource.foundry.id}/managedNetworks/default?api-version=2026-03-15-preview"
      $bodyPath = Join-Path $env:TEMP "foundry-managed-network-isolation-${random_string.unique.result}.json"

      @'
      {
        "properties": {
          "managedNetwork": {
            "isolationMode": "AllowOnlyApprovedOutbound",
            "firewallSku": "Standard",
            "managedNetworkKind": "V2"
          }
        }
      }
      '@ | Set-Content -Path $bodyPath -Encoding utf8

      try {
        az rest --method patch --url $uri --body "@$bodyPath" --headers "Content-Type=application/json" --output json
      } catch {
        Write-Host "PATCH returned an error; checking read-back state. $($_.Exception.Message)"
      } finally {
        Remove-Item $bodyPath -Force -ErrorAction SilentlyContinue
      }

      $resp = az rest --method get --url $uri --output json | ConvertFrom-Json
      $mode = $resp.properties.managedNetwork.isolationMode
      if ($mode -ne "AllowOnlyApprovedOutbound") {
        throw "Managed network isolation mode is '$mode', expected AllowOnlyApprovedOutbound."
      }
      Write-Host "Managed network isolation mode is $mode."
    EOT
  }

  depends_on = [
    azapi_resource.foundry,
    azurerm_role_assignment.foundry_network_connection_approver,
    terraform_data.managed_network_ready
  ]
}

resource "azapi_resource" "foundry_fqdn_outbound_rules" {
  count = var.foundry_mvnet_fw_aoao ? length(local.foundry_mvnet_fqdn_outbound_rules) : 0

  type      = "Microsoft.CognitiveServices/accounts/managedNetworks/outboundRules@2026-03-15-preview"
  name      = local.foundry_mvnet_fqdn_outbound_rules[count.index].name
  parent_id = "${azapi_resource.foundry.id}/managedNetworks/default"

  schema_validation_enabled = false

  body = {
    properties = {
      type        = "FQDN"
      destination = local.foundry_mvnet_fqdn_outbound_rules[count.index].destination
      category    = "UserDefined"
    }
  }

  depends_on = [
    azapi_resource.foundry,
    azurerm_role_assignment.foundry_network_connection_approver,
    terraform_data.managed_network_isolation
  ]
}

resource "azapi_resource" "foundry_service_tag_outbound_rules" {
  count = var.foundry_mvnet_fw_aoao ? length(local.foundry_mvnet_service_tag_outbound_rules) : 0

  type      = "Microsoft.CognitiveServices/accounts/managedNetworks/outboundRules@2026-03-15-preview"
  name      = local.foundry_mvnet_service_tag_outbound_rules[count.index].name
  parent_id = "${azapi_resource.foundry.id}/managedNetworks/default"

  schema_validation_enabled = false

  body = {
    properties = {
      type = "ServiceTag"
      destination = {
        serviceTag = local.foundry_mvnet_service_tag_outbound_rules[count.index].service_tag
        protocol   = "TCP"
        portRanges = "443"
      }
      category = "UserDefined"
    }
  }

  depends_on = [
    azapi_resource.foundry,
    azurerm_role_assignment.foundry_network_connection_approver,
    terraform_data.managed_network_isolation
  ]
}