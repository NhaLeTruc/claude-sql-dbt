/*
  Analysis: Campaign ROI Analysis and Performance Ranking

  Business Question: Which marketing campaigns deliver the best return on investment?

  Purpose:
  - Rank campaigns by ROI for budget allocation decisions
  - Identify high-performing channels for increased investment
  - Spot underperforming campaigns for optimization or termination
  - Calculate customer acquisition efficiency by channel
  - Support marketing budget planning and strategy

  Usage:
  - Run via: dbt compile --select analyses/campaign_roi_analysis
  - Execute compiled SQL in target/ directory against warehouse
  - Results show all campaigns ranked by ROI with key performance metrics

  Insights from Results:
  - Positive ROI = Profitable campaigns (revenue > cost)
  - Negative ROI = Loss-making campaigns (revenue < cost)
  - ROI > 200% = Highly efficient campaigns (3x return)
  - ROI between 0-100% = Break-even to modest return
  - ROI < 0% = Money-losing campaigns requiring action
  - Compare CAC (cost per acquisition) across channels
  - High CAC + High LTV = Sustainable if LTV > 3x CAC
  - Low CAC + Low LTV = Volume play requiring retention focus
  - Channel patterns reveal which channels work best for acquisition
*/

SELECT
    campaign_id,
    campaign_name,
    channel,
    campaign_start_date,
    campaign_end_date,
    is_active,

    -- Investment
    campaign_budget,

    -- Performance metrics
    customers_acquired,
    total_orders,
    total_revenue,
    average_customer_ltv,

    -- Efficiency metrics
    cost_per_acquisition,
    return_on_investment_pct,

    -- Performance classification
    CASE
        WHEN return_on_investment_pct IS NULL THEN 'No Conversions'
        WHEN return_on_investment_pct >= 200 THEN 'Highly Profitable'
        WHEN return_on_investment_pct >= 100 THEN 'Profitable'
        WHEN return_on_investment_pct >= 0 THEN 'Break-Even to Modest'
        WHEN return_on_investment_pct >= -50 THEN 'Loss-Making'
        ELSE 'Severe Loss'
    END AS roi_classification,

    -- LTV to CAC ratio (healthy = 3:1 or higher)
    CASE
        WHEN cost_per_acquisition > 0 AND average_customer_ltv IS NOT NULL THEN
            ROUND((average_customer_ltv / cost_per_acquisition)::numeric, 2)
        ELSE NULL
    END AS ltv_to_cac_ratio

FROM {{ ref('marketing_attribution') }}
ORDER BY return_on_investment_pct DESC NULLS LAST
