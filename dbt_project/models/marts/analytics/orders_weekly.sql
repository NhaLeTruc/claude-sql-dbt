/*
  Analytics mart: orders_weekly

  Purpose: Weekly time-series analytics aggregated from daily data.
  Materialization: Table (analytics-ready mart for BI tools)

  Business Use Cases:
  - Track weekly order trends smoothing out daily volatility
  - Calculate week-over-week growth rates
  - Analyze weekly revenue patterns and seasonality
  - Compare weeks across years (e.g., week 12 of 2023 vs 2024)
  - Support weekly forecasting and planning cycles

  Grain: One row per week (ISO week: Monday-Sunday)

  Key Features:
  - Uses DATE_TRUNC('week', date) for Monday start
  - Aggregates from orders_daily for consistency
  - WoW growth calculation using LAG() window function
  - Average daily revenue for week-level intensity metric

  ISO Week Standard:
  - Week starts Monday, ends Sunday
  - Week 1 contains first Thursday of year
  - Weeks numbered 1-53
*/

{{ config(
    materialized='table'
) }}

WITH daily_orders AS (
    SELECT *
    FROM {{ ref('orders_daily') }}
),

weekly_aggregates AS (
    SELECT
        -- Week boundaries (ISO week: Monday-Sunday)
        DATE_TRUNC('week', date_key)::date AS week_start_date,
        (DATE_TRUNC('week', date_key) + INTERVAL '6 days')::date AS week_end_date,

        -- Week identifiers (derived from week_start_date for consistency)
        MIN(EXTRACT(WEEK FROM date_key)) AS week_number,
        EXTRACT(YEAR FROM DATE_TRUNC('week', date_key)::date) AS year,

        -- Aggregate order metrics from daily data
        SUM(total_orders) AS total_orders,
        SUM(total_revenue) AS total_revenue,
        SUM(total_units) AS total_units,
        SUM(unique_customers) AS unique_customers,

        -- Average daily revenue for the week
        AVG(total_revenue) AS average_daily_revenue

    FROM daily_orders
    GROUP BY 1,2
),

weekly_with_wow AS (
    SELECT
        *,

        -- Week-over-week revenue for previous week
        -- LAG() looks back 1 week in the ordered sequence
        LAG(total_revenue, 1) OVER (ORDER BY week_start_date) AS revenue_last_week,

        -- Calculate WoW growth percentage
        -- Formula: ((current - prior) / prior) * 100
        CASE
            WHEN LAG(total_revenue, 1) OVER (ORDER BY week_start_date) > 0 THEN
                ROUND(((total_revenue - LAG(total_revenue, 1) OVER (ORDER BY week_start_date)) /
                       LAG(total_revenue, 1) OVER (ORDER BY week_start_date) * 100)::numeric, 2)
            ELSE NULL
        END AS wow_growth_pct

    FROM weekly_aggregates
),

final AS (
    SELECT
        -- Week identifiers
        week_start_date,
        week_end_date,
        week_number,
        year,

        -- Order metrics
        total_orders,
        total_revenue,
        total_units,
        unique_customers,
        average_daily_revenue,

        -- Growth metric
        wow_growth_pct,

        -- Metadata
        CURRENT_TIMESTAMP AS dbt_updated_at

    FROM weekly_with_wow
)

SELECT * FROM final
