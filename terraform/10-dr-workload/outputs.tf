output "resource_group_name" {
  value = azurerm_resource_group.dr.name
}

output "location" {
  value = azurerm_resource_group.dr.location
}

output "storage_account_name" {
  value = azurerm_storage_account.artifacts.name
}

output "artifacts_container_name" {
  value = azurerm_storage_container.artifacts.name
}

output "evidence_container_name" {
  value = azurerm_storage_container.evidence.name
}

output "logs_container_name" {
  value = azurerm_storage_container.logs.name
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

output "databricks_workspace_resource_id" {
  value = azurerm_databricks_workspace.main.id
}
