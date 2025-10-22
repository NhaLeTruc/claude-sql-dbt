/*
Staging model: stg_ecommerce__orders

Purpose: Standardize order data from raw source
Grain: One row per order
Materialization: View (lightweight, source-conformed)

Transformations:
- Rename columns to standard naming convention
- Cast types for consistency
- Add dbt_updated_at metadata
- Recalculate order_total from line items to fix source data quality issues

Business context:
- order_status values: pending -> processing -> shipped -> delivered
- Orders can also be cancelled or returned at any point
- campaign_id NULL indicates organic (non-campaign) orders
*/

WITH source AS (
    SELECT * FROM {{ source('raw_data', 'orders') }}
),

order_line_totals AS (
    -- Calculate correct order totals from line items
    SELECT
        order_id,
        SUM(line_total) AS calculated_order_total
    FROM {{ source('raw_data', 'order_items') }}
    GROUP BY order_id
)

SELECT
    -- Natural key
    s.order_id,

    -- Foreign keys
    s.customer_id,
    s.campaign_id,  -- NULL for organic orders

    -- Order attributes
    s.order_date,
    s.order_status,  -- Current status in fulfillment pipeline
    COALESCE(olt.calculated_order_total, s.order_total) AS order_total,   -- Use calculated total from line items

    -- Metadata
    s.created_at,
    s.updated_at AS source_updated_at,  -- Timestamp from source system
    CURRENT_TIMESTAMP AS dbt_updated_at  -- ETL refresh timestamp

FROM source s
LEFT JOIN order_line_totals olt ON s.order_id = olt.order_id
