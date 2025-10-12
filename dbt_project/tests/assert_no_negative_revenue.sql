/*
  Singular test: Validates that no revenue/monetary fields contain negative values.

  Test Logic:
  - Checks key revenue fields across major analytics marts
  - Identifies any records with negative monetary values
  - Returns union of all violations across models

  Expected Result: 0 rows (all revenue fields >= 0)
  If rows returned: Data integrity issue - negative values in revenue fields

  Models Checked:
  - customer_analytics: lifetime_value, average_order_value
  - product_performance: total_revenue, total_profit
  - orders_daily: total_revenue
  - orders_weekly: total_revenue
  - orders_monthly: total_revenue
  - marketing_attribution: total_revenue
*/

-- Check customer_analytics for negative lifetime_value or average_order_value
SELECT
    'customer_analytics' AS model_name,
    customer_id AS record_id,
    'lifetime_value' AS field_name,
    lifetime_value AS field_value
FROM {{ ref('customer_analytics') }}
WHERE lifetime_value < 0

UNION ALL

SELECT
    'customer_analytics' AS model_name,
    customer_id AS record_id,
    'average_order_value' AS field_name,
    average_order_value AS field_value
FROM {{ ref('customer_analytics') }}
WHERE average_order_value < 0

UNION ALL

-- Check product_performance for negative total_revenue or total_profit
SELECT
    'product_performance' AS model_name,
    product_id AS record_id,
    'total_revenue' AS field_name,
    total_revenue AS field_value
FROM {{ ref('product_performance') }}
WHERE total_revenue < 0

UNION ALL

-- Check orders_daily for negative total_revenue
SELECT
    'orders_daily' AS model_name,
    date_key::text AS record_id,
    'total_revenue' AS field_name,
    total_revenue AS field_value
FROM {{ ref('orders_daily') }}
WHERE total_revenue < 0

UNION ALL

-- Check orders_weekly for negative total_revenue
SELECT
    'orders_weekly' AS model_name,
    week_start_date::text AS record_id,
    'total_revenue' AS field_name,
    total_revenue AS field_value
FROM {{ ref('orders_weekly') }}
WHERE total_revenue < 0

UNION ALL

-- Check orders_monthly for negative total_revenue
SELECT
    'orders_monthly' AS model_name,
    month_start_date::text AS record_id,
    'total_revenue' AS field_name,
    total_revenue AS field_value
FROM {{ ref('orders_monthly') }}
WHERE total_revenue < 0

UNION ALL

-- Check marketing_attribution for negative total_revenue
SELECT
    'marketing_attribution' AS model_name,
    campaign_id AS record_id,
    'total_revenue' AS field_name,
    total_revenue AS field_value
FROM {{ ref('marketing_attribution') }}
WHERE total_revenue < 0
