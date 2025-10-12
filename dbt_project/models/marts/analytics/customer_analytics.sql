{{
    config(
        materialized='table'
    )
}}

/*
Analytics mart: customer_analytics

Purpose: Customer behavior analysis with RFM segmentation and lifetime value
Grain: One row per customer
Materialization: Table (complex calculations, frequently queried)

Business Logic - RFM Scoring:
- Recency (R): Days since last order (lower is better)
  - Score 5: 0-30 days, 4: 31-90 days, 3: 91-180 days, 2: 181-365 days, 1: 365+ days
- Frequency (F): Number of orders (higher is better)
  - Score 5: 20+ orders, 4: 10-19, 3: 5-9, 2: 2-4, 1: 1 order
- Monetary (M): Lifetime value (higher is better)
  - Score 5: $5000+, 4: $1000-4999, 3: $500-999, 2: $100-499, 1: $0-99

Combined RFM Score: Simple average of R, F, M scores (1-5 scale)

Segmentation:
- VIP: RFM score >= 4.5
- Active: RFM score >= 3.5
- At-risk: RFM score >= 2.5 and days_since_last_order > 90
- New: total_orders = 1
- Dormant: RFM score < 2.5
*/

WITH customers AS (
    SELECT * FROM {{ ref('dim_customers') }}
),

orders_agg AS (
    SELECT * FROM {{ ref('int_customers__orders_agg') }}
),

-- Calculate RFM scores
rfm_calc AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.email,
        c.customer_segment,
        c.signup_date,

        -- Order metrics
        oa.first_order_date,
        oa.last_order_date,
        oa.days_since_last_order,
        COALESCE(oa.total_orders, 0) AS total_orders,
        COALESCE(oa.total_order_value, 0) AS lifetime_value,
        oa.average_order_value,

        -- Recency score (1-5, lower days = higher score)
        CASE
            WHEN oa.days_since_last_order IS NULL THEN NULL
            WHEN oa.days_since_last_order <= 30 THEN 5
            WHEN oa.days_since_last_order <= 90 THEN 4
            WHEN oa.days_since_last_order <= 180 THEN 3
            WHEN oa.days_since_last_order <= 365 THEN 2
            ELSE 1
        END AS recency_score,

        -- Frequency score (1-5, more orders = higher score)
        CASE
            WHEN oa.total_orders IS NULL THEN NULL
            WHEN oa.total_orders >= 20 THEN 5
            WHEN oa.total_orders >= 10 THEN 4
            WHEN oa.total_orders >= 5 THEN 3
            WHEN oa.total_orders >= 2 THEN 2
            ELSE 1
        END AS frequency_score,

        -- Monetary score (1-5, higher value = higher score)
        CASE
            WHEN oa.total_order_value IS NULL THEN NULL
            WHEN oa.total_order_value >= 5000 THEN 5
            WHEN oa.total_order_value >= 1000 THEN 4
            WHEN oa.total_order_value >= 500 THEN 3
            WHEN oa.total_order_value >= 100 THEN 2
            ELSE 1
        END AS monetary_score,

        -- Activity flag
        CASE
            WHEN oa.days_since_last_order IS NOT NULL AND oa.days_since_last_order <= 90
            THEN TRUE
            ELSE FALSE
        END AS is_active

    FROM customers c
    LEFT JOIN orders_agg oa
        ON c.customer_id = oa.customer_id
)

SELECT
    -- Customer identification
    customer_id,
    customer_name,
    email,
    customer_segment,
    signup_date,

    -- Order history
    first_order_date,
    last_order_date,
    days_since_last_order,
    total_orders,
    lifetime_value,
    average_order_value,

    -- RFM analysis
    recency_score,
    frequency_score,
    monetary_score,
    ROUND((recency_score + frequency_score + monetary_score) / 3.0, 1) AS rfm_score,

    -- Activity status
    is_active,

    -- Metadata
    CURRENT_TIMESTAMP AS dbt_updated_at

FROM rfm_calc
