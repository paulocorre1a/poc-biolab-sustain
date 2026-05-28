# Databricks notebook source
from datetime import datetime
from pyspark.sql.functions import col, current_timestamp, round as spark_round, sum as spark_sum, count as spark_count

storage_account = "stpocbiolabdrdev001"

raw_customers_path = f"abfss://raw@{storage_account}.dfs.core.windows.net/customers/customers.csv"
raw_sales_path = f"abfss://raw@{storage_account}.dfs.core.windows.net/sales/sales.csv"

bronze_customers_path = f"abfss://bronze@{storage_account}.dfs.core.windows.net/customers"
bronze_sales_path = f"abfss://bronze@{storage_account}.dfs.core.windows.net/sales"

silver_sales_customer_path = f"abfss://silver@{storage_account}.dfs.core.windows.net/sales_customer"

gold_customer_revenue_path = f"abfss://gold@{storage_account}.dfs.core.windows.net/customer_revenue"
gold_state_revenue_path = f"abfss://gold@{storage_account}.dfs.core.windows.net/state_revenue"

print("============================================================")
print("BIOLAB - DR Data Platform Validation")
print("============================================================")
print(f"Execution UTC: {datetime.utcnow().isoformat()}Z")

df_customers_raw = (
    spark.read
    .option("header", "true")
    .option("inferSchema", "true")
    .csv(raw_customers_path)
)

df_sales_raw = (
    spark.read
    .option("header", "true")
    .option("inferSchema", "true")
    .csv(raw_sales_path)
)

customers_raw_count = df_customers_raw.count()
sales_raw_count = df_sales_raw.count()

df_customers_bronze = df_customers_raw.withColumn("bronze_processed_at_utc", current_timestamp())
df_sales_bronze = df_sales_raw.withColumn("bronze_processed_at_utc", current_timestamp())

df_customers_bronze.write.mode("overwrite").format("delta").save(bronze_customers_path)
df_sales_bronze.write.mode("overwrite").format("delta").save(bronze_sales_path)

df_customers = spark.read.format("delta").load(bronze_customers_path)
df_sales = spark.read.format("delta").load(bronze_sales_path)

df_silver = (
    df_sales.alias("s")
    .join(df_customers.alias("c"), col("s.customer_id") == col("c.customer_id"), "inner")
    .select(
        col("s.sale_id").cast("int").alias("sale_id"),
        col("s.customer_id").cast("int").alias("customer_id"),
        col("c.name").alias("customer_name"),
        col("c.city").alias("city"),
        col("c.state").alias("state"),
        col("s.product").alias("product"),
        col("s.amount").cast("double").alias("amount")
    )
    .withColumn("amount", spark_round(col("amount"), 2))
    .withColumn("silver_processed_at_utc", current_timestamp())
)

df_silver.write.mode("overwrite").format("delta").save(silver_sales_customer_path)

df_gold_customer = (
    df_silver
    .groupBy("customer_id", "customer_name")
    .agg(
        spark_count("sale_id").alias("total_sales"),
        spark_round(spark_sum("amount"), 2).alias("total_amount")
    )
)

df_gold_state = (
    df_silver
    .groupBy("state")
    .agg(
        spark_count("sale_id").alias("total_sales"),
        spark_round(spark_sum("amount"), 2).alias("total_amount")
    )
)

df_gold_customer.write.mode("overwrite").format("delta").save(gold_customer_revenue_path)
df_gold_state.write.mode("overwrite").format("delta").save(gold_state_revenue_path)

bronze_customers_count = spark.read.format("delta").load(bronze_customers_path).count()
bronze_sales_count = spark.read.format("delta").load(bronze_sales_path).count()
silver_count = spark.read.format("delta").load(silver_sales_customer_path).count()
gold_customer_count = spark.read.format("delta").load(gold_customer_revenue_path).count()
gold_state_count = spark.read.format("delta").load(gold_state_revenue_path).count()

print("============================================================")
print("VALIDATION RESULT")
print("============================================================")
print(f"Customers RAW rows        : {customers_raw_count}")
print(f"Sales RAW rows            : {sales_raw_count}")
print(f"Customers BRONZE rows     : {bronze_customers_count}")
print(f"Sales BRONZE rows         : {bronze_sales_count}")
print(f"SILVER rows               : {silver_count}")
print(f"GOLD customer rows        : {gold_customer_count}")
print(f"GOLD state rows           : {gold_state_count}")

assert customers_raw_count == 5, f"Expected 5 customers, got {customers_raw_count}"
assert sales_raw_count == 6, f"Expected 6 sales, got {sales_raw_count}"
assert bronze_customers_count == 5, f"Expected 5 bronze customers, got {bronze_customers_count}"
assert bronze_sales_count == 6, f"Expected 6 bronze sales, got {bronze_sales_count}"
assert silver_count == 6, f"Expected 6 silver rows, got {silver_count}"
assert gold_customer_count >= 1, "Expected at least one customer revenue row"
assert gold_state_count >= 1, "Expected at least one state revenue row"

print("Status: SUCCESS")
print("Message: DR restored Databricks and processed RAW -> BRONZE -> SILVER -> GOLD Delta layers.")
print("============================================================")
