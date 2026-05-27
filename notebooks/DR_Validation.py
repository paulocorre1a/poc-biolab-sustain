# Databricks notebook source
# MAGIC %md
# MAGIC # DR Validation Notebook
# MAGIC Notebook criado/restaurado automaticamente pelo Terraform como evidência da POC de DR.

# COMMAND ----------

from datetime import datetime, timezone

result = {
    "status": "RESTORE_VALIDATED",
    "validated_at_utc": datetime.now(timezone.utc).isoformat(),
    "message": "Databricks workspace, cluster, notebook and job were restored by pipeline."
}

print(result)

# COMMAND ----------

dbutils.notebook.exit(str(result))
