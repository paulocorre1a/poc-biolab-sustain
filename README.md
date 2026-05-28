# POC BIOLAB - Azure Databricks Disaster Recovery

POC corporativa de Disaster Recovery para Azure Databricks com reconstrução automatizada via Azure DevOps Pipeline.

## Objetivo

Provar que é possível destruir e reconstruir do zero uma plataforma Azure Databricks funcional, incluindo infraestrutura Azure, Storage, Databricks Workspace, notebooks, jobs, processamento de dados e evidências de restore.

## Arquitetura geral

``mermaid
flowchart TD
    A[GitHub Repository] --> B[Azure DevOps Pipeline]
    B --> C[Terraform Backend]
    C --> D[Azure Infra]
    D --> E[Azure Databricks Workspace]
    D --> F[Storage Account Data Lake]
    E --> G[Databricks Job]
    G --> H[Job Cluster Efemero]
    H --> I[Notebook DR Validation]
    I --> J[RAW -> BRONZE -> SILVER -> GOLD]
    J --> K[Evidencia JSON]
    K --> L[Azure Storage Evidence]
    K --> M[Pipeline Artifact]
``

## Foundation permanente

Recursos que NAO devem ser apagados:

- Resource Group: poc-biolab-sustain
- Storage Account tfstate: stpocbiolabtfstate001
- Container: tfstate
- Azure DevOps Pipeline
- GitHub Repository

## Workload recuperavel

Recursos que podem ser apagados e recriados:

- Resource Group: rg-poc-biolab-dr-dev
- Managed Resource Group Databricks: rg-poc-biolab-dr-dev-dbw-managed
- Azure Databricks Workspace: dbw-poc-biolab-dr-dev
- Storage Account: stpocbiolabdrdev001
- Containers: raw, bronze, silver, gold, artifacts, evidence, logs

## Estrategia tecnica

- Terraform cria Resource Group, Storage Account, Containers e Azure Databricks Workspace.
- PowerShell com Databricks REST API restaura Notebook, Job, Job Cluster efemero, execucao do Job e evidencia JSON.

``mermaid
flowchart TD
    A[Terraform] --> B[Resource Group]
    A --> C[Storage Account]
    A --> D[Containers]
    A --> E[Databricks Workspace]
    F[PowerShell + Databricks REST API] --> G[Upload RAW Data]
    F --> H[Import Notebook]
    F --> I[Create Job]
    F --> J[Run Job Cluster Efemero]
    F --> K[Generate Evidence]
``

## Sobre o Compute

A POC nao mantem All-purpose Compute permanente.

O Job usa Job Cluster efemero. Ele nasce automaticamente durante a execucao do Job, executa o notebook e e encerrado automaticamente.

Por isso a tela Compute pode ficar vazia apos a execucao. Isso e esperado.

## Fluxo de dados

``mermaid
flowchart LR
    A[RAW CSV] --> B[BRONZE Delta]
    B --> C[SILVER Delta]
    C --> D[GOLD Delta]
``

Entradas:

- raw/customers/customers.csv
- raw/sales/sales.csv

Saidas:

- bronze/customers
- bronze/sales
- silver/sales_customer
- gold/customer_revenue
- gold/state_revenue

## Pipeline

Arquivo: .azuredevops/azure-pipelines.yml

``mermaid
flowchart TD
    A[Validate Terraform and Scripts] --> B[Deploy Azure Infrastructure]
    B --> C[Restore Databricks Artifacts]
    C --> D[Publish DR Evidence]
``

Stages:

1. Validate Terraform and Scripts
2. Deploy Azure Infrastructure
3. Restore Databricks Artifacts
4. Publish DR Evidence

## Evidencia esperada

Artifact final:

- databricks-dr-evidence-final/databricks-restore-evidence.json

Campos esperados:

- restore_status = SUCCESS
- run_life_cycle_state = TERMINATED
- run_result_state = SUCCESS

## Teste completo de DR

``mermaid
sequenceDiagram
    participant User
    participant Terraform
    participant Azure
    participant Pipeline
    participant Databricks
    participant Storage
    User->>Terraform: terraform destroy
    Terraform->>Azure: remove workload recuperavel
    User->>Pipeline: Run pipeline
    Pipeline->>Terraform: terraform apply
    Terraform->>Azure: recria infra
    Pipeline->>Databricks: restaura notebook e job
    Databricks->>Storage: le RAW
    Databricks->>Storage: grava BRONZE/SILVER/GOLD
    Pipeline->>Storage: publica evidencia
``

### 1. Destruir workload recuperavel

Comando:

cd C:\Projetos\poc_biolab\terraform\10-dr-workload
terraform destroy -var-file="dev.tfvars"

Confirmar com: yes

### 2. Validar que o workload foi apagado

az group show --name rg-poc-biolab-dr-dev -o table
az group show --name rg-poc-biolab-dr-dev-dbw-managed -o table

O esperado e que ambos nao existam.

### 3. Validar que a foundation continua

az group show --name poc-biolab-sustain -o table
az storage account show --name stpocbiolabtfstate001 --resource-group poc-biolab-sustain -o table

### 4. Reexecutar o pipeline

No Azure DevOps: Pipelines -> Run pipeline

### 5. Validar resultado

- Pipeline verde
- Artifact final publicado
- JSON com restore_status = SUCCESS
- Storage com containers RAW/BRONZE/SILVER/GOLD
- Job Databricks com ultimo run SUCCESS
- All-purpose Compute vazio

## Resultado final

Esta POC prova reconstrucao automatizada do Azure Databricks, separacao entre foundation e workload recuperavel, Terraform remoto com backend resiliente, pipeline one-click deploy and restore, execucao real de dados com Spark, arquitetura Medallion basica e evidencia auditavel do restore.
