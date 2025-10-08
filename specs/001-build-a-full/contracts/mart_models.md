# Analytics Mart Model Contracts

**Purpose**: Define interfaces for business-ready analytics marts
**Date**: 2025-10-08

---

## Model: customer_analytics

**Purpose**: Provide comprehensive customer behavior analysis with RFM segmentation and lifetime value metrics
**Grain**: One row per customer (current snapshot)
**Materialization**: table
**User Story**: P1 - Customer Analytics Foundation

### Columns

| Column Name | Data Type | Nullable | Description | Business Rules |
|-------------|-----------|----------|-------------|----------------|
| customer_id | INTEGER | NO | Natural key from source system | UNIQUE, NOT NULL |
| customer_name | VARCHAR(255) | NO | Customer full name | NOT NULL |
| email | VARCHAR(255) | NO | Customer email address | NOT NULL |
| customer_segment | VARCHAR(50) | YES | Current segment classification | ACCEPTED_VALUES: ['new', 'active', 'at-risk', 'dormant', 'vip'] |
| signup_date | DATE | NO | Customer registration date | NOT NULL, <= CURRENT_DATE |
| first_order_date | DATE | YES | Date of first order | NULL if no orders, <= CURRENT_DATE |
| last_order_date | DATE | YES | Date of most recent order | NULL if no orders, <= CURRENT_DATE, >= first_order_date |
| days_since_last_order | INTEGER | YES | Recency metric (R in RFM) | NULL if no orders, >= 0 |
| total_orders | INTEGER | NO | Frequency metric (F in RFM) | NOT NULL, >= 0 |
| lifetime_value | DECIMAL(10,2) | NO | Monetary metric (M in RFM) | NOT NULL, >= 0 |
| average_order_value | DECIMAL(10,2) | YES | Average order size | NULL if no orders, >= 0 |
| rfm_score | INTEGER | YES | Combined RFM score (1-5, 5 = best) | NULL if no orders, BETWEEN 1 AND 5 |
| is_active | BOOLEAN | NO | Has ordered in last 90 days | NOT NULL |
| dbt_updated_at | TIMESTAMP | NO | ETL metadata timestamp | NOT NULL |

### Relationships

**Upstream Dependencies**:
- `ref('dim_customers')` - Customer master data
- `ref('int_customers__orders_agg')` - Aggregated order metrics per customer
- `ref('fact_orders')` - Order transactions (for validation)

**Downstream Consumers**:
- `marketing_attribution` - Uses lifetime_value for campaign ROI
- Analysis: `top_customers_by_ltv.sql`
- Exposure: `executive_dashboard`

### Tests Required

**Generic Tests**:
- `customer_id`: unique, not_null
- `email`: not_null
- `customer_segment`: accepted_values (['new', 'active', 'at-risk', 'dormant', 'vip'])
- `signup_date`: not_null
- `lifetime_value`: not_null (custom test: >= 0)
- `total_orders`: not_null (custom test: >= 0)
- `rfm_score`: custom test (BETWEEN 1 AND 5 WHERE rfm_score IS NOT NULL)

**Singular Tests**:
- `assert_customer_ltv_matches_orders.sql`: Validates lifetime_value = SUM(orders.order_total) for each customer

**Test Coverage**: >80% of columns (per constitution requirement for critical marts)

### Sample Query

```sql
-- Top 10 customers by lifetime value
SELECT
  customer_name,
  email,
  customer_segment,
  total_orders,
  lifetime_value,
  average_order_value,
  days_since_last_order,
  rfm_score
FROM {{ ref('customer_analytics') }}
WHERE lifetime_value > 0
ORDER BY lifetime_value DESC
LIMIT 10;

-- At-risk customers (high LTV but haven't ordered recently)
SELECT
  customer_name,
  email,
  lifetime_value,
  days_since_last_order,
  last_order_date
FROM {{ ref('customer_analytics') }}
WHERE customer_segment = 'at-risk'
  AND lifetime_value > 1000
ORDER BY lifetime_value DESC;
```

---

## Model: product_performance

**Purpose**: Track product sales performance with rankings and profitability metrics by category
**Grain**: One row per product
**Materialization**: table
**User Story**: P2 - Product Performance Analysis

### Columns

