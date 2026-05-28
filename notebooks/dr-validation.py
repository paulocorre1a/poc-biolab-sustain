# Databricks notebook source
from datetime import datetime
from pyspark.sql.functions import col, round as spark_round, current_timestamp

storage_account = "stpocbiolabdrdev001"

raw_path = f"abfss://raw@{storage_account}.dfs.core.windows.net/sales/sales_raw.csv"
silver_path = f"abfss://silver@{storage_account}.dfs.core.windows.net/sales/sales_silver"
gold_path = f"abfss://gold@{storage_account}.dfs.core.windows.net/sales/sales_gold"

print("============================================================")
print("BIOLAB - Databricks DR Data Validation")
print("============================================================")
print(f"Execution UTC: {datetime.utcnow().isoformat()}Z")
print(f"Reading raw data from: {raw_path}")

df_raw = (
    spark.read
    .option("header", "true")
    .option("inferSchema", "true")
    .csv(raw_path)
)

raw_count = df_raw.count()

df_silver = (
    df_raw
    .withColumn("total_amount", spark_round(col("quantity") * col("unit_price"), 2))
    .withColumn("processed_at_utc", current_timestamp())
)

df_silver.write.mode("overwrite").format("delta").save(silver_path)

df_gold = (
    df_silver
    .groupBy("customer")
    .sum("total_amount")
    .withColumnRenamed("sum(total_amount)", "customer_total_amount")
)

df_gold.write.mode("overwrite").format("delta").save(gold_path)

silver_count = spark.read.format("delta").load(silver_path).count()
gold_count = spark.read.format("delta").load(gold_path).count()

print("============================================================")
print("DR DATA VALIDATION RESULT")
print("============================================================")
print(f"Raw rows    : {raw_count}")
print(f"Silver rows : {silver_count}")
print(f"Gold rows   : {gold_count}")

assert raw_count == 5, f"Expected 5 raw rows, got {raw_count}"
assert silver_count == 5, f"Expected 5 silver rows, got {silver_count}"
assert gold_count >= 1, "Expected at least one gold aggregate row"

print("Status: SUCCESS")
print("Message: DR restored Databricks and processed real data from ADLS Gen2.")
print("============================================================")
