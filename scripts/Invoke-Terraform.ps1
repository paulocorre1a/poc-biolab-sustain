[CmdletBinding()]
param(
    [ValidateSet("plan","apply","destroy")][string]$Action = "plan",
    [string]$WorkingDirectory = "terraform/10-dr-workload",
    [string]$BackendConfig = "backend-dev.hcl",
    [string]$VarFile = "dev.tfvars",
    [string]$PlanFile = "tfplan",
    [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"
Push-Location $WorkingDirectory
try {
    terraform version
    terraform init -reconfigure -backend-config=$BackendConfig
    terraform validate

    if ($Action -eq "plan") {
        terraform plan -var-file=$VarFile -out=$PlanFile
    }
    elseif ($Action -eq "apply") {
        terraform plan -var-file=$VarFile -out=$PlanFile
        terraform apply $(if($AutoApprove){"-auto-approve"}) $PlanFile
        terraform output -json | Out-File -FilePath "terraform-outputs.json" -Encoding utf8
    }
    elseif ($Action -eq "destroy") {
        terraform plan -destroy -var-file=$VarFile -out=$PlanFile
        terraform apply $(if($AutoApprove){"-auto-approve"}) $PlanFile
    }
}
finally {
    Pop-Location
}
