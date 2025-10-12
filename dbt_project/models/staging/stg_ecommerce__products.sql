/*
  Staging model: stg_ecommerce__products

  Purpose: Standardizes product catalog data from raw source.
  Materialization: View (lightweight, source-conformed layer)

  Transformations:
  - Standardizes column names and types for consistency
  - Calculates profit_margin_pct inline for reference: ((list_price - unit_cost) / list_price * 100)
  - Validates category against product_categories seed (enforced via foreign key test)
  - Adds dbt_updated_at metadata timestamp

  Business Context:
  - Product catalog from inventory management system
  - One row per product (grain: product_id)
  - SKU is unique identifier for inventory tracking
  - Category hierarchy: category > subcategory structure
*/

WITH source AS (
    SELECT *
    FROM {{ source('raw_data', 'products') }}
),

standardized AS (
    SELECT
        -- Primary key
        product_id,

        -- Product attributes
        product_name,
        sku,
        category,
        subcategory,

        -- Pricing and cost
        unit_cost,
        list_price,

        -- Calculate profit margin percentage
        -- Formula: (selling price - cost) / selling price * 100
        CASE
            WHEN list_price > 0 THEN
                ROUND(((list_price - unit_cost) / list_price * 100)::numeric, 2)
            ELSE 0
        END AS profit_margin_pct,

        -- Status flag
        is_active,

        -- Metadata timestamps
        updated_at AS source_updated_at,
        CURRENT_TIMESTAMP AS dbt_updated_at

    FROM source
)

SELECT * FROM standardized
