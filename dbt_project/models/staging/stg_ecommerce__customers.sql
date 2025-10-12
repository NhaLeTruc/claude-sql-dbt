/*
Staging model: stg_ecommerce__customers

Purpose: Standardize customer data from raw source
Grain: One row per customer
Materialization: View (lightweight, source-conformed)

Transformations:
- Rename columns to standard naming convention (name -> customer_name, segment -> customer_segment)
- Cast types for consistency
- Add dbt_updated_at metadata for tracking ETL refresh time
- No business logic - pure standardization layer
*/

WITH source AS (
    SELECT * FROM {{ source('raw_data', 'customers') }}
)

SELECT
    -- Natural key
    customer_id,

    -- Customer attributes
    email,
    name AS customer_name,  -- Renamed for clarity
    signup_date,
    segment AS customer_segment,  -- Renamed for clarity
    state,
    country,

    -- Metadata
    updated_at AS source_updated_at,  -- Renamed to distinguish from dbt timestamp
    CURRENT_TIMESTAMP AS dbt_updated_at  -- ETL refresh timestamp

FROM source
