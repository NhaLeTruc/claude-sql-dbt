/*
Singular test: Validate customer lifetime_value equals sum of order totals

This test ensures data consistency between customer_analytics mart
and underlying order data. Returns failing rows where LTV doesn't match.

Test passes when query returns 0 rows.
Test fails when query returns any rows (data inconsistency).
*/

WITH customer_ltv AS (
    SELECT
        customer_id,
        lifetime_value
    FROM {{ ref('customer_analytics') }}
),

order_totals AS (
    SELECT
        customer_id,
        SUM(order_total) AS calculated_ltv
    FROM {{ ref('stg_ecommerce__orders') }}
    WHERE order_status NOT IN ('cancelled', 'returned')
    GROUP BY customer_id
),

comparison AS (
    SELECT
        COALESCE(c.customer_id, o.customer_id) AS customer_id,
        COALESCE(c.lifetime_value, 0) AS reported_ltv,
        COALESCE(o.calculated_ltv, 0) AS calculated_ltv,
        ABS(COALESCE(c.lifetime_value, 0) - COALESCE(o.calculated_ltv, 0)) AS difference
    FROM customer_ltv c
    FULL OUTER JOIN order_totals o
        ON c.customer_id = o.customer_id
)

-- Return rows where LTV doesn't match (allowing 0.01 tolerance for rounding)
SELECT
    customer_id,
    reported_ltv,
    calculated_ltv,
    difference
FROM comparison
WHERE difference > 0.01
