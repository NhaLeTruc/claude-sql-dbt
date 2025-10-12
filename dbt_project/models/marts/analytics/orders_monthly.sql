/*
  Analytics mart: orders_monthly

  Purpose: Monthly time-series analytics aggregated from daily data.
  Materialization: Table (analytics-ready mart for BI tools)

  Business Use Cases:
  - Track monthly revenue and order trends
  - Calculate month-over-month growth rates
  - Analyze seasonal patterns and yearly cycles
  - Support monthly business reviews and planning
  - Compare performance across quarters and years
  - Forecast monthly targets and budgets

  Grain: One row per month (calendar month boundaries)

  Key Features:
  - Uses DATE_TRUNC('month', date) for first day of month
  - Aggregates from orders_daily for consistency
  - MoM growth calculation using LAG() window function
  - Average daily revenue for month-level intensity metric
  - Quarter aggregation for quarterly reporting

  Calendar Month Standard:
  - Month boundaries: 1st day to last day
  - Months numbered 1-12
  - Quarters: Q1 (Jan-Mar), Q2 (Apr-Jun), Q3 (Jul-Sep), Q4 (Oct-Dec)
*/

{{ config(
    materialized='table'
) }}

WITH daily_orders AS (
    SELECT *
    FROM {{ ref('orders_daily') }}
),

monthly_aggregates AS (
    SELECT
        -- Month boundaries
        DATE_TRUNC('month', date_key)::date AS month_start_date,

        -- Month identifiers
        MIN(EXTRACT(MONTH FROM date_key)) AS month,
        MIN(month_name) AS month_name,
        MIN(EXTRACT(QUARTER FROM date_key)) AS quarter,
        year,

        -- Count of days in month for average calculations
        COUNT(DISTINCT date_key) AS days_in_month,

        -- Aggregate order metrics from daily data
        SUM(total_orders) AS total_orders,
        SUM(total_revenue) AS total_revenue,
        SUM(total_units) AS total_units,
        SUM(unique_customers) AS unique_customers

    FROM daily_orders
    GROUP BY DATE_TRUNC('month', date_key)::date, year
),

monthly_with_avg AS (
    SELECT
        *,

        -- Average daily revenue for the month
        -- Uses actual days in month for accurate daily average
        CASE
            WHEN days_in_month > 0 THEN
                total_revenue / days_in_month
            ELSE 0
        END AS average_daily_revenue

    FROM monthly_aggregates
),

monthly_with_mom AS (
    SELECT
        *,

        -- Month-over-month revenue for previous month
        -- LAG() looks back 1 month in the ordered sequence
        LAG(total_revenue, 1) OVER (ORDER BY month_start_date) AS revenue_last_month,

        -- Calculate MoM growth percentage
        -- Formula: ((current - prior) / prior) * 100
        CASE
            WHEN LAG(total_revenue, 1) OVER (ORDER BY month_start_date) > 0 THEN
                ROUND(((total_revenue - LAG(total_revenue, 1) OVER (ORDER BY month_start_date)) /
                       LAG(total_revenue, 1) OVER (ORDER BY month_start_date) * 100)::numeric, 2)
            ELSE NULL
        END AS mom_growth_pct

    FROM monthly_with_avg
),

final AS (
    SELECT
        -- Month identifiers
        month_start_date,
        month,
        month_name,
        quarter,
        year,

        -- Order metrics
        total_orders,
        total_revenue,
        total_units,
        unique_customers,
        average_daily_revenue,

        -- Growth metric
        mom_growth_pct,

        -- Metadata
        CURRENT_TIMESTAMP AS dbt_updated_at

    FROM monthly_with_mom
)

SELECT * FROM final
