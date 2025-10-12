/*
  Singular test: Validates that campaign end_date >= start_date for all campaigns.

  Test Logic:
  - Checks all campaigns in campaign_metadata seed
  - Compares end_date to start_date
  - Returns rows where end_date < start_date (invalid date range)

  Expected Result: 0 rows (all campaigns have valid date ranges)
  If rows returned: Data quality issue - campaign has end date before start date
*/

SELECT
    campaign_id,
    campaign_name,
    start_date,
    end_date,
    end_date - start_date AS campaign_duration_days
FROM {{ ref('campaign_metadata') }}
WHERE end_date IS NOT NULL
  AND end_date < start_date
