/*
  Analytics mart: marketing_attribution

  Purpose: Marketing campaign attribution analytics for ROI and channel optimization.
  Materialization: Table (analytics-ready mart for BI tools)

  Business Use Cases:
  - Calculate campaign ROI and profitability
  - Analyze customer acquisition costs (CAC) by channel
  - Compare lifetime value of customers by acquisition source
  - Optimize marketing budget allocation across channels
  - Track campaign performance and effectiveness
  - Identify best-performing campaigns and channels

  Grain: One row per campaign

  Attribution Model: First-Touch Attribution
  - Customer's first order determines campaign attribution
  - If first order has campaign_id, customer is attributed to that campaign
  - All subsequent orders from that customer contribute to campaign revenue
  - This models customer acquisition and long-term value generation

  Key Metrics:
  - Customers acquired: COUNT DISTINCT customers whose first order had this campaign_id
  - Total revenue: SUM of ALL orders from acquired customers (not just first order)
  - CAC (Cost per Acquisition): campaign_budget / customers_acquired
  - ROI: ((total_revenue - campaign_budget) / campaign_budget) * 100
  - Average LTV: Average lifetime value of acquired customers
*/

{{ config(
    materialized='table'
) }}

WITH campaigns AS (
    SELECT *
    FROM {{ ref('campaign_metadata') }}
),

customer_analytics AS (
    SELECT
        customer_id,
        lifetime_value
    FROM {{ ref('customer_analytics') }}
),

fact_orders AS (
    SELECT
        order_id,
        customer_key,
        order_date,
        campaign_id,
        order_total
    FROM {{ ref('fact_orders') }}
),

customers AS (
    SELECT
        customer_id,
        customer_key
    FROM {{ ref('dim_customers') }}
),

-- Identify each customer's first order with campaign attribution
first_orders AS (
    SELECT
        c.customer_id,
        fo.campaign_id AS first_touch_campaign_id,
        MIN(fo.order_date) AS first_order_date
    FROM fact_orders fo
    INNER JOIN customers c ON fo.customer_key = c.customer_key
    WHERE fo.campaign_id IS NOT NULL  -- Only consider orders with campaign attribution
    GROUP BY c.customer_id, fo.campaign_id
),

-- For each customer, get their earliest campaign attribution (first touch)
customer_first_campaign AS (
    SELECT
        customer_id,
        first_touch_campaign_id,
        first_order_date,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY first_order_date) AS rn
    FROM first_orders
),

customer_attribution AS (
    SELECT
        customer_id,
        first_touch_campaign_id AS attributed_campaign_id
    FROM customer_first_campaign
    WHERE rn = 1  -- Only keep first campaign per customer
),

-- Aggregate all orders from attributed customers per campaign
campaign_performance AS (
    SELECT
        ca.attributed_campaign_id AS campaign_id,

        -- Customer acquisition
        COUNT(DISTINCT ca.customer_id) AS customers_acquired,

        -- Order volume from acquired customers
        COUNT(DISTINCT fo.order_id) AS total_orders,

        -- Revenue from all orders by acquired customers
        SUM(fo.order_total) AS total_revenue,

        -- Average LTV of acquired customers
        AVG(cust_analytics.lifetime_value) AS average_customer_ltv

    FROM customer_attribution ca
    LEFT JOIN customers c ON ca.customer_id = c.customer_id
    LEFT JOIN fact_orders fo ON c.customer_key = fo.customer_key
    LEFT JOIN customer_analytics cust_analytics ON ca.customer_id = cust_analytics.customer_id
    GROUP BY ca.attributed_campaign_id
),

marketing_attribution AS (
    SELECT
        -- Campaign identifiers
        camp.campaign_id,
        camp.campaign_name,
        camp.channel,
        camp.start_date AS campaign_start_date,
        camp.end_date AS campaign_end_date,

        -- Campaign investment
        camp.budget AS campaign_budget,

        -- Performance metrics
        COALESCE(cp.customers_acquired, 0) AS customers_acquired,
        COALESCE(cp.total_orders, 0) AS total_orders,
        COALESCE(cp.total_revenue, 0) AS total_revenue,
        cp.average_customer_ltv,

        -- Customer acquisition cost (CAC)
        -- Formula: campaign_budget / customers_acquired
        CASE
            WHEN COALESCE(cp.customers_acquired, 0) > 0 THEN
                ROUND((camp.budget / cp.customers_acquired)::numeric, 2)
            ELSE NULL
        END AS cost_per_acquisition,

        -- Return on investment (ROI) percentage
        -- Formula: ((total_revenue - campaign_budget) / campaign_budget) * 100
        -- Positive = profitable, negative = loss
        CASE
            WHEN camp.budget > 0 AND COALESCE(cp.total_revenue, 0) > 0 THEN
                ROUND((((COALESCE(cp.total_revenue, 0) - camp.budget) / camp.budget) * 100)::numeric, 2)
            WHEN camp.budget > 0 AND COALESCE(cp.total_revenue, 0) = 0 THEN
                -100.00  -- Complete loss if no revenue
            ELSE NULL
        END AS return_on_investment_pct,

        -- Campaign status flag
        CASE
            WHEN camp.end_date IS NULL OR camp.end_date >= CURRENT_DATE THEN TRUE
            ELSE FALSE
        END AS is_active,

        -- Metadata
        CURRENT_TIMESTAMP AS dbt_updated_at

    FROM campaigns camp
    LEFT JOIN campaign_performance cp ON camp.campaign_id = cp.campaign_id
)

SELECT * FROM marketing_attribution
