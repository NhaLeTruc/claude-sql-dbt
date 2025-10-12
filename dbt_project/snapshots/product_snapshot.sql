/*
  Snapshot: product_snapshot

  Purpose: Tracks historical changes to product attributes using SCD Type 2.
  Strategy: Timestamp-based on updated_at column from source

  Business Use Cases:
  - Track product price changes over time for pricing analysis
  - Monitor category migrations and product repositioning
  - Analyze profit margin trends and pricing strategy evolution
  - Support historical product reporting "as of" specific dates

  SCD Type 2 Explanation:
  - Creates new row when product attributes change
  - Maintains dbt_valid_from and dbt_valid_to timestamps
  - Current records have dbt_valid_to = NULL
  - Enables point-in-time analysis of product catalog

  Configuration:
  - Target schema: snapshots
  - Unique key: product_id (business key)
  - Updated timestamp: updated_at from source
  - Check interval: Every dbt snapshot run
*/

{% snapshot product_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='product_id',
      strategy='timestamp',
      updated_at='updated_at',
    )
}}

SELECT
    product_id,
    product_name,
    sku,
    category,
    subcategory,
    unit_cost,
    list_price,
    is_active,
    updated_at
FROM {{ source('raw_data', 'products') }}

{% endsnapshot %}
