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
- Frequency (F): Number of orders (higher is better)
- Monetary (M): Lifetime value (higher is better)
- Thresholds configured in seeds/rfm_thresholds.csv for easy adjustment

Combined RFM Score: Simple average of R, F, M scores (1-5 scale)

Segmentation:
- VIP: RFM score >= 4.5
- Active: RFM score >= 3.5
- At-risk: RFM score >= 2.5 and days_since_last_order > 90
- New: total_orders = 1
- Dormant: RFM score < 2.5

Note: This model uses configurable RFM thresholds from seed data,
making it easy to adjust scoring without modifying SQL.
*/

WITH customers AS (
    SELECT * FROM {{ ref('dim_customers') }}
),

orders_agg AS (
    SELECT * FROM {{ ref('int_customers__orders_agg') }}
),

rfm_thresholds AS (
    SELECT * FROM {{ ref('rfm_thresholds') }}
),

-- Calculate RFM scores using configurable thresholds
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
        -- Join to threshold table for configurable scoring
        COALESCE(rt_r.score, 1) AS recency_score,

        -- Frequency score (1-5, more orders = higher score)
        COALESCE(rt_f.score, 1) AS frequency_score,

        -- Monetary score (1-5, higher value = higher score)
        COALESCE(rt_m.score, 1) AS monetary_score,

        -- Activity flag (active if ordered within 90 days)
        CASE
            WHEN oa.days_since_last_order IS NOT NULL AND oa.days_since_last_order <= 90
            THEN TRUE
            ELSE FALSE
        END AS is_active

    FROM customers c
    LEFT JOIN orders_agg oa
        ON c.customer_id = oa.customer_id

    -- Join to RFM threshold configurations
    LEFT JOIN rfm_thresholds rt_r
        ON rt_r.metric = 'recency'
        AND oa.days_since_last_order BETWEEN rt_r.min_value AND rt_r.max_value

    LEFT JOIN rfm_thresholds rt_f
        ON rt_f.metric = 'frequency'
        AND COALESCE(oa.total_orders, 0) BETWEEN rt_f.min_value AND rt_f.max_value

    LEFT JOIN rfm_thresholds rt_m
        ON rt_m.metric = 'monetary'
        AND COALESCE(oa.total_order_value, 0) BETWEEN rt_m.min_value AND rt_m.max_value
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
