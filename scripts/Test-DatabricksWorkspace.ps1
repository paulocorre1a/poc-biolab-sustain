[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$WorkspaceName
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================"
Write-Host "BIOLAB - Databricks Workspace Diagnostic"
Write-Host "============================================================"

az account set --subscription $SubscriptionId

$workspace = az databricks workspace show `
    --resource-group $ResourceGroupName `
    --name $WorkspaceName `
    -o json | ConvertFrom-Json

$workspaceUrl = "https://$($workspace.workspaceUrl)"
$workspaceId  = $workspace.workspaceId
$resourceId   = $workspace.id

Write-Host "Workspace Name : $WorkspaceName"
Write-Host "Workspace URL  : $workspaceUrl"
Write-Host "Workspace ID   : $workspaceId"
Write-Host "Resource ID    : $resourceId"

Write-Host ""
Write-Host "Getting Azure Databricks access token via Azure CLI..."

$token = az account get-access-token `
    --resource "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d" `
    --query accessToken `
    -o tsv

if ([string]::IsNullOrWhiteSpace($token)) {
    throw "Failed to obtain Azure Databricks access token."
}

Write-Host "Token obtained successfully."

Write-Host ""
Write-Host "Calling Databricks API: /api/2.0/clusters/spark-versions"

$headers = @{
    Authorization = "Bearer $token"
}

$response = Invoke-RestMethod `
    -Method Get `
    -Uri "$workspaceUrl/api/2.0/clusters/spark-versions" `
    -Headers $headers

if (-not $response.versions) {
    throw "Databricks API responded, but no Spark versions were returned."
}

Write-Host "Databricks API authentication succeeded."
Write-Host ""
Write-Host "First available Spark versions:"
$response.versions |
    Select-Object -First 5 |
    ForEach-Object {
        Write-Host "- $($_.key) | $($_.name)"
    }

Write-Host ""
Write-Host "============================================================"
Write-Host "Diagnostic completed successfully."
Write-Host "============================================================"
