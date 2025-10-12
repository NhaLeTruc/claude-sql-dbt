/*
  Analytics mart: orders_daily

  Purpose: Daily time-series analytics for order trends and forecasting.
  Materialization: Table (analytics-ready mart for BI tools)

  Business Use Cases:
  - Track daily order volume and revenue trends
  - Identify seasonality patterns and weekly cycles
  - Calculate year-over-year growth rates
  - Forecast future demand based on historical patterns
  - Analyze weekend vs weekday performance
  - Monitor zero-sale days and business disruptions

  Grain: One row per date (2022-01-01 to 2024-12-31)

  Key Features:
  - Complete date spine coverage (includes zero-sale days)
  - YoY growth calculation using LAG() window function
  - Cumulative YTD revenue using SUM() OVER window function
  - Weekend flag for day-of-week analysis

  Window Functions:
  - LAG(metric, 365) for year-over-year comparisons
  - SUM() OVER (PARTITION BY year ORDER BY date) for YTD cumulative
*/

{{ config(
    materialized='table'
) }}

WITH date_spine AS (
    SELECT *
    FROM {{ ref('dim_date') }}
),

daily_orders AS (
    SELECT *
    FROM {{ ref('int_orders__daily_agg') }}
),

daily_with_dates AS (
    -- LEFT JOIN ensures all dates present, even zero-sale days
    SELECT
        d.date_key,
        d.day_of_week_name,
        d.month_name,
        d.year,
        d.is_weekend,

        -- Order metrics (COALESCE to 0 for zero-sale days)
        COALESCE(o.total_orders, 0) AS total_orders,
        COALESCE(o.total_revenue, 0) AS total_revenue,
        COALESCE(o.total_units, 0) AS total_units,
        COALESCE(o.unique_customers, 0) AS unique_customers,
        o.average_order_value  -- NULL for zero-sale days

    FROM date_spine d
    LEFT JOIN daily_orders o ON d.date_key = o.date_key
),

daily_with_calculations AS (
    SELECT
        *,

        -- Cumulative year-to-date revenue
        -- Window function: SUM() OVER resets each year, orders by date
        SUM(total_revenue) OVER (
            PARTITION BY year
            ORDER BY date_key
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue_ytd,

        -- Year-over-year revenue for same date last year
        -- LAG(metric, 365) looks back exactly 365 days
        LAG(total_revenue, 365) OVER (ORDER BY date_key) AS revenue_last_year

    FROM daily_with_dates
),

daily_with_yoy AS (
    SELECT
        *,

        -- Calculate YoY growth percentage
        -- Formula: ((current - prior) / prior) * 100
        CASE
            WHEN revenue_last_year > 0 THEN
                ROUND(((total_revenue - revenue_last_year) / revenue_last_year * 100)::numeric, 2)
            ELSE NULL
        END AS yoy_growth_pct

    FROM daily_with_calculations
),

final AS (
    SELECT
        -- Date attributes
        date_key,
        day_of_week_name,
        month_name,
        year,

        -- Order metrics
        total_orders,
        total_revenue,
        total_units,
        unique_customers,
        average_order_value,

        -- Calculated metrics
        cumulative_revenue_ytd,
        yoy_growth_pct,

        -- Date flags
        is_weekend,

        -- Metadata
        CURRENT_TIMESTAMP AS dbt_updated_at

    FROM daily_with_yoy
)

SELECT * FROM final
