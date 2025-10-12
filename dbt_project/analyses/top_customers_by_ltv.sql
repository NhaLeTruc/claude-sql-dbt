/*
  Analysis: Top 10 Customers by Lifetime Value

  Business Question: Who are our most valuable customers based on total spending?

  Purpose:
  - Identify VIP customers for targeted retention programs
  - Understand characteristics of high-value customers
  - Support customer loyalty and rewards program decisions
  - Provide input for account management prioritization

  Usage:
  - Run via: dbt compile --select analyses/top_customers_by_ltv
  - Execute compiled SQL in target/ directory against warehouse
  - Results show top 10 customers ranked by lifetime_value

  Insights from Results:
  - Look for patterns in customer_segment (are VIPs concentrated in certain segments?)
  - Check total_orders to understand purchase frequency patterns
  - Compare average_order_value to identify big spenders vs frequent buyers
  - Use RFM scores to segment high-value customers by engagement level
*/

SELECT
    customer_id,
    customer_name,
    email,
    customer_segment,
    total_orders,
    lifetime_value,
    average_order_value,
    rfm_score,
    days_since_last_order,
    is_active
FROM {{ ref('customer_analytics') }}
WHERE lifetime_value > 0
ORDER BY lifetime_value DESC
LIMIT 10
