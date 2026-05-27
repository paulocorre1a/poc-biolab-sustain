[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$ContainerName,

    [Parameter(Mandatory = $true)]
    [string]$Location,

    [Parameter(Mandatory = $false)]
    [string]$BackendFilePath = "terraform/10-dr-workload/backend-dev.hcl",

    [Parameter(Mandatory = $false)]
    [string]$StateKey = "databricks-dr/dev/terraform.tfstate"
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================"
Write-Host "BIOLAB - Terraform Backend Bootstrap"
Write-Host "============================================================"
Write-Host "SubscriptionId     : $SubscriptionId"
Write-Host "TenantId           : $TenantId"
Write-Host "ResourceGroupName  : $ResourceGroupName"
Write-Host "StorageAccountName : $StorageAccountName"
Write-Host "ContainerName      : $ContainerName"
Write-Host "Location           : $Location"
Write-Host "BackendFilePath    : $BackendFilePath"
Write-Host "StateKey           : $StateKey"
Write-Host "============================================================"

if ($StorageAccountName.Length -lt 3 -or $StorageAccountName.Length -gt 24) {
    throw "Storage Account name must be between 3 and 24 characters."
}

if ($StorageAccountName -cnotmatch '^[a-z0-9]+$') {
    throw "Storage Account name must contain only lowercase letters and numbers."
}

Write-Host "Setting Azure subscription context..."
az account set --subscription $SubscriptionId

if ($LASTEXITCODE -ne 0) {
    Write-Host "Azure context not available. Running az login..."
    az login --tenant $TenantId | Out-Null
    az account set --subscription $SubscriptionId
}

Write-Host "Validating Azure account context..."
$account = az account show --query "{subscription:id, tenant:tenantId, user:user.name}" -o json | ConvertFrom-Json

if ($account.subscription -ne $SubscriptionId) {
    throw "Current subscription does not match expected subscription."
}

if ($account.tenant -ne $TenantId) {
    throw "Current tenant does not match expected tenant."
}

Write-Host "Azure context validated:"
Write-Host "Subscription: $($account.subscription)"
Write-Host "Tenant      : $($account.tenant)"
Write-Host "User        : $($account.user)"

Write-Host "Checking if Resource Group exists..."
$rgExists = az group exists --name $ResourceGroupName | ConvertFrom-Json

if (-not $rgExists) {
    Write-Host "Creating Resource Group: $ResourceGroupName"
    az group create `
        --name $ResourceGroupName `
        --location $Location `
        --tags `
            project=biolab `
            workload=databricks-dr `
            purpose=tfstate `
            lifecycle=permanent `
            managed_by=bootstrap | Out-Null
}
else {
    Write-Host "Resource Group already exists: $ResourceGroupName"
}

Write-Host "Checking if Storage Account exists..."
$storageExists = az storage account check-name `
    --name $StorageAccountName `
    --query "nameAvailable" `
    -o tsv

$existingStorage = az storage account show `
    --name $StorageAccountName `
    --resource-group $ResourceGroupName `
    --query "name" `
    -o tsv 2>$null

if ([string]::IsNullOrWhiteSpace($existingStorage)) {
    if ($storageExists -ne "true") {
        throw "Storage Account name '$StorageAccountName' is not available and was not found in Resource Group '$ResourceGroupName'."
    }

    Write-Host "Creating Storage Account: $StorageAccountName"

    az storage account create `
        --name $StorageAccountName `
        --resource-group $ResourceGroupName `
        --location $Location `
        --sku Standard_ZRS `
        --kind StorageV2 `
        --min-tls-version TLS1_2 `
        --allow-blob-public-access false `
        --https-only true `
        --tags `
            project=biolab `
            workload=databricks-dr `
            purpose=tfstate `
            lifecycle=permanent `
            managed_by=bootstrap | Out-Null
}
else {
    Write-Host "Storage Account already exists in expected Resource Group: $StorageAccountName"
}

Write-Host "Creating or validating Blob Container: $ContainerName"

az storage container create `
    --name $ContainerName `
    --account-name $StorageAccountName `
    --auth-mode login | Out-Null

$backendDirectory = Split-Path -Path $BackendFilePath -Parent

if (-not [string]::IsNullOrWhiteSpace($backendDirectory)) {
    if (-not (Test-Path $backendDirectory)) {
        Write-Host "Creating backend directory: $backendDirectory"
        New-Item -ItemType Directory -Path $backendDirectory -Force | Out-Null
    }
}

$backendContent = @"
resource_group_name  = "$ResourceGroupName"
storage_account_name = "$StorageAccountName"
container_name       = "$ContainerName"
key                  = "$StateKey"
use_azuread_auth     = true
"@

Write-Host "Writing backend config file: $BackendFilePath"
Set-Content -Path $BackendFilePath -Value $backendContent -Encoding UTF8

Write-Host "============================================================"
Write-Host "Terraform backend bootstrap completed successfully."
Write-Host "============================================================"
Write-Host "Resource Group : $ResourceGroupName"
Write-Host "Storage Account: $StorageAccountName"
Write-Host "Container      : $ContainerName"
Write-Host "Backend File   : $BackendFilePath"
Write-Host "State Key      : $StateKey"
Write-Host "============================================================"