| Column Name | Data Type | Nullable | Description | Business Rules |
|-------------|-----------|----------|-------------|----------------|
| product_id | INTEGER | NO | Natural key from product catalog | UNIQUE, NOT NULL |
| product_name | VARCHAR(255) | NO | Product display name | NOT NULL |
| category | VARCHAR(100) | NO | Product category | NOT NULL, FK to product_categories seed |
| subcategory | VARCHAR(100) | YES | Product subcategory | NULL allowed |
| total_units_sold | INTEGER | NO | Total quantity sold to date | NOT NULL, >= 0 |
| total_revenue | DECIMAL(10,2) | NO | Total revenue generated | NOT NULL, >= 0 |
| total_profit | DECIMAL(10,2) | NO | Total profit (revenue - cost * quantity) | NOT NULL |
| profit_margin_pct | DECIMAL(5,2) | NO | Profit margin percentage | NOT NULL, BETWEEN 0 AND 100 |
| total_orders | INTEGER | NO | Distinct orders containing product | NOT NULL, >= 0 |
| average_unit_price | DECIMAL(10,2) | NO | Average selling price per unit | NOT NULL, >= 0 |
| category_rank | INTEGER | NO | Rank by revenue within category | NOT NULL, >= 1 |
| overall_rank | INTEGER | NO | Rank by revenue across all products | NOT NULL, >= 1, <= (count of products) |
| is_active | BOOLEAN | NO | Product currently available | NOT NULL |
| dbt_updated_at | TIMESTAMP | NO | ETL metadata timestamp | NOT NULL |

### Relationships

**Upstream Dependencies**:
- `ref('dim_products')` - Product master data
- `ref('int_products__sales_agg')` - Aggregated sales metrics per product
- `ref('fact_order_items')` - Order line items (for validation)

**Downstream Consumers**:
- Analysis: `product_sales_trends.sql`
- Exposure: `executive_dashboard`

### Tests Required

**Generic Tests**:
- `product_id`: unique, not_null
- `product_name`: not_null
- `category`: not_null, relationships (product_categories seed)
- `total_units_sold`: not_null (custom test: >= 0)
- `total_revenue`: not_null (custom test: >= 0)
- `profit_margin_pct`: not_null (custom test: BETWEEN 0 AND 100)
- `category_rank`: not_null (custom test: >= 1)
- `overall_rank`: not_null (custom test: >= 1)

**Singular Tests**:
- Custom test: total_revenue >= total_profit (profit cannot exceed revenue)
- Custom test: category_rank unique within each category

**Test Coverage**: >80% of columns

### Sample Query

```sql
-- Top 10 products by revenue
SELECT
  product_name,
  category,
  total_units_sold,
  total_revenue,
  total_profit,
  profit_margin_pct,
  overall_rank
FROM {{ ref('product_performance') }}
WHERE is_active = TRUE
ORDER BY total_revenue DESC
LIMIT 10;

-- Bottom 5 products by category (candidates for discontinuation)
SELECT
  product_name,
  category,
  total_units_sold,
  total_revenue,
  category_rank
FROM {{ ref('product_performance') }}
WHERE category_rank <= 5
  AND total_units_sold < 100
ORDER BY category, category_rank;
```

---

## Model: orders_daily

**Purpose**: Daily aggregations of order metrics for time-series analysis
**Grain**: One row per day (including zero-sale days via date spine)
**Materialization**: table
**User Story**: P3 - Time-Series Order Analytics

### Columns

| Column Name | Data Type | Nullable | Description | Business Rules |
|-------------|-----------|----------|-------------|----------------|
| date_key | DATE | NO | Date dimension primary key | UNIQUE, NOT NULL, BETWEEN '2022-01-01' AND '2024-12-31' |
| total_orders | INTEGER | NO | Orders placed on this day | NOT NULL, >= 0 |
| total_revenue | DECIMAL(10,2) | NO | Revenue generated on this day | NOT NULL, >= 0 |
| total_units | INTEGER | NO | Units sold on this day | NOT NULL, >= 0 |
| unique_customers | INTEGER | NO | Distinct customers who ordered | NOT NULL, >= 0 |
| average_order_value | DECIMAL(10,2) | YES | AOV for this day | NULL if total_orders = 0, >= 0 |
| cumulative_revenue_ytd | DECIMAL(10,2) | NO | Year-to-date cumulative revenue | NOT NULL, >= 0 |
| yoy_growth_pct | DECIMAL(5,2) | YES | Year-over-year growth percentage | NULL for first year data |
| dbt_updated_at | TIMESTAMP | NO | ETL metadata timestamp | NOT NULL |

### Relationships

