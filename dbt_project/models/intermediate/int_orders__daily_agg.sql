/*
  Intermediate model: int_orders__daily_agg

  Purpose: Aggregates order metrics by date for time-series analytics.
  Materialization: View (intermediate layer, not exposed to end users)

  Business Logic:
  - Aggregates completed orders only (excludes cancelled/returned)
  - Groups by order_date to produce daily metrics
  - Includes total_units by joining to order_items
  - Calculates unique customer count per day
  - Used by orders_daily mart for complete date spine coverage

  Grain: One row per date (only dates with orders present)

  Dependencies:
  - stg_ecommerce__orders: Order header data
  - stg_ecommerce__order_items: Line items for unit counts
*/

{{ config(
    materialized='view'
) }}

WITH orders AS (
    SELECT *
    FROM {{ ref('stg_ecommerce__orders') }}
    WHERE order_status NOT IN ('cancelled', 'returned')
),

order_items AS (
    SELECT
        order_id,
        quantity
    FROM {{ ref('stg_ecommerce__order_items') }}
),

-- Join orders to items to get unit counts
orders_with_units AS (
    SELECT
        o.order_date,
        o.order_id,
        o.customer_id,
        o.order_total,
        COALESCE(SUM(oi.quantity), 0) AS total_units
    FROM orders o
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.order_date, o.order_id, o.customer_id, o.order_total
),

-- Aggregate daily metrics
daily_aggregates AS (
    SELECT
        order_date AS date_key,

        -- Order counts
        COUNT(DISTINCT order_id) AS total_orders,

        -- Revenue metrics (in USD)
        SUM(order_total) AS total_revenue,

        -- Volume metrics
        SUM(total_units) AS total_units,

        -- Customer metrics
        COUNT(DISTINCT customer_id) AS unique_customers,

        -- Average order value
        CASE
            WHEN COUNT(DISTINCT order_id) > 0 THEN
                SUM(order_total) / COUNT(DISTINCT order_id)
            ELSE NULL
        END AS average_order_value

    FROM orders_with_units
    GROUP BY order_date
)

SELECT * FROM daily_aggregates
