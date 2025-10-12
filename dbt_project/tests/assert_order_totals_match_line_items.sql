/*
  Singular test: Validates that order_total in orders table equals the sum of line_total from order_items.

  Test Logic:
  - Joins orders to aggregated order_items
  - Calculates difference between order_total and SUM(line_total)
  - Returns rows where difference exceeds $0.01 (to account for floating point precision)

  Expected Result: 0 rows (all order totals match line item sums)
  If rows returned: Data integrity issue between orders and order_items tables
*/

WITH order_aggregates AS (
    -- Aggregate line items per order
    SELECT
        order_id,
        SUM(line_total) AS calculated_order_total
    FROM {{ ref('stg_ecommerce__order_items') }}
    GROUP BY order_id
),

order_comparison AS (
    -- Compare order header total to calculated total from line items
    SELECT
        o.order_id,
        o.order_total AS header_order_total,
        COALESCE(oa.calculated_order_total, 0) AS line_items_order_total,
        ABS(o.order_total - COALESCE(oa.calculated_order_total, 0)) AS difference
    FROM {{ ref('stg_ecommerce__orders') }} o
    LEFT JOIN order_aggregates oa ON o.order_id = oa.order_id
)

-- Return rows where order totals don't match (allowing $0.01 tolerance for rounding)
SELECT
    order_id,
    header_order_total,
    line_items_order_total,
    difference
FROM order_comparison
WHERE difference > 0.01
