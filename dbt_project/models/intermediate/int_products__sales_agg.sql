/*
  Intermediate model: int_products__sales_agg

  Purpose: Aggregates sales performance metrics per product for analytics.
  Materialization: View (intermediate layer, not exposed to end users)

  Business Logic:
  - Aggregates completed order line items only (excludes cancelled/returned orders)
  - Calculates total units sold, revenue, profit, and order count per product
  - Computes average unit price weighted by quantity
  - Used by product_performance mart and other product analytics

  Grain: One row per product_id

  Dependencies:
  - stg_ecommerce__order_items: Line item transactions
  - stg_ecommerce__orders: Order status filtering
*/

{{ config(
    materialized='view'
) }}

WITH order_items AS (
    SELECT *
    FROM {{ ref('stg_ecommerce__order_items') }}
),

orders AS (
    SELECT
        order_id,
        order_status
    FROM {{ ref('stg_ecommerce__orders') }}
),

-- Filter to completed orders only (exclude cancelled/returned)
completed_order_items AS (
    SELECT
        oi.product_id,
        oi.quantity,
        oi.line_total,
        oi.line_profit,
        oi.unit_price,
        oi.order_id
    FROM order_items oi
    INNER JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status NOT IN ('cancelled', 'returned')
),

-- Aggregate sales metrics per product
product_aggregates AS (
    SELECT
        product_id,

        -- Volume metrics
        SUM(quantity) AS total_units_sold,
        COUNT(DISTINCT order_id) AS total_orders,

        -- Revenue and profit metrics (in USD)
        SUM(line_total) AS total_revenue,
        SUM(line_profit) AS total_profit,

        -- Average unit price (weighted by quantity)
        CASE
            WHEN SUM(quantity) > 0 THEN
                SUM(unit_price * quantity) / SUM(quantity)
            ELSE NULL
        END AS average_unit_price

    FROM completed_order_items
    GROUP BY product_id
)

SELECT * FROM product_aggregates
