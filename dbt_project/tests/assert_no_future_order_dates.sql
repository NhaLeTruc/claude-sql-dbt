/*
  Singular test: Validates that no orders have order_date in the future.

  Test Logic:
  - Checks all orders in staging model
  - Compares order_date to CURRENT_DATE
  - Returns rows where order_date > CURRENT_DATE

  Expected Result: 0 rows (all orders have valid historical dates)
  If rows returned: Data quality issue - orders incorrectly dated in the future
*/

SELECT
    order_id,
    order_date,
    CURRENT_DATE AS current_date,
    order_date - CURRENT_DATE AS days_in_future
FROM {{ ref('stg_ecommerce__orders') }}
WHERE order_date > CURRENT_DATE
