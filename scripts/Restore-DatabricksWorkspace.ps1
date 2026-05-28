[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$WorkspaceName,

    [Parameter(Mandatory = $false)]
    [string]$ClusterName = "dbc-poc-biolab-dr-dev",

    [Parameter(Mandatory = $false)]
    [string]$SparkVersion = "12.2.x-scala2.12",

    [Parameter(Mandatory = $false)]
    [string]$NodeTypeId = "Standard_DS3_v2",

    [Parameter(Mandatory = $false)]
    [int]$MinWorkers = 1,

    [Parameter(Mandatory = $false)]
    [int]$MaxWorkers = 2,

    [Parameter(Mandatory = $false)]
    [string]$NotebookLocalPath = ".\notebooks\dr-validation.py",

    [Parameter(Mandatory = $false)]
    [string]$NotebookWorkspacePath = "/Shared/biolab/dr-validation",

    [Parameter(Mandatory = $false)]
    [string]$JobName = "job-poc-biolab-dr-validation",

    [Parameter(Mandatory = $false)]
    [string]$EvidenceDirectory = ".\evidence",

    [Parameter(Mandatory = $false)]
    [string]$DataStorageAccountName = "stpocbiolabdrdev001"
)

$ErrorActionPreference = "Stop"

function Invoke-DatabricksApi {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("GET", "POST")]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [object]$Body
    )

    $uri = "$script:WorkspaceUrl$Path"
    $headers = @{ Authorization = "Bearer $script:DatabricksToken" }

    if ($Method -eq "GET") {
        return Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
    }

    $jsonBody = $Body | ConvertTo-Json -Depth 30

    return Invoke-RestMethod `
        -Method Post `
        -Uri $uri `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $jsonBody
}

Write-Host "============================================================"
Write-Host "BIOLAB - Databricks Restore with Medallion Data Validation"
Write-Host "============================================================"

az account set --subscription $SubscriptionId

$workspace = az databricks workspace show `
    --resource-group $ResourceGroupName `
    --name $WorkspaceName `
    -o json | ConvertFrom-Json

$script:WorkspaceUrl = "https://$($workspace.workspaceUrl)"
$WorkspaceResourceId = $workspace.id
$WorkspaceId = $workspace.workspaceId

Write-Host "Workspace URL: $script:WorkspaceUrl"
Write-Host "Workspace ID : $WorkspaceId"

$script:DatabricksToken = az account get-access-token `
    --resource "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d" `
    --query accessToken `
    -o tsv

if ([string]::IsNullOrWhiteSpace($script:DatabricksToken)) {
    throw "Failed to obtain Databricks token."
}

if (-not (Test-Path $NotebookLocalPath)) {
    throw "Notebook file not found: $NotebookLocalPath"
}

if (-not (Test-Path ".\data\customers.csv")) {
    throw "Sample data file not found: .\data\customers.csv"
}

if (-not (Test-Path ".\data\sales.csv")) {
    throw "Sample data file not found: .\data\sales.csv"
}

if (-not (Test-Path $EvidenceDirectory)) {
    New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
}

Write-Host "Retrieving storage key..."

$storageKey = az storage account keys list `
    --resource-group $ResourceGroupName `
    --account-name $DataStorageAccountName `
    --query "[0].value" `
    -o tsv

if ([string]::IsNullOrWhiteSpace($storageKey)) {
    throw "Failed to retrieve storage account key."
}

Write-Host "Uploading RAW datasets..."

az storage blob upload `
    --account-name $DataStorageAccountName `
    --account-key $storageKey `
    --container-name "raw" `
    --name "customers/customers.csv" `
    --file ".\data\customers.csv" `
    --overwrite true | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Failed to upload customers.csv."
}

az storage blob upload `
    --account-name $DataStorageAccountName `
    --account-key $storageKey `
    --container-name "raw" `
    --name "sales/sales.csv" `
    --file ".\data\sales.csv" `
    --overwrite true | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Failed to upload sales.csv."
}

Write-Host "RAW datasets uploaded successfully."

Invoke-DatabricksApi `
    -Method POST `
    -Path "/api/2.0/workspace/mkdirs" `
    -Body @{ path = "/Shared/biolab" } | Out-Null

$notebookContentBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $NotebookLocalPath))
$notebookBase64 = [System.Convert]::ToBase64String($notebookContentBytes)

Invoke-DatabricksApi `
    -Method POST `
    -Path "/api/2.0/workspace/import" `
    -Body @{
        path      = $NotebookWorkspacePath
        format    = "SOURCE"
        language  = "PYTHON"
        content   = $notebookBase64
        overwrite = $true
    } | Out-Null

Write-Host "Notebook imported successfully."

Write-Host "Waiting for Databricks worker environment..."

$workerReady = $false

for ($attempt = 1; $attempt -le 30; $attempt++) {
    try {
        $nodeTypesResponse = Invoke-DatabricksApi `
            -Method GET `
            -Path "/api/2.0/clusters/list-node-types"

        if ($nodeTypesResponse.node_types -and $nodeTypesResponse.node_types.Count -gt 0) {
            $workerReady = $true
            break
        }
    }
    catch {
        Write-Host "Attempt $attempt - worker environment not ready: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds 30
}

if (-not $workerReady) {
    throw "Databricks worker environment was not ready after waiting."
}

$clustersResponse = Invoke-DatabricksApi `
    -Method GET `
    -Path "/api/2.0/clusters/list"

if ($clustersResponse.clusters) {
    $oldClusters = $clustersResponse.clusters | Where-Object { $_.cluster_name -eq $ClusterName }

    foreach ($oldCluster in $oldClusters) {
        try {
            Write-Host "Deleting old cluster: $($oldCluster.cluster_id)"
            Invoke-DatabricksApi `
                -Method POST `
                -Path "/api/2.0/clusters/delete" `
                -Body @{ cluster_id = $oldCluster.cluster_id } | Out-Null
        }
        catch {
            Write-Host "Ignored cluster delete error: $($_.Exception.Message)"
        }
    }

    Start-Sleep -Seconds 30
}

