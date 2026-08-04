-- Databricks notebook source
SHOW TABLES;

CREATE OR REPLACE TABLE olist.orders_clean AS
SELECT
  order_id,
  customer_id,
  order_status,
  CAST(order_purchase_timestamp AS TIMESTAMP) AS order_purchase_timestamp,
  CAST(order_approved_at AS TIMESTAMP) AS order_approved_at,
  CAST(order_delivered_carrier_date AS TIMESTAMP) AS order_delivered_carrier_date,
  CAST(order_delivered_customer_date AS TIMESTAMP) AS order_delivered_customer_date,
  CAST(order_estimated_delivery_date AS TIMESTAMP) AS order_estimated_delivery_date,
  DATEDIFF(
    CAST(order_delivered_customer_date AS TIMESTAMP),
    CAST(order_estimated_delivery_date AS TIMESTAMP)
  ) AS delay_days,
  DATEDIFF(
    CAST(order_delivered_customer_date AS TIMESTAMP),
    CAST(order_estimated_delivery_date AS TIMESTAMP)
  ) > 0 AS is_late
FROM olist.olist_orders_dataset
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;

SELECT COUNT(*) AS n_orders FROM olist.orders_clean;

CREATE OR REPLACE TABLE olist.order_items_agg AS
SELECT
  order_id,
  COUNT(order_item_id) AS n_items,
  SUM(price) AS total_price,
  SUM(freight_value) AS total_freight,
  COUNT(DISTINCT seller_id) AS n_distinct_sellers,
  COUNT(DISTINCT product_id) AS n_distinct_products,
  FIRST(product_id) AS product_id,
  FIRST(seller_id) AS seller_id
FROM olist.olist_order_items_dataset
GROUP BY order_id;

SELECT COUNT(*) AS n_order_items_agg FROM olist.order_items_agg; 

CREATE OR REPLACE TABLE olist.payments_agg AS
SELECT
  order_id,
  SUM(payment_value) AS total_payment_value,
  MAX(payment_installments) AS n_payment_installments,
  FIRST(payment_type) AS payment_type
FROM olist.olist_order_payments_dataset
GROUP BY order_id;

SELECT COUNT(*) AS n_payments_agg FROM olist.payments_agg;

CREATE OR REPLACE TABLE olist.reviews_clean AS
SELECT order_id, review_score, review_comment_title, review_comment_message
FROM (
  SELECT
    order_id, review_score, review_comment_title, review_comment_message,
    ROW_NUMBER() OVER (
      PARTITION BY order_id
      ORDER BY CAST(review_answer_timestamp AS TIMESTAMP) DESC
    ) AS rn
  FROM olist.olist_order_reviews_dataset
)
WHERE rn = 1;

SELECT COUNT(*) AS n_reviews_clean FROM olist.reviews_clean;

CREATE OR REPLACE TABLE olist.master AS
SELECT
  o.order_id,
  o.customer_id,
  o.order_status,
  o.order_purchase_timestamp,
  o.order_delivered_customer_date,
  o.order_estimated_delivery_date,
  o.delay_days,
  o.is_late,
  i.n_items,
  i.total_price,
  i.total_freight,
  i.n_distinct_sellers,
  i.n_distinct_products,
  i.product_id,
  i.seller_id,
  p.total_payment_value,
  p.n_payment_installments,
  p.payment_type,
  r.review_score,
  r.review_comment_title,
  r.review_comment_message,
  c.customer_unique_id,
  c.customer_city,
  c.customer_state,
  c.customer_zip_code_prefix,
  s.seller_city,
  s.seller_state,
  s.seller_zip_code_prefix,
  ct.product_category_name_english
FROM olist.orders_clean o
LEFT JOIN olist.order_items_agg i ON o.order_id = i.order_id
LEFT JOIN olist.payments_agg p ON o.order_id = p.order_id
LEFT JOIN olist.reviews_clean r ON o.order_id = r.order_id
LEFT JOIN olist.olist_customers_dataset c ON o.customer_id = c.customer_id
LEFT JOIN olist.olist_sellers_dataset s ON i.seller_id = s.seller_id
LEFT JOIN olist.olist_products_dataset pr ON i.product_id = pr.product_id
LEFT JOIN olist.product_category_name_translation ct ON pr.product_category_name = ct.product_category_name;

