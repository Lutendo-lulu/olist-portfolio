-- Databricks notebook source
-- dim_date
CREATE OR REPLACE TABLE database.olist.dim_date AS
SELECT
  explode(sequence(
    (SELECT MIN(order_purchase_timestamp) FROM database.olist.master),
    (SELECT MAX(order_delivered_customer_date) FROM database.olist.master),
    interval 1 day
  )) AS date
FROM (SELECT 1);

ALTER TABLE database.olist.dim_date ADD COLUMN date_key INT;
UPDATE database.olist.dim_date SET date_key = CAST(date_format(date, 'yyyyMMdd') AS INT);

CREATE OR REPLACE TABLE database.olist.dim_date AS
SELECT
  CAST(date_format(date, 'yyyyMMdd') AS INT) AS date_key,
  date,
  YEAR(date) AS year,
  MONTH(date) AS month,
  date_format(date, 'MMM') AS month_name,
  QUARTER(date) AS quarter,
  date_format(date, 'E') AS day_of_week,
  dayofweek(date) IN (1, 7) AS is_weekend
FROM (
  SELECT explode(sequence(
    (SELECT MIN(order_purchase_timestamp) FROM database.olist.master),
    (SELECT MAX(order_delivered_customer_date) FROM database.olist.master),
    interval 1 day
  )) AS date
);

-- dim_customer
CREATE OR REPLACE TABLE database.olist.dim_customer AS
SELECT DISTINCT
  customer_unique_id AS customer_key,
  customer_city,
  customer_state,
  customer_zip_code_prefix
FROM database.olist.master;

-- dim_seller
CREATE OR REPLACE TABLE database.olist.dim_seller AS
SELECT DISTINCT
  seller_id AS seller_key,
  seller_city,
  seller_state,
  seller_zip_code_prefix
FROM database.olist.master
WHERE seller_id IS NOT NULL;

-- dim_product
CREATE OR REPLACE TABLE database.olist.dim_product AS
SELECT DISTINCT
  product_id AS product_key,
  COALESCE(product_category_name_english, 'unknown') AS product_category
FROM database.olist.master
WHERE product_id IS NOT NULL;

-- fact_orders
CREATE OR REPLACE TABLE database.olist.fact_orders AS
SELECT
  order_id,
  CAST(date_format(order_purchase_timestamp, 'yyyyMMdd') AS INT) AS date_key,
  customer_unique_id AS customer_key,
  seller_id AS seller_key,
  product_id AS product_key,
  order_purchase_timestamp,
  order_delivered_customer_date,
  order_estimated_delivery_date,
  delay_days,
  is_late,
  n_items,
  total_price,
  total_freight,
  total_payment_value,
  payment_type,
  n_payment_installments,
  review_score
FROM database.olist.master;

SELECT COUNT(*) FROM database.olist.fact_orders;