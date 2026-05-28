[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$WorkspaceName,

    [Parameter(Mandatory = $true)]
    [string]$ServicePrincipalDisplayName
)

$ErrorActionPreference = "Stop"

az account set --subscription $SubscriptionId

$workspace = az databricks workspace show `
    --resource-group $ResourceGroupName `
    --name $WorkspaceName `
    -o json | ConvertFrom-Json

$workspaceUrl = "https://$($workspace.workspaceUrl)"

$token = az account get-access-token `
    --resource "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d" `
    --query accessToken `
    -o tsv

$headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/scim+json"
}

$sp = az ad sp list `
    --display-name $ServicePrincipalDisplayName `
    --query "[0].{appId:appId,id:id,displayName:displayName}" `
    -o json | ConvertFrom-Json

if (-not $sp.appId) {
    throw "Service Principal not found: $ServicePrincipalDisplayName"
}

Write-Host "Service Principal found:"
Write-Host "DisplayName : $($sp.displayName)"
Write-Host "AppId       : $($sp.appId)"
Write-Host "ObjectId    : $($sp.id)"

$filter = [System.Web.HttpUtility]::UrlEncode("applicationId eq `"$($sp.appId)`"")
$existing = Invoke-RestMethod `
    -Method Get `
    -Uri "$workspaceUrl/api/2.0/preview/scim/v2/ServicePrincipals?filter=$filter" `
    -Headers $headers

if ($existing.Resources -and $existing.Resources.Count -gt 0) {
    $dbxSpId = $existing.Resources[0].id
    Write-Host "Service Principal already exists in Databricks workspace: $dbxSpId"
}
else {
    Write-Host "Creating Service Principal inside Databricks workspace..."

    $body = @{
        schemas       = @("urn:ietf:params:scim:schemas:core:2.0:ServicePrincipal")
        applicationId = $sp.appId
        displayName   = $sp.displayName
        active        = $true
    } | ConvertTo-Json -Depth 10

    $created = Invoke-RestMethod `
        -Method Post `
        -Uri "$workspaceUrl/api/2.0/preview/scim/v2/ServicePrincipals" `
        -Headers $headers `
        -Body $body

    $dbxSpId = $created.id
    Write-Host "Service Principal created in Databricks workspace: $dbxSpId"
}

$groups = Invoke-RestMethod `
    -Method Get `
    -Uri "$workspaceUrl/api/2.0/preview/scim/v2/Groups" `
    -Headers $headers

$adminsGroup = $groups.Resources | Where-Object { $_.displayName -eq "admins" } | Select-Object -First 1

if (-not $adminsGroup) {
    throw "Databricks admins group not found."
}

Write-Host "Adding Service Principal to Databricks admins group..."

$patchBody = @{
    schemas = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
    Operations = @(
        @{
            op    = "add"
            path  = "members"
            value = @(
                @{
                    value = $dbxSpId
                }
            )
        }
    )
} | ConvertTo-Json -Depth 20

Invoke-RestMethod `
    -Method Patch `
    -Uri "$workspaceUrl/api/2.0/preview/scim/v2/Groups/$($adminsGroup.id)" `
    -Headers $headers `
    -Body $patchBody | Out-Null

Write-Host "Service Principal granted Databricks workspace admin."
