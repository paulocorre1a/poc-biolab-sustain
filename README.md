# POC BIOLAB - Azure Databricks Disaster Recovery

POC corporativa de Disaster Recovery para Azure Databricks com reconstrução automatizada via Azure DevOps Pipeline.

## Objetivo

Provar que é possível destruir e reconstruir do zero uma plataforma Azure Databricks funcional, incluindo infraestrutura Azure, Azure Databricks Workspace, Storage Account, containers RAW/BRONZE/SILVER/GOLD, notebooks, jobs, job cluster efêmero, processamento de dados e evidências de restore.

## Foundation permanente

Recursos que NAO devem ser apagados:

- Resource Group: poc-biolab-sustain
- Storage Account tfstate: stpocbiolabtfstate001
- Container: tfstate
- Azure DevOps Pipeline
- GitHub Repository

## Workload recuperável

Recursos que podem ser apagados e recriados:

- Resource Group: rg-poc-biolab-dr-dev
- Managed Resource Group Databricks: rg-poc-biolab-dr-dev-dbw-managed
- Azure Databricks Workspace: dbw-poc-biolab-dr-dev
- Storage Account: stpocbiolabdrdev001
- Containers: raw, bronze, silver, gold, artifacts, evidence, logs

## Estratégia técnica

Terraform cria Resource Group, Storage Account, Containers e Azure Databricks Workspace.

PowerShell com Databricks REST API restaura Notebook, Job, Job Cluster efêmero, execução do Job e evidência JSON.

## Sobre o Compute

A POC nao mantém All-purpose Compute permanente.

O Job usa Job Cluster efêmero. Ele é criado automaticamente durante a execução do Job, executa o notebook e é encerrado automaticamente.

Por isso a tela Compute pode ficar vazia após a execução. Isso é esperado.

## Fluxo de dados

O notebook executa o fluxo:

RAW -> BRONZE -> SILVER -> GOLD

Entradas:

- raw/customers/customers.csv
- raw/sales/sales.csv

Saídas:

- bronze/customers
- bronze/sales
- silver/sales_customer
- gold/customer_revenue
- gold/state_revenue

## Pipeline

Arquivo:

.azuredevops/azure-pipelines.yml

Stages:

1. Validate Terraform and Scripts
2. Deploy Azure Infrastructure
3. Restore Databricks Artifacts
4. Publish DR Evidence

## Evidência esperada

Artifact final:

databricks-dr-evidence-final/databricks-restore-evidence.json

Campos esperados:

- restore_status = SUCCESS
- run_life_cycle_state = TERMINATED
- run_result_state = SUCCESS

## Teste completo de DR

1. Destruir workload recuperável:

terraform destroy -var-file="dev.tfvars"

2. Validar que o workload foi apagado:

az group show --name rg-poc-biolab-dr-dev -o table
az group show --name rg-poc-biolab-dr-dev-dbw-managed -o table

3. Validar que a foundation continua:

az group show --name poc-biolab-sustain -o table

az storage account show --name stpocbiolabtfstate001 --resource-group poc-biolab-sustain -o table

4. Reexecutar o pipeline no Azure DevOps:

Pipelines -> Run pipeline

5. Validar resultado:

- Pipeline verde
- Artifact final publicado
- JSON com restore_status = SUCCESS
- Storage com containers RAW/BRONZE/SILVER/GOLD
- Job Databricks com último run SUCCESS
- All-purpose Compute vazio

## Resultado final

Esta POC prova reconstrução automatizada do Azure Databricks, separação entre foundation e workload recuperável, Terraform remoto com backend resiliente, pipeline one-click deploy and restore, execução real de dados com Spark, arquitetura Medallion básica e evidência auditável do restore.
