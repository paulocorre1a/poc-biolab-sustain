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

variable "cluster_name" {
  type = string
}

variable "cluster_node_type_id" {
  type    = string
  default = "Standard_DS3_v2"
}

variable "spark_version" {
  type    = string
  default = "15.4.x-scala2.12"
}

variable "cluster_min_workers" {
  type    = number
  default = 1
}

variable "cluster_max_workers" {
  type    = number
  default = 2
}

variable "cluster_num_workers" {
  type    = number
  default = 1
}

variable "cluster_autotermination_minutes" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
