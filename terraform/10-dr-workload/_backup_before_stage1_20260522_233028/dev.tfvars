subscription_id = "4ae6462d-bd8b-4156-a6e4-871ca4c32dd8"
tenant_id       = "c91d481c-40b4-4ff9-8f2e-a00df534d8b7"

project     = "biolab"
environment = "dev"
owner       = "paulo.correia"
cost_center = "poc"

location = "brazilsouth"

resource_group_name       = "rg-poc-biolab-dr-dev"
databricks_workspace_name = "dbw-poc-biolab-dr-dev"
databricks_sku            = "premium"

storage_account_name     = "stpocbiolabdrdev001"
artifacts_container_name = "artifacts"
evidence_container_name  = "evidence"

cluster_name                    = "dbc-poc-biolab-dr-dev"
cluster_node_type_id            = "Standard_DS3_v2"
spark_version                   = "15.4.x-scala2.12"
cluster_min_workers             = 1
cluster_max_workers             = 2
cluster_num_workers             = 1
cluster_autotermination_minutes = 30
