# POC BIOLAB - Azure Databricks Disaster Recovery

POC corporativa de Disaster Recovery para Azure Databricks com reconstrução automatizada via Azure DevOps Pipeline.

---

# Objetivo

Provar que é possível destruir e reconstruir do zero uma plataforma Azure Databricks funcional, incluindo:

- Infraestrutura Azure
- Azure Databricks Workspace
- Storage Account
- Containers RAW / BRONZE / SILVER / GOLD
- Notebooks
- Jobs
- Job Cluster efêmero
- Processamento de dados
- Evidências de restore

---

# Arquitetura geral

```mermaid
flowchart TD
    A[GitHub Repository] --> B[Azure DevOps Pipeline]
    B --> C[Terraform Backend]
    C --> D[Azure Infrastructure]
    D --> E[Azure Databricks Workspace]
    D --> F[Azure Storage Data Lake]
    E --> G[Databricks Job]
    G --> H[Job Cluster Efêmero]
    H --> I[Notebook DR Validation]
    I --> J[RAW -> BRONZE -> SILVER -> GOLD]
    J --> K[Evidência JSON]
    K --> L[Azure Storage Evidence]
    K --> M[Pipeline Artifact]
```

---

# Separação de recursos

```mermaid
flowchart LR
    A[Foundation Permanente] --> A1[poc-biolab-sustain]
    A --> A2[stpocbiolabtfstate001]
    A --> A3[tfstate]

    B[Workload Recuperável] --> B1[rg-poc-biolab-dr-dev]
    B --> B2[dbw-poc-biolab-dr-dev]
    B --> B3[stpocbiolabdrdev001]
    B --> B4[rg-poc-biolab-dr-dev-dbw-managed]
```

---

# Foundation permanente

Recursos que NÃO devem ser apagados:

- Resource Group: `poc-biolab-sustain`
- Storage Account tfstate: `stpocbiolabtfstate001`
- Container: `tfstate`
- Azure DevOps Pipeline
- GitHub Repository

---

# Workload recuperável

Recursos que podem ser apagados e recriados:

- Resource Group: `rg-poc-biolab-dr-dev`
- Managed Resource Group Databricks: `rg-poc-biolab-dr-dev-dbw-managed`
- Azure Databricks Workspace: `dbw-poc-biolab-dr-dev`
- Storage Account: `stpocbiolabdrdev001`

Containers:

- `raw`
- `bronze`
- `silver`
- `gold`
- `artifacts`
- `evidence`
- `logs`

---

# Estratégia técnica

```mermaid
flowchart TD
    A[Terraform] --> B[Resource Group]
    A --> C[Storage Account]
    A --> D[Containers]
    A --> E[Databricks Workspace]

    F[PowerShell + Databricks REST API] --> G[Upload RAW Data]
    F --> H[Import Notebook]
    F --> I[Create Job]
    F --> J[Run Job Cluster Efêmero]
    F --> K[Generate Evidence]
```

---

# Sobre o Compute

A POC NÃO mantém All-purpose Compute permanente.

O Job usa Job Cluster efêmero:

- nasce automaticamente durante a execução do Job
- executa o notebook
- é encerrado automaticamente
- não aparece como All-purpose Compute permanente

Por isso a tela Compute pode ficar vazia após a execução. Isso é esperado.

---

# Fluxo Medallion

```mermaid
flowchart LR
    A[RAW CSV] --> B[BRONZE Delta]
    B --> C[SILVER Delta]
    C --> D[GOLD Delta]
```

Entradas:

- `raw/customers/customers.csv`
- `raw/sales/sales.csv`

Saídas:

- `bronze/customers`
- `bronze/sales`
- `silver/sales_customer`
- `gold/customer_revenue`
- `gold/state_revenue`

---

# Pipeline

Arquivo:

```text
.azuredevops/azure-pipelines.yml
```

Stages:

1. Validate Terraform and Scripts
2. Deploy Azure Infrastructure
3. Restore Databricks Artifacts
4. Publish DR Evidence

---

# Pipeline Flow

```mermaid
flowchart TD
    A[Validate Terraform and Scripts]
        --> B[Deploy Azure Infrastructure]

    B --> C[Restore Databricks Artifacts]

    C --> D[Publish DR Evidence]
```

---

# Evidência esperada

Artifact final:

```text
databricks-dr-evidence-final/databricks-restore-evidence.json
```

Campos esperados:

```json
{
  "restore_status": "SUCCESS",
  "run_life_cycle_state": "TERMINATED",
  "run_result_state": "SUCCESS"
}
```

---

# Teste completo de DR

```mermaid
sequenceDiagram
    participant User
    participant Terraform
    participant Azure
    participant Pipeline
    participant Databricks
    participant Storage

    User->>Terraform: terraform destroy
    Terraform->>Azure: remove workload recuperável

    User->>Pipeline: Run pipeline

    Pipeline->>Terraform: terraform apply
    Terraform->>Azure: recria infraestrutura

    Pipeline->>Databricks: restaura notebook e job

    Databricks->>Storage: lê RAW
    Databricks->>Storage: grava BRONZE/SILVER/GOLD

    Pipeline->>Storage: publica evidência
```

---

# Como executar o teste

## 1. Destruir workload recuperável

```powershell
cd C:\Projetos\poc_biolab\terraform\10-dr-workload

terraform destroy -var-file="dev.tfvars"
```

Confirmar com:

```text
yes
```

---

## 2. Validar que o workload foi apagado

```powershell
az group show --name rg-poc-biolab-dr-dev -o table

az group show --name rg-poc-biolab-dr-dev-dbw-managed -o table
```

O esperado é que ambos não existam.

---

## 3. Validar que a foundation continua

```powershell
az group show --name poc-biolab-sustain -o table

az storage account show `
  --name stpocbiolabtfstate001 `
  --resource-group poc-biolab-sustain `
  -o table
```

---

## 4. Reexecutar o pipeline

Azure DevOps:

```text
Pipelines -> Run pipeline
```

---

## 5. Validar resultado

Validar:

- Pipeline verde
- Artifact final publicado
- JSON com `restore_status = SUCCESS`
- Storage com containers RAW/BRONZE/SILVER/GOLD
- Job Databricks com último run SUCCESS
- Compute vazio após execução

---

# Resultado final

Esta POC prova:

- reconstrução automatizada do Azure Databricks
- separação entre foundation e workload recuperável
- Terraform remoto com backend resiliente
- pipeline one-click deploy and restore
- execução real de dados com Spark
- arquitetura Medallion
- evidência auditável do restore
- recuperação completa após destruição do workload