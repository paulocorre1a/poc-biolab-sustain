# BIOLAB - Azure Databricks Disaster Recovery POC

## Objetivo

POC corporativa para provar que um Azure Databricks Workspace pode ser destruído e recriado automaticamente, incluindo infraestrutura Azure, cluster, notebook, job e evidências de restore.

## Princípio da arquitetura

Separação obrigatória:

1. **Foundation permanente**: Resource Group, Storage Account e container do Terraform remote state.
2. **Workload recuperável**: Resource Group da POC, Storage Account de artefatos, containers, Azure Databricks Workspace, cluster, notebook e job.
3. **Artefatos versionados**: notebooks, Terraform, scripts PowerShell e pipeline YAML ficam no GitHub/Azure Repos.
4. **Restore automatizado**: Azure DevOps executa Terraform e recria tudo do zero.
5. **Evidências**: JSON publicado no Azure Storage e como artifact do pipeline.

## O que NÃO fazer

- Não importar recursos manualmente no state.
- Não misturar backend permanente com workload destruível.
- Não executar `terraform apply` duas vezes no mesmo stage sem necessidade.
- Não criar workspace pelo Portal e depois tentar controlar via Terraform.
- Não usar extensão `az databricks` como mecanismo principal de restore.

## Estrutura

```text
.azuredevops/azure-pipelines.yml
scripts/Bootstrap-TerraformBackend.ps1
scripts/Invoke-Terraform.ps1
scripts/Publish-DrEvidence.ps1
terraform/10-dr-workload/
  versions.tf
  providers.tf
  variables.tf
  main.tf
  outputs.tf
  backend-dev.hcl
  dev.tfvars
notebooks/DR_Validation.py
evidence/.gitkeep
```

## Pré-requisitos

- Azure DevOps Service Connection chamada `SC-AZURE-BIOLAB-WIF`.
- Preferência: Workload Identity Federation, sem secret fixo.
- Permissões mínimas no escopo da subscription ou RGs da POC:
  - Contributor
  - Storage Blob Data Contributor no Storage do tfstate
- Azure CLI disponível no agente.
- Terraform instalado pelo pipeline.

## Execução local

```powershell
az login --tenant c91d481c-40b4-4ff9-8f2e-a00df534d8b7
az account set --subscription 4ae6462d-bd8b-4156-a6e4-871ca4c32dd8

./scripts/Bootstrap-TerraformBackend.ps1 `
  -SubscriptionId 4ae6462d-bd8b-4156-a6e4-871ca4c32dd8 `
  -TenantId c91d481c-40b4-4ff9-8f2e-a00df534d8b7 `
  -Location eastus

./scripts/Invoke-Terraform.ps1 -Action plan -AutoApprove
./scripts/Invoke-Terraform.ps1 -Action apply -AutoApprove
./scripts/Publish-DrEvidence.ps1
```

## Execução Azure DevOps

1. Crie o Service Connection `SC-AZURE-BIOLAB-WIF`.
2. Garanta RBAC para o identity usado pelo pipeline.
3. Crie um pipeline apontando para `.azuredevops/azure-pipelines.yml`.
4. Execute com `action=apply`.
5. Para testar DR, execute `action=destroy` e depois `action=apply` novamente.

## Estratégia de ambientes

Para QA/PRD, duplicar os arquivos `.tfvars` e backend:

- `qa.tfvars` + `backend-qa.hcl`
- `prd.tfvars` + `backend-prd.hcl`

Cada ambiente deve ter uma key distinta no tfstate:

```hcl
key = "databricks-dr/dev/terraform.tfstate"
key = "databricks-dr/qa/terraform.tfstate"
key = "databricks-dr/prd/terraform.tfstate"
```

## Reexecução segura

O pipeline é idempotente porque:

- O state remoto é único por ambiente.
- O backend fica fora do destroy.
- O Terraform controla a criação do workspace e dos objetos Databricks.
- Outputs são gerados somente após apply.
- Evidências são publicadas com timestamp.

## Rollback

Rollback nesta POC significa retornar para a última versão conhecida do Git:

1. Reverter commit do Terraform/notebook/job.
2. Executar pipeline `plan`.
3. Validar mudanças.
4. Executar `apply`.

Para restore total:

1. Executar `destroy` no workload.
2. Executar `apply`.
3. Validar evidência publicada.