**Upstream Dependencies**:
- `ref('dim_date')` - Date spine (ensures all dates present)
- `ref('int_orders__daily_agg')` - Daily order aggregations
- `ref('fact_orders')` - Order transactions

**Downstream Consumers**:
- `orders_weekly` - Aggregated from daily
- `orders_monthly` - Aggregated from daily
- Analysis: Time-series trend queries
- Exposure: `executive_dashboard`

### Tests Required

**Generic Tests**:
- `date_key`: unique, not_null
- `total_orders`: not_null (custom test: >= 0)
- `total_revenue`: not_null (custom test: >= 0)
- `cumulative_revenue_ytd`: not_null (custom test: >= 0)

**Singular Tests**:
- `assert_daily_totals_match_fact_orders.sql`: Validates SUM(orders_daily.total_revenue) = SUM(fact_orders.order_total)
- Custom test: cumulative_revenue_ytd is monotonically increasing within each year

**Test Coverage**: >80% of columns

### Sample Query

```sql
-- Last 30 days revenue trend
SELECT
  date_key,
  total_orders,
  total_revenue,
  average_order_value,
  unique_customers
FROM {{ ref('orders_daily') }}
WHERE date_key >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY date_key DESC;

-- Year-over-year comparison
SELECT
  EXTRACT(MONTH FROM date_key) AS month,
  EXTRACT(YEAR FROM date_key) AS year,
  SUM(total_revenue) AS monthly_revenue,
  AVG(yoy_growth_pct) AS avg_yoy_growth
FROM {{ ref('orders_daily') }}
GROUP BY 1, 2
ORDER BY 2, 1;
```

---

## Model: orders_weekly

**Purpose**: Weekly aggregations of order metrics for trend analysis
**Grain**: One row per week (start of week = Monday)
**Materialization**: table
**User Story**: P3 - Time-Series Order Analytics

### Columns

| Column Name | Data Type | Nullable | Description | Business Rules |
|-------------|-----------|----------|-------------|----------------|
| week_start_date | DATE | NO | Start of week (Monday) | UNIQUE, NOT NULL |
| week_end_date | DATE | NO | End of week (Sunday) | NOT NULL, = week_start_date + 6 days |
| week_number | INTEGER | NO | Week of year (1-53) | NOT NULL, BETWEEN 1 AND 53 |
| year | INTEGER | NO | Year | NOT NULL |
| total_orders | INTEGER | NO | Orders in week | NOT NULL, >= 0 |
| total_revenue | DECIMAL(10,2) | NO | Revenue in week | NOT NULL, >= 0 |
| total_units | INTEGER | NO | Units sold in week | NOT NULL, >= 0 |
| unique_customers | INTEGER | NO | Distinct customers in week | NOT NULL, >= 0 |
| average_order_value | DECIMAL(10,2) | YES | AOV for week | NULL if total_orders = 0 |
| wow_growth_pct | DECIMAL(5,2) | YES | Week-over-week growth % | NULL for first week |
| dbt_updated_at | TIMESTAMP | NO | ETL metadata timestamp | NOT NULL |

**Logic**: Aggregated from `orders_daily` with `DATE_TRUNC('week', date_key)`

---

## Model: orders_monthly

**Purpose**: Monthly aggregations of order metrics for trend and seasonality analysis
**Grain**: One row per month
**Materialization**: table
**User Story**: P3 - Time-Series Order Analytics

### Columns

| Column Name | Data Type | Nullable | Description | Business Rules |
|-------------|-----------|----------|-------------|----------------|
| month_start_date | DATE | NO | First day of month | UNIQUE, NOT NULL |
| month | INTEGER | NO | Month number (1-12) | NOT NULL, BETWEEN 1 AND 12 |
| month_name | VARCHAR(10) | NO | Month name ('January', ...) | NOT NULL |
| year | INTEGER | NO | Year | NOT NULL |
| total_orders | INTEGER | NO | Orders in month | NOT NULL, >= 0 |
| total_revenue | DECIMAL(10,2) | NO | Revenue in month | NOT NULL, >= 0 |
| total_units | INTEGER | NO | Units sold in month | NOT NULL, >= 0 |
| unique_customers | INTEGER | NO | Distinct customers in month | NOT NULL, >= 0 |
| average_order_value | DECIMAL(10,2) | YES | AOV for month | NULL if total_orders = 0 |
| mom_growth_pct | DECIMAL(5,2) | YES | Month-over-month growth % | NULL for first month |
| yoy_growth_pct | DECIMAL(5,2) | YES | Year-over-year growth % | NULL for first year |
| dbt_updated_at | TIMESTAMP | NO | ETL metadata timestamp | NOT NULL |

