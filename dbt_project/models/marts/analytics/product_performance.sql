/*
  Analytics mart: product_performance

  Purpose: Product performance analytics for merchandising and inventory decisions.
  Materialization: Table (analytics-ready mart for BI tools)

  Business Use Cases:
  - Identify top/bottom performing products by revenue, profit, or units
  - Analyze profit margins across products and categories
  - Rank products within categories for merchandising prioritization
  - Track inventory turnover and sales velocity
  - Support pricing optimization and product mix decisions

  Grain: One row per product

  Business Logic:
  - Includes ALL products (even those with zero sales) for complete catalog view
  - Sales metrics calculated from completed orders only (excludes cancelled/returned)
  - Profit margin % = (total_profit / total_revenue) * 100
  - Category rank uses DENSE_RANK based on total_revenue (1 = highest)
  - Products with no sales show NULL for average_unit_price and profit_margin_pct
*/

{{ config(
    materialized='table'
) }}

WITH products AS (
    SELECT *
    FROM {{ ref('dim_products') }}
),

sales_aggregates AS (
    SELECT *
    FROM {{ ref('int_products__sales_agg') }}
),

product_performance AS (
    SELECT
        -- Product identifiers
        p.product_id,
        p.product_name,
        p.sku,
        p.category,
        p.subcategory,

        -- Sales volume metrics
        COALESCE(sa.total_units_sold, 0) AS total_units_sold,
        COALESCE(sa.total_orders, 0) AS total_orders,

        -- Revenue and profit metrics (USD)
        COALESCE(sa.total_revenue, 0) AS total_revenue,
        COALESCE(sa.total_profit, 0) AS total_profit,

        -- Average unit price (weighted by quantity sold)
        sa.average_unit_price,

        -- Profit margin percentage
        -- Only calculate for products with sales (avoid division by zero)
        CASE
            WHEN sa.total_revenue > 0 THEN
                ROUND((sa.total_profit / sa.total_revenue * 100)::numeric, 2)
            ELSE NULL
        END AS profit_margin_pct,

        -- Category ranking based on total revenue
        -- DENSE_RANK handles ties; 1 = highest revenue in category
        DENSE_RANK() OVER (
            PARTITION BY p.category
            ORDER BY COALESCE(sa.total_revenue, 0) DESC
        ) AS category_rank,

        -- Product status
        p.is_active,

        -- Metadata
        CURRENT_TIMESTAMP AS dbt_updated_at

    FROM products p
    LEFT JOIN sales_aggregates sa ON p.product_id = sa.product_id
)

SELECT * FROM product_performance