Write-Host "Creating cluster: $ClusterName"

$clusterCreateResponse = Invoke-DatabricksApi `
    -Method POST `
    -Path "/api/2.0/clusters/create" `
    -Body @{
        cluster_name            = $ClusterName
        spark_version           = $SparkVersion
        node_type_id            = $NodeTypeId
        autotermination_minutes = 30
        autoscale               = @{
            min_workers = $MinWorkers
            max_workers = $MaxWorkers
        }
        spark_conf              = @{
            "fs.azure.account.key.$DataStorageAccountName.dfs.core.windows.net"  = $storageKey
            "fs.azure.account.key.$DataStorageAccountName.blob.core.windows.net" = $storageKey
        }
        custom_tags             = @{
            project     = "biolab"
            environment = "dev"
            purpose     = "databricks-dr-poc-medallion"
            managed_by  = "powershell"
        }
    }

$clusterId = $clusterCreateResponse.cluster_id

$jobPayload = @{
    name = $JobName
    tasks = @(
        @{
            task_key = "dr_validation"
            existing_cluster_id = $clusterId
            notebook_task = @{
                notebook_path = $NotebookWorkspacePath
            }
        }
    )
    tags = @{
        project     = "biolab"
        environment = "dev"
        purpose     = "databricks-dr-poc-medallion"
        managed_by  = "powershell"
    }
}

$existingJobs = Invoke-DatabricksApi `
    -Method GET `
    -Path "/api/2.1/jobs/list?name=$JobName"

$existingJob = $null

if ($existingJobs.jobs) {
    $existingJob = $existingJobs.jobs | Where-Object { $_.settings.name -eq $JobName } | Select-Object -First 1
}

if ($existingJob) {
    $jobId = $existingJob.job_id
    Invoke-DatabricksApi `
        -Method POST `
        -Path "/api/2.1/jobs/reset" `
        -Body @{
            job_id       = $jobId
            new_settings = $jobPayload
        } | Out-Null
}
else {
    $jobCreateResponse = Invoke-DatabricksApi `
        -Method POST `
        -Path "/api/2.1/jobs/create" `
        -Body $jobPayload

    $jobId = $jobCreateResponse.job_id
}

$runNowResponse = Invoke-DatabricksApi `
    -Method POST `
    -Path "/api/2.1/jobs/run-now" `
    -Body @{ job_id = $jobId }

$runId = $runNowResponse.run_id

$evidence = [ordered]@{
    generated_at_utc        = (Get-Date).ToUniversalTime().ToString("o")
    subscription_id         = $SubscriptionId
    resource_group_name     = $ResourceGroupName
    workspace_name          = $WorkspaceName
    workspace_url           = $script:WorkspaceUrl
    workspace_id            = $WorkspaceId
    workspace_resource_id   = $WorkspaceResourceId
    data_storage_account    = $DataStorageAccountName
    raw_customers_path      = "abfss://raw@$DataStorageAccountName.dfs.core.windows.net/customers/customers.csv"
    raw_sales_path          = "abfss://raw@$DataStorageAccountName.dfs.core.windows.net/sales/sales.csv"
    bronze_customers_path   = "abfss://bronze@$DataStorageAccountName.dfs.core.windows.net/customers"
    bronze_sales_path       = "abfss://bronze@$DataStorageAccountName.dfs.core.windows.net/sales"
    silver_output_path      = "abfss://silver@$DataStorageAccountName.dfs.core.windows.net/sales_customer"
    gold_customer_path      = "abfss://gold@$DataStorageAccountName.dfs.core.windows.net/customer_revenue"
    gold_state_path         = "abfss://gold@$DataStorageAccountName.dfs.core.windows.net/state_revenue"
    cluster_name            = $ClusterName
    cluster_id              = $clusterId
    notebook_workspace_path = $NotebookWorkspacePath
    job_name                = $JobName
    job_id                  = $jobId
    run_id                  = $runId
    restore_status          = "SUBMITTED"
}

$evidencePath = Join-Path $EvidenceDirectory "databricks-restore-evidence.json"

$evidence |
    ConvertTo-Json -Depth 20 |
    Set-Content -Path $evidencePath -Encoding UTF8

Write-Host "Databricks restore submitted successfully."
Write-Host "Cluster ID: $clusterId"
Write-Host "Job ID    : $jobId"
Write-Host "Run ID    : $runId"
Write-Host "Evidence  : $evidencePath"
