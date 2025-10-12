/*
  Staging model: stg_ecommerce__order_items

  Purpose: Standardizes order line item data from raw source.
  Materialization: View (lightweight, source-conformed layer)

  Transformations:
  - Standardizes column names and types for consistency
  - Joins to products to enrich with unit_cost for profit calculation
  - Calculates line_profit: line_total - (quantity * unit_cost)
  - Adds dbt_updated_at metadata timestamp

  Business Context:
  - Line items from order management system
  - One row per product per order (grain: order_item_id)
  - Pricing logic: line_total = (quantity * unit_price) - discount
  - Discount is an absolute dollar amount, not percentage
  - Line profit represents gross profit before overhead allocation
*/

WITH source AS (
    SELECT *
    FROM {{ source('raw_data', 'order_items') }}
),

products AS (
    SELECT
        product_id,
        unit_cost
    FROM {{ ref('stg_ecommerce__products') }}
),

standardized AS (
    SELECT
        -- Primary key
        oi.order_item_id,

        -- Foreign keys
        oi.order_id,
        oi.product_id,

        -- Line item quantities and pricing
        oi.quantity,
        oi.unit_price,
        oi.discount,
        oi.line_total,

        -- Calculate line-level profit
        -- Formula: revenue - cost = line_total - (quantity * unit_cost)
        oi.line_total - (oi.quantity * p.unit_cost) AS line_profit,

        -- Metadata timestamp
        CURRENT_TIMESTAMP AS dbt_updated_at

    FROM source oi
    LEFT JOIN products p ON oi.product_id = p.product_id
)

SELECT * FROM standardized
