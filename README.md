# Olist Delivery Delay Analysis

Analysis of 96,470 delivered orders from the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), built with Databricks SQL and Power BI.

## Key finding

Late orders average **2.27★**, on-time orders average **4.29★**. Review scores don't decline gradually with delay — they hold steady around 4.2–4.3 until an order goes late, then crash.

## Other findings

- **Geography:** late-delivery rate ranges from 21% (Alagoas) to 4% (Paraná)
- **Sellers:** 14 of ~794 active sellers have late rates over 20%, vs. a 6.8% platform average
- **Revenue at risk:** ~R$4,300–5,100 in estimated lost repeat-purchase revenue from late orders

## Stack

- **Databricks (SQL)** — cleaning, aggregation, and analysis
- **Power BI** — dashboard
- **Python/pandas** — exploratory validation

## Structure

```
sql/        Databricks SQL scripts, run in order
powerbi/    Dashboard file
notebooks/  Exploratory analysis
```
