[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$ContainerName,

    [Parameter(Mandatory = $true)]
    [string]$EvidencePath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $EvidencePath)) {
    throw "Evidence file not found: $EvidencePath"
}

az account set --subscription $SubscriptionId

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$blobName = "databricks-dr/$timestamp/databricks-restore-evidence.json"

Write-Host "Uploading evidence to storage..."
Write-Host "Storage Account : $StorageAccountName"
Write-Host "Container       : $ContainerName"
Write-Host "Blob            : $blobName"

az storage blob upload `
    --account-name $StorageAccountName `
    --container-name $ContainerName `
    --name $blobName `
    --file $EvidencePath `
    --auth-mode login `
    --overwrite true | Out-Null

Write-Host "Evidence uploaded successfully."
Write-Host "Blob path: $blobName"
