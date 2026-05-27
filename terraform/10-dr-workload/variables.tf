variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "project" {
  type    = string
  default = "biolab"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "owner" {
  type    = string
  default = "paulo.correia"
}

variable "cost_center" {
  type    = string
  default = "poc"
}

variable "location" {
  type    = string
  default = "brazilsouth"
}

variable "resource_group_name" {
  type = string
}

variable "databricks_workspace_name" {
  type = string
}

variable "databricks_managed_resource_group_name" {
  type = string
}

variable "databricks_sku" {
  type    = string
  default = "premium"
}

variable "storage_account_name" {
  type = string
}

variable "artifacts_container_name" {
  type    = string
  default = "artifacts"
}

variable "evidence_container_name" {
  type    = string
  default = "evidence"
}

variable "logs_container_name" {
  type    = string
  default = "logs"
}
