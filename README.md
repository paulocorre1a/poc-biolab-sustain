# POC BIOLAB - Azure Databricks Disaster Recovery

POC corporativa para Disaster Recovery de Azure Databricks usando Terraform, PowerShell, Azure CLI, Azure Storage, Azure Databricks, GitHub e Azure DevOps.

## Arquitetura

### Foundation permanente

- Resource Group: poc-biolab-sustain
- Storage Account tfstate: stpocbiolabtfstate001
- Container: tfstate

### Workload recuperável

- Resource Group: rg-poc-biolab-dr-dev
- Azure Databricks Workspace: dbw-poc-biolab-dr-dev
- Storage Account evidências: stpocbiolabdrdev001
- Containers: artifacts, evidence, logs

## Estratégia

Terraform controla a infraestrutura Azure: Resource Group, Storage Account, Containers e Azure Databricks Workspace.

PowerShell + Databricks REST API controlam artefatos operacionais: Cluster, Notebook, Job, execução e evidências.

## Evidência esperada

Arquivo:

evidence/databricks-restore-evidence.json

Resultado esperado:

restore_status = SUCCESS
run_life_cycle_state = TERMINATED
run_result_state = SUCCESS

## Pipeline

Arquivo:

.azuredevops/azure-pipelines.yml

Executa:

1. Terraform init/validate
2. Terraform plan/apply
3. Restore Databricks
4. Wait Job
5. Upload evidência
6. Publish Pipeline Artifact
