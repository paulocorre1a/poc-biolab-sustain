locals {
  common_tags = {
    project     = var.project
    environment = var.environment
    owner       = var.owner
    cost_center = var.cost_center
    managed_by  = "terraform"
    purpose     = "databricks-dr-poc"
  }
}

resource "azurerm_resource_group" "dr" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_storage_account" "artifacts" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.dr.name
  location                 = azurerm_resource_group.dr.location
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  tags = local.common_tags
}

resource "azurerm_storage_container" "artifacts" {
  name                  = var.artifacts_container_name
  storage_account_name  = azurerm_storage_account.artifacts.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "evidence" {
  name                  = var.evidence_container_name
  storage_account_name  = azurerm_storage_account.artifacts.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "logs" {
  name                  = var.logs_container_name
  storage_account_name  = azurerm_storage_account.artifacts.name
  container_access_type = "private"
}

resource "azurerm_databricks_workspace" "main" {
  name                        = var.databricks_workspace_name
  resource_group_name         = azurerm_resource_group.dr.name
  location                    = azurerm_resource_group.dr.location
  sku                         = var.databricks_sku
  managed_resource_group_name = var.databricks_managed_resource_group_name

  public_network_access_enabled = true

  tags = local.common_tags
}
