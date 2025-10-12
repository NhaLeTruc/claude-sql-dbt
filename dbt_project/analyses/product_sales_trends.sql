/*
  Analysis: Product Sales Trends and Performance

  Business Question: Which products are growing vs declining, and what are the top/bottom performers?

  Purpose:
  - Identify trending products for inventory planning
  - Spot declining products for promotional campaigns or discontinuation
  - Understand product mix performance by category
  - Support merchandising and buying decisions
  - Inform pricing and markdown strategies

  Usage:
  - Run via: dbt compile --select analyses/product_sales_trends
  - Execute compiled SQL in target/ directory against warehouse
  - Results show products sorted by revenue with profitability metrics

  Insights from Results:
  - High revenue + high profit margin = Star products (promote heavily)
  - High revenue + low profit margin = Volume drivers (optimize costs)
  - Low revenue + high profit margin = Niche products (targeted marketing)
  - Low revenue + low profit margin = Candidates for discontinuation
  - Category rank shows competitive position within category
  - Profit margin trends indicate pricing power and cost pressures
*/

SELECT
    product_id,
    product_name,
    sku,
    category,
    subcategory,
    total_units_sold,
    total_revenue,
    total_profit,
    total_orders,
    average_unit_price,
    profit_margin_pct,
    category_rank,
    is_active,

    -- Performance classification
    CASE
        WHEN total_revenue >= 10000 AND profit_margin_pct >= 30 THEN 'Star Product'
        WHEN total_revenue >= 10000 AND profit_margin_pct < 30 THEN 'Volume Driver'
        WHEN total_revenue < 10000 AND profit_margin_pct >= 30 THEN 'Niche Product'
        WHEN total_revenue < 10000 AND profit_margin_pct < 30 THEN 'Low Performer'
        ELSE 'Unclassified'
    END AS performance_classification

FROM {{ ref('product_performance') }}
WHERE total_revenue > 0  -- Only show products with sales
ORDER BY total_revenue DESC
LIMIT 50
