{{
    config(
        materialized='table'
    )
}}

/*
Dimension model: dim_customers

Purpose: Customer dimension with current snapshot (SCD Type 1)
Grain: One row per customer
Materialization: Table (frequently queried, stable reference data)

Design:
- SCD Type 1: Overwrites on each refresh (current state only)
- For historical tracking, see customer_snapshot (SCD Type 2)
- Surrogate key generated using dbt_utils for FK relationships
- Includes is_active flag based on order history

Business Logic:
- is_active = TRUE if customer has placed at least one order
- Combines customer master data with order existence check
- All customers from source included, even if no orders
*/

WITH customers AS (
    SELECT * FROM {{ ref('stg_ecommerce__customers') }}
),

orders_agg AS (
    SELECT * FROM {{ ref('int_customers__orders_agg') }}
)

SELECT
    -- Surrogate key for dimension (used as FK in facts)
    {{ dbt_utils.generate_surrogate_key(['c.customer_id']) }} AS customer_key,

    -- Natural key
    c.customer_id,

    -- Customer attributes
    c.customer_name,
    c.email,
    c.customer_segment,
    c.state,
    c.country,
    c.signup_date,

    -- Derived attributes
    CASE
        WHEN oa.total_orders IS NOT NULL AND oa.total_orders > 0
        THEN TRUE
        ELSE FALSE
    END AS is_active,

    -- Metadata
    CURRENT_TIMESTAMP AS dbt_updated_at

FROM customers c
LEFT JOIN orders_agg oa
    ON c.customer_id = oa.customer_id
