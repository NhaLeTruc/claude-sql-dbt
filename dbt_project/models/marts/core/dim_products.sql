/*
  Dimension model: dim_products

  Purpose: Product dimension for star schema with current state (SCD Type 1).
  Materialization: Table (persistent, rebuilt on each run)

  Business Context:
  - Contains product catalog information with category hierarchy
  - SCD Type 1: Only current state tracked (no historical changes)
  - Includes all products regardless of sales activity for complete catalog view
  - Used as conformed dimension across all product-related facts

  Grain: One row per product_id

  Surrogate Key:
  - product_key: Hash-based surrogate key for use as FK in fact tables
  - Generated using dbt_utils.generate_surrogate_key for consistency
*/

{{ config(
    materialized='table'
) }}

WITH products AS (
    SELECT *
    FROM {{ ref('stg_ecommerce__products') }}
),

product_dimension AS (
    SELECT
        -- Surrogate key for FK relationships in facts
        {{ dbt_utils.generate_surrogate_key(['product_id']) }} AS product_key,

        -- Natural key (business key)
        product_id,

        -- Product attributes
        product_name,
        sku,
        category,
        subcategory,

        -- Pricing and cost attributes
        unit_cost,
        list_price,
        profit_margin_pct,

        -- Status flag
        is_active,

        -- Metadata timestamps
        source_updated_at,
        CURRENT_TIMESTAMP AS dbt_updated_at

    FROM products
)

SELECT * FROM product_dimension
