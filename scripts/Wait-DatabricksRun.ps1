[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$WorkspaceName,

    [Parameter(Mandatory = $true)]
    [string]$EvidencePath
)

$ErrorActionPreference = "Stop"

$evidence = Get-Content $EvidencePath -Raw | ConvertFrom-Json

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
}

$runId = $evidence.run_id

Write-Host "Monitoring Databricks run_id: $runId"

for ($i = 1; $i -le 60; $i++) {
    $run = Invoke-RestMethod `
        -Method Get `
        -Uri "$workspaceUrl/api/2.1/jobs/runs/get?run_id=$runId" `
        -Headers $headers

    $lifeCycleState = $run.state.life_cycle_state
    $resultState    = $run.state.result_state
    $stateMessage   = $run.state.state_message

    Write-Host "Attempt $i - lifecycle=$lifeCycleState result=$resultState message=$stateMessage"

    if ($lifeCycleState -in @("TERMINATED", "SKIPPED", "INTERNAL_ERROR")) {
        $evidence | Add-Member -NotePropertyName "run_life_cycle_state" -NotePropertyValue $lifeCycleState -Force
        $evidence | Add-Member -NotePropertyName "run_result_state" -NotePropertyValue $resultState -Force
        $evidence | Add-Member -NotePropertyName "run_state_message" -NotePropertyValue $stateMessage -Force
        $evidence | Add-Member -NotePropertyName "run_page_url" -NotePropertyValue $run.run_page_url -Force
        $evidence | Add-Member -NotePropertyName "validated_at_utc" -NotePropertyValue (Get-Date).ToUniversalTime().ToString("o") -Force

        if ($resultState -eq "SUCCESS") {
            $evidence.restore_status = "SUCCESS"
        }
        else {
            $evidence.restore_status = "FAILED"
        }

        $evidence |
            ConvertTo-Json -Depth 20 |
            Set-Content -Path $EvidencePath -Encoding UTF8

        if ($resultState -ne "SUCCESS") {
            throw "Databricks job finished without SUCCESS. Result: $resultState"
        }

        Write-Host "Databricks job completed successfully."
        Write-Host "Evidence updated: $EvidencePath"
        exit 0
    }

    Start-Sleep -Seconds 20
}

throw "Timeout waiting for Databricks job run to finish."
