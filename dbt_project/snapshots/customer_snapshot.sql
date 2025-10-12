{% snapshot customer_snapshot %}

{{
    config(
      target_schema='snapshots',
      target_database='ecommerce_dw',
      unique_key='customer_id',
      strategy='timestamp',
      updated_at='updated_at',
    )
}}

/*
Snapshot: customer_snapshot

Purpose: Track historical changes to customer attributes using SCD Type 2
Strategy: Timestamp-based (using source updated_at column)
Grain: One row per customer per version

Business Use Case:
- Track customer segment changes over time (new -> active -> at-risk -> dormant -> vip)
- Enable point-in-time customer analysis (what segment was customer in when they ordered?)
- Audit trail for customer attribute changes

dbt Snapshot Metadata:
- dbt_valid_from: When this version became active
- dbt_valid_to: When this version was superseded (NULL for current version)
- dbt_updated_at: When dbt processed this snapshot

Usage Example:
  -- Get customer's segment at time of order
  SELECT
    o.order_id,
    o.order_date,
    cs.customer_segment AS segment_at_order_time
  FROM orders o
  JOIN customer_snapshot cs
    ON o.customer_id = cs.customer_id
    AND o.order_date >= cs.dbt_valid_from
    AND (o.order_date < cs.dbt_valid_to OR cs.dbt_valid_to IS NULL)
*/

SELECT
    customer_id,
    email,
    name AS customer_name,
    signup_date,
    segment AS customer_segment,
    state,
    country,
    updated_at

FROM {{ source('raw_data', 'customers') }}

{% endsnapshot %}
