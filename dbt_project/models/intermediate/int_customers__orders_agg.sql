{{
    config(
        materialized='ephemeral'
    )
}}

/*
Intermediate model: int_customers__orders_agg

Purpose: Aggregate order metrics per customer for downstream models
Grain: One row per customer (with at least one order)
Materialization: Ephemeral (inlined into dependent queries)

Business Logic:
- Excludes cancelled and returned orders from metrics
- Calculates first/last order dates for recency analysis
- Computes lifetime value, order counts, and average order value
- Uses custom macro for days calculation

Used by: dim_customers, customer_analytics
*/

WITH orders AS (
    SELECT * FROM {{ ref('stg_ecommerce__orders') }}
    -- Filter to completed orders only (exclude cancelled/returned)
    WHERE order_status NOT IN ('cancelled', 'returned')
)

SELECT
    customer_id,

    -- Temporal metrics
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    {{ calculate_days_between('MAX(order_date)', 'CURRENT_DATE') }} AS days_since_last_order,

    -- Frequency metrics
    COUNT(DISTINCT order_id) AS total_orders,

    -- Monetary metrics
    SUM(order_total) AS total_order_value,
    AVG(order_total) AS average_order_value

FROM orders
GROUP BY customer_id