**Logic**: Aggregated from `orders_daily` with `DATE_TRUNC('month', date_key)`

---

## Model: marketing_attribution

**Purpose**: Track campaign performance, customer acquisition, and ROI by marketing channel
**Grain**: One row per campaign
**Materialization**: table
**User Story**: P4 - Marketing Campaign Attribution

### Columns

| Column Name | Data Type | Nullable | Description | Business Rules |
|-------------|-----------|----------|-------------|----------------|
| campaign_id | INTEGER | NO | Campaign identifier | UNIQUE, NOT NULL |
| campaign_name | VARCHAR(100) | NO | Campaign display name | NOT NULL |
| channel | VARCHAR(50) | NO | Marketing channel | NOT NULL, ACCEPTED_VALUES: ['email', 'social', 'search', 'display', 'affiliate', 'direct'] |
| campaign_budget | DECIMAL(10,2) | NO | Budget allocated (USD) | NOT NULL, > 0 |
| start_date | DATE | NO | Campaign launch date | NOT NULL |
| end_date | DATE | NO | Campaign end date | NOT NULL, >= start_date |
| customers_acquired | INTEGER | NO | Customers attributed (first-touch) | NOT NULL, >= 0 |
| total_orders | INTEGER | NO | Orders attributed to campaign | NOT NULL, >= 0 |
| total_revenue | DECIMAL(10,2) | NO | Revenue from attributed customers | NOT NULL, >= 0 |
| customer_lifetime_value | DECIMAL(10,2) | NO | Total LTV of acquired customers | NOT NULL, >= 0 |
| cost_per_acquisition | DECIMAL(10,2) | YES | CAC = budget / customers_acquired | NULL if customers_acquired = 0, >= 0 |
| return_on_investment | DECIMAL(5,2) | YES | ROI% = (revenue - budget) / budget * 100 | NULL if budget = 0 |
| is_active | BOOLEAN | NO | Campaign currently running | NOT NULL, = (end_date >= CURRENT_DATE) |
| dbt_updated_at | TIMESTAMP | NO | ETL metadata timestamp | NOT NULL |

### Relationships

**Upstream Dependencies**:
- `ref('campaign_metadata')` - Seed file with campaign details
- `ref('fact_orders')` - Orders with campaign attribution
- `ref('customer_analytics')` - Customer lifetime values

**Downstream Consumers**:
- Analysis: `campaign_roi_analysis.sql`
- Exposure: `marketing_dashboard`

### Tests Required

**Generic Tests**:
- `campaign_id`: unique, not_null
- `campaign_name`: not_null
- `channel`: not_null, accepted_values (['email', 'social', 'search', 'display', 'affiliate', 'direct'])
- `campaign_budget`: not_null (custom test: > 0)
- `start_date`: not_null
- `end_date`: not_null
- `customers_acquired`: not_null (custom test: >= 0)

**Singular Tests**:
- `assert_campaign_dates_valid.sql`: Validates end_date >= start_date for all campaigns
- Custom test: total_orders >= customers_acquired (can't have more orders than customers on first touch)

**Test Coverage**: >80% of columns

### Sample Query

```sql
-- Top 5 campaigns by ROI
SELECT
  campaign_name,
  channel,
  campaign_budget,
  customers_acquired,
  total_revenue,
  cost_per_acquisition,
  return_on_investment
FROM {{ ref('marketing_attribution') }}
WHERE customers_acquired > 0
ORDER BY return_on_investment DESC
LIMIT 5;

-- Campaign performance by channel
SELECT
  channel,
  COUNT(*) AS num_campaigns,
  SUM(campaign_budget) AS total_budget,
  SUM(customers_acquired) AS total_customers,
  SUM(total_revenue) AS total_revenue,
  AVG(return_on_investment) AS avg_roi
FROM {{ ref('marketing_attribution') }}
GROUP BY 1
ORDER BY total_revenue DESC;
```

---

## Contract Enforcement

All mart models MUST:
1. Implement ALL columns specified in contract
2. Pass ALL tests specified in contract
3. Maintain specified grain (one row per...)
4. Document purpose, assumptions, and business logic in schema.yml
5. Achieve >80% column test coverage (per constitution)

Breaking changes to contracts require:
- Impact analysis of downstream consumers
- Version bump in contract file
- Communication to stakeholders
- Migration plan for dependent models/analyses/exposures
