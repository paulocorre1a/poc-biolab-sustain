# BIOLAB — Databricks Disaster Recovery (DR) POC

## Objetivo

Demonstrar um processo completo de Disaster Recovery (DR) para Azure Databricks utilizando:

- Terraform
- Azure DevOps Pipelines
- Azure Storage Account
- PySpark
- Arquitetura Medallion
- Restore automatizado de notebooks/jobs
- Recuperação íntegra de dados

---

# Cenário validado

A POC simula um ambiente produtivo de analytics/data platform contendo:

## Infraestrutura

- Azure Databricks Workspace
- Azure Storage Account (Data Lake)
- Containers:
  - raw
  - bronze
  - silver
  - gold
  - logs
  - evidence
  - artifacts

## Dados

O ambiente contém datasets simulando um workload real.

### RAW

- customers.csv
- sales.csv

### BRONZE

Dados normalizados com timestamp de ingestão.

### SILVER

Dados enriquecidos via JOIN entre clientes e vendas.

### GOLD

Agregações analíticas prontas para consumo.

---

# Fluxo completo validado

<p align="center">
  <img src="documentation/Fluxo%20completo%20validado.png" alt="Fluxo completo validado" width="1200">
</p>

---

# Evidência do DR

A pipeline executa automaticamente:

- Restore da infraestrutura
- Restore do Databricks Workspace
- Restore dos notebooks
- Restore dos jobs
- Restore dos datasets RAW
- Reprocessamento completo Medallion
- Geração de evidências JSON

Arquivo gerado:

```text
databricks-restore-evidence.json
```

---

# Evidência de integridade dos dados

Após o restore completo:

| Layer | Resultado |
|---|---|
| RAW customers | 5 registros |
| RAW sales | 6 registros |
| BRONZE customers | 5 registros |
| BRONZE sales | 6 registros |
| SILVER | 6 registros |
| GOLD customer | 5 registros |
| GOLD state | 4 registros |

Resultado final:

```text
Status: SUCCESS
Message: DR restored Databricks and processed
RAW -> BRONZE -> SILVER -> GOLD Delta layers.
```

---

# Processo de teste validado

## 1. Ambiente existente

Ambiente operacional contendo:

- infraestrutura
- notebooks
- jobs
- dados RAW
- dados processados

## 2. Destruição completa

Execução:

```powershell
terraform destroy -var-file="dev.tfvars"
```

Resultado:

- Resource Group removido
- Databricks removido
- Clusters removidos
- Jobs removidos
- Storage containers removidos

## 3. Recuperação automatizada

Execução automática via Azure DevOps Pipeline:

- Terraform Apply
- Restore Databricks
- Upload datasets
- Execução notebook
- Reprocessamento Medallion
- Publicação evidências

## 4. Validação final

Comprovação de que:

- infraestrutura foi recriada
- notebooks foram restaurados
- jobs foram restaurados
- dados foram recuperados
- processamento foi executado
- dados finais permaneceram íntegros

---

# Arquitetura Medallion

<p align="center">
  <img src="documentation/Arquitetura%20Medallion.png" alt="Arquitetura Medallion" width="1000">
</p>

---

# Componentes utilizados

| Serviço | Objetivo |
|---|---|
| Azure Databricks | Processamento distribuído |
| Azure Storage Account | Data Lake |
| Terraform | Infraestrutura como código |
| Azure DevOps | Orquestração DR |
| PowerShell | Automação |
| PySpark | Processamento Medallion |

---

## Observação sobre execução manual do notebook

A validação oficial da POC deve ser feita pelo Job Databricks:

Jobs & Pipelines -> job-poc-biolab-dr-validation -> Run now

O notebook pode falhar se executado manualmente em Serverless ou em um All-purpose Compute sem a configuração de acesso ao Storage.

Isso ocorre porque o pipeline cria um Job Cluster efêmero com a configuração necessária para acessar o Data Lake. Após a execução, esse cluster é encerrado automaticamente.

Portanto, o comportamento esperado é:

- Job Databricks com run SUCCESS
- All-purpose Compute vazio
- Evidência JSON com restore_status = SUCCESS


# Resultado final da POC

A solução demonstra um processo real de Disaster Recovery para Data Platforms em Azure:

- Ambiente completamente destruído
- Infraestrutura recriada automaticamente
- Databricks restaurado
- Dados recuperados
- Pipelines executados
- Evidências geradas
- Integridade dos dados validada

Isso representa um cenário aderente a ambientes corporativos modernos orientados a:

- IaC
- GitOps
- DataOps
- Disaster Recovery
- Analytics resiliente

---

# Publicação no Git

```powershell
cd C:\Projetos\poc_biolab

git add README.md
git commit -m "Update README with DR architecture and recovery validation"
git push
```
