/*
  Fact table: fact_orders

  Purpose: Order header facts for star schema time-series analytics.
  Materialization: Table (persistent fact table)

  Business Context:
  - One row per order (order-level grain, not line-level)
  - Contains order measures and foreign keys to customer and date dimensions
  - Used for time-series analysis at order level
  - Complements fact_order_items (which is line-level grain)

  Grain: One row per order_id

  Star Schema Design:
  - Foreign keys: customer_key, date_key
  - Measures: order_total
  - Attributes: order_status, campaign_id, created_at
*/

{{ config(
    materialized='table'
) }}

WITH orders AS (
    SELECT *
    FROM {{ ref('stg_ecommerce__orders') }}
),

customers AS (
    SELECT
        customer_id,
        customer_key
    FROM {{ ref('dim_customers') }}
),

dates AS (
    SELECT
        date_key
    FROM {{ ref('dim_date') }}
),

fact_base AS (
    SELECT
        -- Primary key
        o.order_id,

        -- Foreign keys to dimensions
        c.customer_key,
        o.order_date AS date_key,

        -- Denormalized attributes for filtering
        o.order_date,
        o.order_status,

        -- Measures
        o.order_total,

        -- Campaign attribution
        o.campaign_id,

        -- Timestamps
        o.created_at,
        CURRENT_TIMESTAMP AS dbt_updated_at

    FROM orders o
    INNER JOIN customers c ON o.customer_id = c.customer_id
    INNER JOIN dates d ON o.order_date = d.date_key
)

SELECT * FROM fact_base
