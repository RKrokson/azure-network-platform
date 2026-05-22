<#
.SYNOPSIS
    Configures Microsoft Fabric tenant-level admin settings required for the Fabric-private module.

.DESCRIPTION
    This script enables the tenant-level Fabric admin settings needed before deploying
    the Fabric-private Terraform module. It uses the Fabric Admin REST API to toggle
    each setting idempotently.

    PREREQUISITES:
    - Caller must have the "Fabric Administrator" role in the tenant with Tenant.ReadWrite.All scope
    - Azure CLI (az) must be installed and authenticated: az login
    - PowerShell 7+ (pwsh)

    SCOPE:
    - One-time per tenant (not per-deploy)
    - Safe to re-run — idempotent (checks current state before updating)

    SETTINGS CONFIGURED (API settingName → portal display name):
    1. FabricGAWorkloads         → "Users can create Fabric items" (the Microsoft Fabric admin switch)
    2. WorkspaceBlockInboundAccess → "Configure workspace-level inbound network rules"
    3. ServicePrincipalAccessGlobalAPIs → "Service principals can call Fabric public APIs"

    NOTE: "Microsoft Fabric" in the admin portal is a section header, not a separate API
    setting. Its only toggle is "Users can create Fabric items" (FabricGAWorkloads above).
    It is NOT exposed as a distinct settingName in the tenant-settings API.

    After toggling setting #2 (WorkspaceBlockInboundAccess), you MUST re-register the
    Microsoft.Fabric provider:
      az provider register --namespace Microsoft.Fabric

    DO NOT run this against a production tenant without understanding the impact.
    This is for lab/POC tenants only.

.NOTES
    Do not enable verbose PowerShell tracing (-Trace) when running this script — it will
    log the bearer token to the console.

    API CONTRACT:
    - Read:   GET  /v1/admin/tenantsettings             (LIST all; no per-setting GET exists)
    - Write:  POST /v1/admin/tenantsettings/{name}/update  (not PATCH, not bare path)
    - Scope:  Tenant.ReadWrite.All; caller must be Fabric Administrator

.EXAMPLE
    ./configure-fabric-tenant-settings.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# ─────────────────────────────────────────────
# Acquire token for Fabric Admin API
# ─────────────────────────────────────────────
Write-Host "Acquiring access token for Fabric Admin API..." -ForegroundColor Cyan
$tokenResponse = az account get-access-token --resource "https://api.fabric.microsoft.com" --query "{accessToken:accessToken}" -o json | ConvertFrom-Json
if (-not $tokenResponse.accessToken) {
    Write-Error "Failed to acquire access token. Ensure you are logged in with 'az login' and have Fabric Administrator role."
    exit 1
}
$headers = @{
    "Authorization" = "Bearer $($tokenResponse.accessToken)"
    "Content-Type"  = "application/json"
}
$baseUrl = "https://api.fabric.microsoft.com/v1"

# ─────────────────────────────────────────────
# Tenant settings to configure
# ─────────────────────────────────────────────
$settings = @(
    # "Microsoft Fabric" in the admin portal is a section header, not its own API setting.
    # Its only toggle — "Users can create Fabric items" — is the entry below (FabricGAWorkloads).
    @{
        Name        = "FabricGAWorkloads"
        DisplayName = "Users can create Fabric items"
        Description = "Enables Fabric GA workloads for the tenant (the Microsoft Fabric admin switch)"
    },
    @{
        Name        = "WorkspaceBlockInboundAccess"
        DisplayName = "Configure workspace-level inbound network rules"
        Description = "Allows workspace admins to restrict inbound public access (required for workspace-level PE)"
    },
    @{
        Name        = "ServicePrincipalAccessGlobalAPIs"
        DisplayName = "Service principals can call Fabric public APIs"
        Description = "Required when Terraform runs as a service principal"
    }
)

