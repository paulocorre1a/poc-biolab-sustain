output "resource_group_name" {
  value = azurerm_resource_group.dr.name
}

output "location" {
  value = azurerm_resource_group.dr.location
}

output "storage_account_name" {
  value = azurerm_storage_account.artifacts.name
}

output "databricks_workspace_name" {
  value = azurerm_databricks_workspace.main.name
}

output "databricks_workspace_id" {
  value = azurerm_databricks_workspace.main.id
}

output "databricks_workspace_url" {
  value = azurerm_databricks_workspace.main.workspace_url
}

output "containers" {
  value = {
    artifacts = azurerm_storage_container.artifacts.name
    evidence  = azurerm_storage_container.evidence.name
    logs      = azurerm_storage_container.logs.name
    raw       = azurerm_storage_container.raw.name
    bronze    = azurerm_storage_container.bronze.name
    silver    = azurerm_storage_container.silver.name
    gold      = azurerm_storage_container.gold.name
  }
}
