########## Workspace Communication Policy — inbound public access toggle
##########
# Fabric does NOT auto-disable public access when a workspace PE is created.
# To enforce private-only inbound, the workspace communicationPolicy must be
# patched via the Fabric data-plane REST API (no ARM/azapi route exists).
#
# Pattern: terraform_data + local-exec PowerShell, gated by a feature flag.
# Drift caveat: if someone flips the policy in the portal, Terraform won't notice.

resource "terraform_data" "workspace_communication_policy" {
  count = local.deploy_inbound ? 1 : 0 # inbound gate — deny-public-access policy only applies when workspace PE is deployed

  triggers_replace = [
    fabric_workspace.workspace.id,
    var.network_mode,
  ]

  input = {
    workspace_id = fabric_workspace.workspace.id
  }

  provisioner "local-exec" {
    interpreter = ["pwsh", "-NoProfile", "-Command"]
    on_failure  = fail
    command     = <<-EOT
      $ErrorActionPreference = 'Stop'
      $token = (az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv)
      if (-not $token) { throw 'Failed to acquire Fabric API access token via az CLI.' }
      $headers = @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }
      $body = '{"inbound":{"publicAccessRules":{"defaultAction":"Deny"}}}'
      # Per Microsoft docs: PUT https://api.fabric.microsoft.com/v1/workspaces/{id}/networking/communicationPolicy
      # Source: https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-set-up#step-8-deny-public-access-to-the-workspace
      $uri = 'https://api.fabric.microsoft.com/v1/workspaces/${self.input.workspace_id}/networking/communicationPolicy'
      Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -Body $body | Out-Null
      Write-Host "Fabric workspace ${self.input.workspace_id} inbound public access set to Deny (private-only via workspace PE)."
      $got = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers
      $actual = $got.inbound.publicAccessRules.defaultAction
      if ($actual -ne 'Deny') {
        throw "Workspace policy verification failed: expected defaultAction=Deny, got '$actual'."
      }
      Write-Host "✅ Verified: workspace ${self.input.workspace_id} inbound defaultAction is Deny."
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    on_failure  = continue
    interpreter = ["pwsh", "-NoProfile", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Continue'
      try {
        $token = (az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv)
        if (-not $token) { Write-Host 'Skipping policy revert — no Fabric API token.'; exit 0 }
        $headers = @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }
        $body = '{"inbound":{"publicAccessRules":{"defaultAction":"Allow"}}}'
        $uri = 'https://api.fabric.microsoft.com/v1/workspaces/${self.input.workspace_id}/networking/communicationPolicy'
        Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -Body $body | Out-Null
        Write-Host "Fabric workspace ${self.input.workspace_id} inbound public access reverted to Allow (best-effort)."
      } catch {
        Write-Host "Best-effort revert of workspace communication policy failed: $($_.Exception.Message)"
      }
    EOT
  }

  depends_on = [
    azurerm_private_endpoint.pe_fabric_workspace,
    # Ensure all Fabric items are created BEFORE deny-public fires.
    # Once the workspace PE is connected, Fabric auto-enforces deny-public access
    # within seconds — MPE and item creation must complete first.
    fabric_lakehouse.lab_lakehouse,
    fabric_workspace_managed_private_endpoint.mpe_storage,
    fabric_workspace_managed_private_endpoint.mpe_sql,
    fabric_workspace_managed_private_endpoint.mpe_keyvault,
  ]
}