# ─────────────────────────────────────────────
# LIST all tenant settings once and cache
# (No per-setting GET endpoint exists in the Fabric Admin API)
# ─────────────────────────────────────────────
$listUrl = "$baseUrl/admin/tenantsettings"
Write-Host "`nFetching all tenant settings from Fabric Admin API..." -ForegroundColor Cyan
try {
    $listResponse = Invoke-RestMethod -Uri $listUrl -Method Get -Headers $headers -ErrorAction Stop
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $responseBody = $_.ErrorDetails.Message
    Write-Error "Failed to list tenant settings.`n  URL: $listUrl`n  HTTP $statusCode`n  Body: $responseBody"
    exit 1
}

# Build a lookup map: settingName -> setting object
$settingMap = @{}
foreach ($s in $listResponse.tenantSettings) {
    $settingMap[$s.settingName] = $s
}
Write-Host "  Found $($settingMap.Count) tenant settings in the API response." -ForegroundColor DarkGray

# ─────────────────────────────────────────────
# Check and enable each setting
# ─────────────────────────────────────────────
$reRegisterRequired = $false

foreach ($setting in $settings) {
    Write-Host "`nChecking: $($setting.DisplayName) ($($setting.Name))..." -ForegroundColor Yellow

    # Validate that the setting name exists in the API response
    if (-not $settingMap.ContainsKey($setting.Name)) {
        $knownNames = ($settingMap.Keys | Sort-Object) -join ", "
        Write-Warning "  Setting '$($setting.Name)' not found in the API response. The name may have changed."
        Write-Warning "  Expected name : $($setting.Name)"
        Write-Warning "  API returned  : $knownNames"
        Write-Warning "  Skipping — configure manually in the Fabric Admin Portal if needed."
        continue
    }

    # Check current state from cached LIST response
    $currentEnabled = $settingMap[$setting.Name].enabled

    if ($currentEnabled -eq $true) {
        Write-Host "  Already configured. Skipping." -ForegroundColor Green
        continue
    }

    # Enable the setting via POST .../update
    Write-Host "  Enabling..." -ForegroundColor Cyan
    $body = @{
        enabled = $true
    } | ConvertTo-Json

    $updateUrl = "$baseUrl/admin/tenantsettings/$($setting.Name)/update"
    try {
        Invoke-RestMethod -Uri $updateUrl -Method Post -Headers $headers -Body $body -ErrorAction Stop
        Write-Host "  Enabled successfully." -ForegroundColor Green

        if ($setting.Name -eq "WorkspaceBlockInboundAccess") {
            $reRegisterRequired = $true
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $responseBody = $_.ErrorDetails.Message
        Write-Warning "  Failed to enable $($setting.DisplayName)."
        Write-Warning "  URL: $updateUrl"
        Write-Warning "  HTTP $statusCode"
        Write-Warning "  Body: $responseBody"
        Write-Warning "  You may need to configure this manually in the Fabric Admin Portal."
        Write-Warning "  Path: Admin portal -> Tenant settings -> $($setting.DisplayName)"
    }
}

# ─────────────────────────────────────────────
# Post-configuration: re-register Fabric provider if needed
# ─────────────────────────────────────────────
if ($reRegisterRequired) {
    Write-Host "`nWorkspace-level inbound network rules was just enabled." -ForegroundColor Yellow
    Write-Host "Re-registering Microsoft.Fabric resource provider (required after this toggle)..." -ForegroundColor Cyan
    az provider register --namespace Microsoft.Fabric
    Write-Host "Provider registration initiated. Check status with:" -ForegroundColor Green
    Write-Host "  az provider show -n Microsoft.Fabric --query registrationState -o tsv" -ForegroundColor White
}

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
Write-Host "`n─────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Tenant configuration complete." -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. If provider re-registration was triggered, wait for 'Registered' state"
Write-Host "  2. cd Fabric-private && terraform init && terraform plan"
Write-Host "─────────────────────────────────────────────" -ForegroundColor Cyan
