/*
  Dimension model: dim_date

  Purpose: Date dimension using date spine approach for complete date coverage.
  Materialization: Table (persistent calendar dimension)

  Business Context:
  - Provides one row per date from 2022-01-01 to 2024-12-31
  - Enables LEFT JOIN to ensure zero-sale days appear in time-series reports
  - Contains calendar attributes for grouping and filtering (day/week/month/quarter/year)
  - Includes weekend and holiday flags for business day analysis

  Date Spine Approach:
  - Uses generate_date_spine macro (wrapper around dbt_utils.date_spine)
  - Ensures continuous date range without gaps
  - Critical for accurate time-series analytics and forecasting

  Grain: One row per date
*/

{{ config(
    materialized='table'
) }}

WITH date_spine AS (
    -- Generate complete date range for data period
    {{ generate_date_spine(
        start_date="'2022-01-01'::date",
        end_date="'2024-12-31'::date"
    ) }}
),

date_dimension AS (
    SELECT
        -- Primary key
        date_day AS date_key,

        -- Day attributes
        EXTRACT(ISODOW FROM date_day) AS day_of_week,  -- 1=Monday, 7=Sunday
        TO_CHAR(date_day, 'Day') AS day_of_week_name,
        EXTRACT(DAY FROM date_day) AS day_of_month,
        EXTRACT(DOY FROM date_day) AS day_of_year,

        -- Week attributes
        EXTRACT(WEEK FROM date_day) AS week_of_year,

        -- Month attributes
        EXTRACT(MONTH FROM date_day) AS month,
        TO_CHAR(date_day, 'Month') AS month_name,

        -- Quarter and year
        EXTRACT(QUARTER FROM date_day) AS quarter,
        EXTRACT(YEAR FROM date_day) AS year,

        -- Weekend flag (Saturday=6, Sunday=7)
        CASE
            WHEN EXTRACT(ISODOW FROM date_day) IN (6, 7) THEN TRUE
            ELSE FALSE
        END AS is_weekend,

        -- Holiday flag (placeholder - can be expanded with actual holiday calendar)
        FALSE AS is_holiday

    FROM date_spine
)

SELECT * FROM date_dimension
