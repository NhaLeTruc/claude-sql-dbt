/*
Staging model: stg_ecommerce__orders

Purpose: Standardize order data from raw source
Grain: One row per order
Materialization: View (lightweight, source-conformed)

Transformations:
- Rename columns to standard naming convention
- Cast types for consistency
- Add dbt_updated_at metadata
- No business logic or filtering - pure standardization

Business context:
- order_status values: pending -> processing -> shipped -> delivered
- Orders can also be cancelled or returned at any point
- campaign_id NULL indicates organic (non-campaign) orders
*/

WITH source AS (
    SELECT * FROM {{ source('raw_data', 'orders') }}
)

SELECT
    -- Natural key
    order_id,

    -- Foreign keys
    customer_id,
    campaign_id,  -- NULL for organic orders

    -- Order attributes
    order_date,
    order_status,  -- Current status in fulfillment pipeline
    order_total,   -- Total order amount in USD

    -- Metadata
    created_at,
    updated_at AS source_updated_at,  -- Timestamp from source system
    CURRENT_TIMESTAMP AS dbt_updated_at  -- ETL refresh timestamp

FROM source