SELECT COUNT(*) AS n_master FROM olist.master;

SELECT
  is_late,
  ROUND(AVG(review_score), 2) AS avg_review_score,
  COUNT(*) AS n_orders
FROM olist.master
WHERE review_score IS NOT NULL
GROUP BY is_late; 

SELECT
  CASE
    WHEN delay_days < -30 THEN '1. <-30 (very early)'
    WHEN delay_days < -14 THEN '2. -30 to -14'
    WHEN delay_days < -7  THEN '3. -14 to -7'
    WHEN delay_days <= 0  THEN '4. -7 to 0 (on-time)'
    WHEN delay_days <= 7  THEN '5. 0 to 7 (late)'
    WHEN delay_days <= 30 THEN '6. 7 to 30 (very late)'
    ELSE '7. >30 (extremely late)'
  END AS delay_bucket,
  ROUND(AVG(review_score), 2) AS avg_review_score,
  COUNT(*) AS n_orders
FROM olist.master
WHERE review_score IS NOT NULL
GROUP BY 1
ORDER BY 1;


SELECT
  customer_state,
  COUNT(*) AS n_orders,
  ROUND(AVG(CASE WHEN is_late THEN 1.0 ELSE 0.0 END), 3) AS late_rate,
  ROUND(AVG(delay_days), 2) AS avg_delay,
  ROUND(AVG(review_score), 2) AS avg_review
FROM olist.master
GROUP BY customer_state
HAVING COUNT(*) >= 300
ORDER BY late_rate DESC;

SELECT
  seller_id,
  COUNT(*) AS n_orders,
  ROUND(AVG(CASE WHEN is_late THEN 1.0 ELSE 0.0 END), 3) AS late_rate,
  ROUND(AVG(delay_days), 2) AS avg_delay,
  ROUND(AVG(review_score), 2) AS avg_review,
  ROUND(SUM(total_price), 2) AS total_revenue
FROM olist.master
GROUP BY seller_id
HAVING COUNT(*) >= 20
ORDER BY late_rate DESC
LIMIT 15;

CREATE OR REPLACE TABLE olist.customer_first_orders AS
SELECT *
FROM (
  SELECT
    customer_unique_id,
    order_id,
    is_late,
    order_purchase_timestamp,
    ROW_NUMBER() OVER (
      PARTITION BY customer_unique_id
      ORDER BY order_purchase_timestamp ASC
    ) AS rn,
    COUNT(*) OVER (PARTITION BY customer_unique_id) AS n_orders_total
  FROM olist.master
)
WHERE rn = 1;

SELECT
  is_late,
  ROUND(AVG(CASE WHEN n_orders_total > 1 THEN 1.0 ELSE 0.0 END), 4) AS repeat_rate,
  COUNT(*) AS n_customers
FROM olist.customer_first_orders
GROUP BY is_late;

WITH repeat_rates AS (
  SELECT
    AVG(CASE WHEN is_late = false THEN CASE WHEN n_orders_total > 1 THEN 1.0 ELSE 0.0 END END) AS ontime_repeat_rate,
    AVG(CASE WHEN is_late = true THEN CASE WHEN n_orders_total > 1 THEN 1.0 ELSE 0.0 END END) AS late_repeat_rate
  FROM olist.customer_first_orders
),
order_stats AS (
  SELECT
    AVG(total_price) AS avg_order_value,
    SUM(CASE WHEN is_late THEN 1 ELSE 0 END) AS n_late_orders
  FROM olist.master
)
SELECT
  r.ontime_repeat_rate,
  r.late_repeat_rate,
  ROUND((r.ontime_repeat_rate - r.late_repeat_rate) * 100, 3) AS delta_pp,
  o.n_late_orders,
  ROUND(o.avg_order_value, 2) AS avg_order_value,
  ROUND(o.n_late_orders * (r.ontime_repeat_rate - r.late_repeat_rate) * o.avg_order_value, 2) AS revenue_at_risk_estimate
FROM repeat_rates r, order_stats o;