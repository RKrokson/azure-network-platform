########## Container App — Three-mode deployment
##########
# Mode "none":        No container app (ACA environment + ACR stay)
# Mode "hello-world": MCR quickstart image (public, no ACR pull needed)
# Mode "mcp-toolbox": MCP Toolkit server built and pushed to private ACR

########## hello-world mode
##########

resource "azurerm_container_app" "hello_world" {
  count                        = var.app_mode == "hello-world" ? 1 : 0
  name                         = "hello-world-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  container_app_environment_id = azurerm_container_app_environment.aca_env.id
  resource_group_name          = azurerm_resource_group.rg_aca00.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = local.common_tags

  template {
    container {
      name   = "quickstart"
      image  = "mcr.microsoft.com/k8se/quickstart:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

########## mcp-toolbox mode
##########

# Build and push MCP Toolbox image to ACR (cloud build — no local Docker needed)
resource "terraform_data" "docker_build" {
  count = var.app_mode == "mcp-toolbox" ? 1 : 0

  triggers_replace = [
    var.app_mode,
    azurerm_container_registry.acr.login_server,
  ]

  provisioner "local-exec" {
    command     = <<-EOT
      $ErrorActionPreference = 'Stop'
      $cloneDir = Join-Path $env:TEMP "mcp-toolbox-$(Get-Random)"
      try {
        Write-Host "Cloning MCP Toolkit repo..."
        git clone --depth 1 https://github.com/AiGhostMod/mcpToolkit $cloneDir
        Write-Host "Building and pushing image via az acr build..."
        az acr build --registry ${azurerm_container_registry.acr.name} --image mcp-toolbox:latest --file "$cloneDir/Dockerfile" $cloneDir
        Write-Host "Build and push complete."
      } finally {
        if (Test-Path $cloneDir) {
          Remove-Item -Recurse -Force $cloneDir
          Write-Host "Cleaned up temp directory."
        }
      }
    EOT
    interpreter = ["pwsh", "-Command"]
  }
}

resource "azurerm_container_app" "mcp_toolbox" {
  count                        = var.app_mode == "mcp-toolbox" ? 1 : 0
  name                         = "mcp-toolbox-${data.terraform_remote_state.networking.outputs.azure_region_0_abbr}-${random_string.unique.result}"
  container_app_environment_id = azurerm_container_app_environment.aca_env.id
  resource_group_name          = azurerm_resource_group.rg_aca00.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = local.common_tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aca_identity.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.aca_identity.id
  }

  template {
    container {
      name   = "mcp-toolbox"
      image  = "${azurerm_container_registry.acr.login_server}/mcp-toolbox:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "MCP_DASHBOARD_ENABLED"
        value = tostring(var.mcp_dashboard_enabled)
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  depends_on = [
    terraform_data.docker_build,
    azurerm_role_assignment.acr_pull,
  ]
}
