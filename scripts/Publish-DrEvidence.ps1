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

$storageKey = az storage account keys list `
    --resource-group $ResourceGroupName `
    --account-name $StorageAccountName `
    --query "[0].value" `
    -o tsv

if ([string]::IsNullOrWhiteSpace($storageKey)) {
    throw "Failed to retrieve storage account key."
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$blobName = "databricks-dr/$timestamp/databricks-restore-evidence.json"

Write-Host "Uploading evidence to storage..."
Write-Host "Storage Account : $StorageAccountName"
Write-Host "Container       : $ContainerName"
Write-Host "Blob            : $blobName"

az storage blob upload `
    --account-name $StorageAccountName `
    --account-key $storageKey `
    --container-name $ContainerName `
    --name $blobName `
    --file $EvidencePath `
    --overwrite true

if ($LASTEXITCODE -ne 0) {
    throw "Evidence upload failed."
}

Write-Host "Evidence uploaded successfully."
Write-Host "Blob path: $blobName"
