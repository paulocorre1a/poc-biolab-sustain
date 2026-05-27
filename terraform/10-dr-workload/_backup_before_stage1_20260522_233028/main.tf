locals {
  name_prefix = lower("${var.project}-${var.environment}")
  tags = {
    project     = var.project
    environment = var.environment
    owner       = var.owner
    cost_center = var.cost_center
    managed_by  = "terraform"
    purpose     = "databricks-dr-poc"
  }
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}-dr"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "artifacts" {
  name                            = replace("st${var.project}${var.environment}${random_string.suffix.result}", "-", "")
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  tags                            = local.tags
}

resource "azurerm_storage_container" "evidence" {
  name                  = "evidence"
  storage_account_name  = azurerm_storage_account.artifacts.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "notebooks_backup" {
  name                  = "notebooks-backup"
  storage_account_name  = azurerm_storage_account.artifacts.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "logs" {
  name                  = "logs"
  storage_account_name  = azurerm_storage_account.artifacts.name
  container_access_type = "private"
}

resource "azurerm_databricks_workspace" "main" {
  name                        = "dbw-${local.name_prefix}-dr"
  resource_group_name         = azurerm_resource_group.main.name
  location                    = azurerm_resource_group.main.location
  sku                         = var.databricks_sku
  managed_resource_group_name = "rg-${local.name_prefix}-dbw-managed"
  tags                        = local.tags
}

resource "databricks_notebook" "dr_validation" {
  path       = "/Shared/DR/DR_Validation"
  language   = "PYTHON"
  source     = "${path.module}/../../notebooks/DR_Validation.py"
  depends_on = [azurerm_databricks_workspace.main]
}

resource "databricks_cluster" "dr_cluster" {
  cluster_name            = "cls-${local.name_prefix}-dr-validation"
  spark_version           = var.spark_version
  node_type_id            = var.cluster_node_type_id
  autotermination_minutes = var.cluster_autotermination_minutes

  autoscale {
    min_workers = var.cluster_min_workers
    max_workers = var.cluster_max_workers
  }

  custom_tags = local.tags
  depends_on  = [azurerm_databricks_workspace.main]
}

resource "databricks_job" "dr_job" {
  name = "job-${local.name_prefix}-dr-validation"

  task {
    task_key = "run-dr-validation-notebook"

    existing_cluster_id = databricks_cluster.dr_cluster.id

    notebook_task {
      notebook_path = databricks_notebook.dr_validation.path
    }
  }

  tags = local.tags
}

