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
    [string]$EvidenceDirectory = ".\evidence"
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

    $headers = @{
        Authorization = "Bearer $script:DatabricksToken"
    }

    if ($Method -eq "GET") {
        return Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
    }

    $jsonBody = $Body | ConvertTo-Json -Depth 20

    return Invoke-RestMethod `
        -Method Post `
        -Uri $uri `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $jsonBody
}

Write-Host "============================================================"
Write-Host "BIOLAB - Databricks Restore"
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

Write-Host "Token acquired successfully."

if (-not (Test-Path $NotebookLocalPath)) {
    throw "Notebook file not found: $NotebookLocalPath"
}

if (-not (Test-Path $EvidenceDirectory)) {
    New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
}

Write-Host "Ensuring workspace directory exists: /Shared/biolab"

Invoke-DatabricksApi `
    -Method POST `
    -Path "/api/2.0/workspace/mkdirs" `
    -Body @{
        path = "/Shared/biolab"
    } | Out-Null

Write-Host "Importing notebook: $NotebookWorkspacePath"

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

Write-Host "Checking existing clusters..."

$clustersResponse = Invoke-DatabricksApi `
    -Method GET `
    -Path "/api/2.0/clusters/list"

$existingCluster = $null

if ($clustersResponse.clusters) {
    $existingCluster = $clustersResponse.clusters | Where-Object { $_.cluster_name -eq $ClusterName } | Select-Object -First 1
}

if ($existingCluster) {
    $clusterId = $existingCluster.cluster_id
    Write-Host "Cluster already exists: $ClusterName ($clusterId)"
}
else {
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
            custom_tags = @{
                project     = "biolab"
                environment = "dev"
                purpose     = "databricks-dr-poc"
                managed_by  = "powershell"
            }
        }

    $clusterId = $clusterCreateResponse.cluster_id
    Write-Host "Cluster created: $clusterId"
}

Write-Host "Creating Databricks job: $JobName"

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
        purpose     = "databricks-dr-poc"
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
    Write-Host "Job already exists: $JobName ($jobId). Resetting definition."

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
    Write-Host "Job created: $jobId"
}

Write-Host "Running job now..."

$runNowResponse = Invoke-DatabricksApi `
    -Method POST `
    -Path "/api/2.1/jobs/run-now" `
    -Body @{
        job_id = $jobId
    }

$runId = $runNowResponse.run_id

Write-Host "Job submitted. Run ID: $runId"

$evidence = [ordered]@{
    generated_at_utc        = (Get-Date).ToUniversalTime().ToString("o")
    subscription_id         = $SubscriptionId
    resource_group_name     = $ResourceGroupName
    workspace_name          = $WorkspaceName
    workspace_url           = $script:WorkspaceUrl
    workspace_id            = $WorkspaceId
    workspace_resource_id   = $WorkspaceResourceId
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

Write-Host "Evidence generated: $evidencePath"

Write-Host "============================================================"
Write-Host "Databricks restore submitted successfully."
Write-Host "============================================================"
Write-Host "Cluster ID: $clusterId"
Write-Host "Job ID    : $jobId"
Write-Host "Run ID    : $runId"
Write-Host "Evidence  : $evidencePath"
Write-Host "============================================================"
