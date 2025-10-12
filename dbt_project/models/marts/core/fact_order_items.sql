/*
  Fact table: fact_order_items

  Purpose: Detailed order line item transactions for star schema analytics.
  Materialization: Incremental (append-only strategy for performance)

  Business Context:
  - Transactional grain: One row per order line item (one product per order)
  - Contains measures (quantity, amounts) and foreign keys to dimensions
  - Denormalizes order_date from orders for time-based partitioning/filtering
  - Denormalizes customer_key for easier customer analytics queries
  - Incremental strategy appends only new order_items based on order_id

  Grain: One row per order_item_id

  Incremental Strategy:
  - On first run: Loads all historical order items
  - On subsequent runs: Appends only new order items (WHERE order_id > MAX existing)
  - Assumes order_items are immutable once created (no updates to existing rows)
*/

{{ config(
    materialized='incremental',
    unique_key='order_item_id'
) }}

WITH order_items AS (
    SELECT *
    FROM {{ ref('stg_ecommerce__order_items') }}
),

orders AS (
    SELECT
        order_id,
        customer_id,
        order_date,
        order_status
    FROM {{ ref('stg_ecommerce__orders') }}
),

products AS (
    SELECT
        product_id,
        product_key
    FROM {{ ref('dim_products') }}
),

customers AS (
    SELECT
        customer_id,
        customer_key
    FROM {{ ref('dim_customers') }}
),

fact_base AS (
    SELECT
        -- Primary key
        oi.order_item_id,

        -- Foreign keys to dimensions
        oi.order_id,
        p.product_key,
        c.customer_key,

        -- Denormalized attributes for filtering/partitioning
        o.order_date,

        -- Measures (quantities and amounts)
        oi.quantity,
        oi.unit_price,
        oi.discount,
        oi.line_total,
        oi.line_profit,

        -- Metadata
        CURRENT_TIMESTAMP AS dbt_updated_at

    FROM order_items oi
    INNER JOIN orders o ON oi.order_id = o.order_id
    INNER JOIN products p ON oi.product_id = p.product_id
    INNER JOIN customers c ON o.customer_id = c.customer_id

    {% if is_incremental() %}
    -- Incremental logic: Only load new order items
    -- Compares against maximum order_id already in fact table
    WHERE oi.order_id > (SELECT MAX(order_id) FROM {{ this }})
    {% endif %}
)

SELECT * FROM fact_base
