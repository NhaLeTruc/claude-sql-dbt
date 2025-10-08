# Data Model: E-Commerce Analytics dbt Demo

**Phase**: 1 - Design & Data Modeling
**Date**: 2025-10-08
**Feature**: [spec.md](spec.md)
**Research**: [research.md](research.md)

## Overview

This document defines the complete data model for the e-commerce analytics dbt project, including source schemas, staging models, intermediate models, dimensional models, fact tables, and analytics marts. All schemas follow constitution requirements for test coverage, documentation, and data quality.

---

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                     Analytics Marts                          │
│  (customer_analytics, product_performance, orders_daily,    │
│   orders_weekly, orders_monthly, marketing_attribution)     │
└──────────────────┬──────────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────────┐
│              Dimensional Models & Facts                      │
│  (dim_customers, dim_products, dim_date,                    │
│   fact_orders, fact_order_items)                            │
└──────────────────┬──────────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────────┐
│              Intermediate Models                             │
│  (int_customers__orders_agg, int_products__sales_agg,       │
│   int_orders__daily_agg)                                    │
└──────────────────┬──────────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────────┐
│                 Staging Models                               │
│  (stg_ecommerce__customers, stg_ecommerce__orders,          │
│   stg_ecommerce__order_items, stg_ecommerce__products)      │
└──────────────────┬──────────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────────┐
│                  Raw Sources                                 │
│  (raw_data.customers, raw_data.orders,                      │
│   raw_data.order_items, raw_data.products,                  │
│   raw_data.campaigns - seed)                                │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. Source Schemas (Raw Data)

### 1.1 raw_data.customers

**Purpose**: Customer master data from CRM system
**Grain**: One row per customer
**Load Strategy**: Mock data via SQL INSERT (docker postgres init script)

| Column Name | Data Type | Nullable | Description | Validation Rules |
|-------------|-----------|----------|-------------|------------------|
| customer_id | INTEGER | NOT NULL | Unique customer identifier (PK) | UNIQUE, NOT NULL |
| email | VARCHAR(255) | NOT NULL | Customer email address | NOT NULL, FORMAT: email |
| name | VARCHAR(255) | NOT NULL | Customer full name | NOT NULL |
| signup_date | DATE | NOT NULL | Date customer registered | NOT NULL, <= CURRENT_DATE |
| segment | VARCHAR(50) | NULL | Customer segment classification | ACCEPTED_VALUES: ['new', 'active', 'at-risk', 'dormant', 'vip'] |
| state | VARCHAR(2) | NULL | US state code | LENGTH = 2 |
| country | VARCHAR(50) | NOT NULL | Country name | NOT NULL, DEFAULT: 'USA' |
| updated_at | TIMESTAMP | NOT NULL | Last update timestamp (for snapshots) | NOT NULL |

**Business Rules**:
- `customer_id` is surrogate key from source system
- `signup_date` cannot be in the future
- `segment` can be NULL for brand new customers (assigned later)

**Test Data Volume**: 10,000 customers

---

### 1.2 raw_data.orders

**Purpose**: Order header data from order management system
**Grain**: One row per order
**Load Strategy**: Mock data via SQL INSERT

| Column Name | Data Type | Nullable | Description | Validation Rules |
|-------------|-----------|----------|-------------|------------------|
| order_id | INTEGER | NOT NULL | Unique order identifier (PK) | UNIQUE, NOT NULL |
| customer_id | INTEGER | NOT NULL | FK to customers | NOT NULL, RELATIONSHIPS: raw_data.customers |
| order_date | DATE | NOT NULL | Date order was placed | NOT NULL, <= CURRENT_DATE |
| order_status | VARCHAR(50) | NOT NULL | Current order status | NOT NULL, ACCEPTED_VALUES: ['pending', 'processing', 'shipped', 'delivered', 'cancelled', 'returned'] |
| order_total | DECIMAL(10,2) | NOT NULL | Total order amount (USD) | NOT NULL, >= 0 |
| campaign_id | INTEGER | NULL | FK to campaigns (attribution) | NULL allowed (organic orders) |
| created_at | TIMESTAMP | NOT NULL | Order creation timestamp | NOT NULL |
| updated_at | TIMESTAMP | NOT NULL | Last update timestamp | NOT NULL |

**Business Rules**:
- `order_total` must be non-negative (>= 0)
- `order_total` should equal SUM(order_items.line_total) for that order (validated in singular test)
- `order_status` transitions: pending → processing → shipped → delivered (or cancelled/returned at any point)
- `campaign_id` NULL indicates organic (non-campaign) order

**Test Data Volume**: 50,000 orders (average 5 per customer)

---

### 1.3 raw_data.order_items

**Purpose**: Line items for each order
**Grain**: One row per product per order
**Load Strategy**: Mock data via SQL INSERT

| Column Name | Data Type | Nullable | Description | Validation Rules |
|-------------|-----------|----------|-------------|------------------|
| order_item_id | INTEGER | NOT NULL | Unique line item identifier (PK) | UNIQUE, NOT NULL |
| order_id | INTEGER | NOT NULL | FK to orders | NOT NULL, RELATIONSHIPS: raw_data.orders |
| product_id | INTEGER | NOT NULL | FK to products | NOT NULL, RELATIONSHIPS: raw_data.products |
| quantity | INTEGER | NOT NULL | Quantity ordered | NOT NULL, > 0 |
| unit_price | DECIMAL(10,2) | NOT NULL | Price per unit (USD) | NOT NULL, >= 0 |
| discount | DECIMAL(10,2) | NOT NULL | Discount applied (USD) | NOT NULL, >= 0, <= (quantity * unit_price) |
| line_total | DECIMAL(10,2) | NOT NULL | Total for line item (USD) | NOT NULL, >= 0, = (quantity * unit_price - discount) |

**Business Rules**:
- `quantity` must be positive integer (> 0)
- `line_total` = `quantity` * `unit_price` - `discount` (validated in singular test)
- `discount` cannot exceed `quantity * unit_price`
- All monetary values non-negative

**Test Data Volume**: 150,000 order items (average 3 per order)

---

### 1.4 raw_data.products

**Purpose**: Product catalog from inventory system
**Grain**: One row per product
**Load Strategy**: Mock data via SQL INSERT

| Column Name | Data Type | Nullable | Description | Validation Rules |
|-------------|-----------|----------|-------------|------------------|
| product_id | INTEGER | NOT NULL | Unique product identifier (PK) | UNIQUE, NOT NULL |
| product_name | VARCHAR(255) | NOT NULL | Product display name | NOT NULL |
| sku | VARCHAR(100) | NOT NULL | Stock keeping unit code | NOT NULL, UNIQUE |
| category | VARCHAR(100) | NOT NULL | Product category | NOT NULL, FK to seed: product_categories |
| subcategory | VARCHAR(100) | NULL | Product subcategory | NULL allowed |
| unit_cost | DECIMAL(10,2) | NOT NULL | Cost to produce/acquire (USD) | NOT NULL, >= 0 |
| list_price | DECIMAL(10,2) | NOT NULL | Retail list price (USD) | NOT NULL, >= unit_cost |
| is_active | BOOLEAN | NOT NULL | Product active status | NOT NULL, DEFAULT: TRUE |
| updated_at | TIMESTAMP | NOT NULL | Last update timestamp | NOT NULL |

**Business Rules**:
- `sku` must be unique across all products
- `list_price` >= `unit_cost` (profit margin validation)
- `category` must exist in `product_categories` seed (FK)
- `is_active = FALSE` for discontinued products

**Test Data Volume**: 100 products across 5 categories

---

### 1.5 Seeds: product_categories.csv

**Purpose**: Reference data for product categories
**Grain**: One row per category
**Load Strategy**: dbt seed

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| category_id | INTEGER | Unique category identifier |
| category_name | VARCHAR(100) | Category display name |
| category_description | TEXT | Category description for reporting |

**Sample Data**:
```csv
category_id,category_name,category_description
1,Electronics,"Consumer electronics and gadgets"
2,Clothing,"Apparel and fashion accessories"
3,Home & Garden,"Home improvement and outdoor living"
4,Books,"Physical and digital books"
5,Toys,"Children's toys and games"
```

---

### 1.6 Seeds: campaign_metadata.csv

**Purpose**: Marketing campaign reference data
**Grain**: One row per campaign
**Load Strategy**: dbt seed

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| campaign_id | INTEGER | Unique campaign identifier |
| campaign_name | VARCHAR(100) | Campaign display name |
| channel | VARCHAR(50) | Marketing channel |
| start_date | DATE | Campaign start date |
| end_date | DATE | Campaign end date |
| budget | DECIMAL(10,2) | Campaign budget (USD) |

**Sample Data** (10 campaigns across 6 channels):
- email, social, search, display, affiliate, direct
- Budget range: $5,000 - $50,000 per campaign
- Date range: 2022-01-01 to 2024-12-31

---

## 2. Staging Models

**Purpose**: Standardize raw sources (rename, cast, basic transformations)
**Materialization**: VIEW (per constitution)
**Naming Convention**: `stg_<source>__<entity>`

### 2.1 stg_ecommerce__customers

**Source**: `raw_data.customers`
**Transformations**:
- Rename columns to standard naming (snake_case)
- Cast types for consistency
- Add `dbt_updated_at` for metadata

```sql
WITH source AS (
  SELECT * FROM {{ source('raw_data', 'customers') }}
)

SELECT
  customer_id,
  email,
  name AS customer_name,
  signup_date,
  segment AS customer_segment,
  state,
  country,
  updated_at AS source_updated_at,
  CURRENT_TIMESTAMP AS dbt_updated_at
FROM source
```

**Tests** (in `_stg_ecommerce__sources.yml`):
- `customer_id`: unique, not_null
- `email`: not_null
- `customer_name`: not_null
- `signup_date`: not_null
- `customer_segment`: accepted_values: ['new', 'active', 'at-risk', 'dormant', 'vip']
- Freshness: warn_after: 24 hours, error_after: 48 hours

---

### 2.2 stg_ecommerce__orders

**Source**: `raw_data.orders`
**Transformations**:
- Rename columns
- Cast dates/timestamps
- Add surrogate key for joins

```sql
WITH source AS (
  SELECT * FROM {{ source('raw_data', 'orders') }}
)

SELECT
  order_id,
  customer_id,
  order_date,
  order_status,
  order_total,
  campaign_id,
  created_at,
  updated_at AS source_updated_at,
  CURRENT_TIMESTAMP AS dbt_updated_at
FROM source
```

**Tests**:
- `order_id`: unique, not_null
- `customer_id`: not_null, relationships: stg_ecommerce__customers
- `order_date`: not_null
- `order_status`: not_null, accepted_values: ['pending', 'processing', 'shipped', 'delivered', 'cancelled', 'returned']
- `order_total`: not_null (custom test: >= 0)

---

### 2.3 stg_ecommerce__order_items

**Source**: `raw_data.order_items`
**Transformations**:
- Rename columns
- Calculate profit margin
- Add metadata

```sql
WITH source AS (
  SELECT * FROM {{ source('raw_data', 'order_items') }}
)

SELECT
  order_item_id,
  order_id,
  product_id,
  quantity,
  unit_price,
  discount,
  line_total,
  (line_total - (quantity * (SELECT unit_cost FROM {{ source('raw_data', 'products') }} p WHERE p.product_id = source.product_id))) AS line_profit,
  CURRENT_TIMESTAMP AS dbt_updated_at
FROM source
```

**Tests**:
- `order_item_id`: unique, not_null
- `order_id`: not_null, relationships: stg_ecommerce__orders
- `product_id`: not_null, relationships: stg_ecommerce__products
- `quantity`: not_null (custom test: > 0)
- `line_total`: not_null (custom test: >= 0)

---

### 2.4 stg_ecommerce__products

**Source**: `raw_data.products`
**Transformations**:
- Rename columns
- Join to seed for category details
- Calculate margin percentage

```sql
WITH source AS (
  SELECT * FROM {{ source('raw_data', 'products') }}
)

SELECT
  product_id,
  product_name,
  sku,
  category,
  subcategory,
  unit_cost,
  list_price,
  ((list_price - unit_cost) / NULLIF(list_price, 0)) * 100 AS profit_margin_pct,
  is_active,
  updated_at AS source_updated_at,
  CURRENT_TIMESTAMP AS dbt_updated_at
FROM source
```

**Tests**:
- `product_id`: unique, not_null
- `sku`: unique, not_null
- `product_name`: not_null
- `category`: not_null, relationships: product_categories seed
- `list_price`: not_null (custom test: >= unit_cost)

---

## 3. Intermediate Models

**Purpose**: Business logic transformations, aggregations for reuse
**Materialization**: EPHEMERAL or VIEW (case-by-case)
**Naming Convention**: `int_<entity>__<verb>`

### 3.1 int_customers__orders_agg

**Purpose**: Aggregate order metrics per customer for downstream models
**Grain**: One row per customer
**Materialization**: EPHEMERAL (only used once in dim_customers)

**Columns**:
- `customer_id` (INTEGER, NOT NULL, PK)
- `first_order_date` (DATE): First order placed
- `last_order_date` (DATE): Most recent order
- `total_orders` (INTEGER): Count of orders
- `total_order_value` (DECIMAL(10,2)): Sum of order totals
- `average_order_value` (DECIMAL(10,2)): Average order total
- `days_since_last_order` (INTEGER): Recency metric

**Logic**:
```sql
SELECT
  customer_id,
  MIN(order_date) AS first_order_date,
  MAX(order_date) AS last_order_date,
  COUNT(DISTINCT order_id) AS total_orders,
  SUM(order_total) AS total_order_value,
  AVG(order_total) AS average_order_value,
  {{ calculate_days_between('MAX(order_date)', 'CURRENT_DATE') }} AS days_since_last_order
FROM {{ ref('stg_ecommerce__orders') }}
WHERE order_status NOT IN ('cancelled', 'returned')  -- Exclude cancelled orders from LTV
GROUP BY 1
```

---

### 3.2 int_products__sales_agg

**Purpose**: Aggregate sales metrics per product
**Grain**: One row per product
**Materialization**: VIEW (used by multiple downstream models)

**Columns**:
- `product_id` (INTEGER, NOT NULL, PK)
- `total_units_sold` (INTEGER): Total quantity sold
- `total_revenue` (DECIMAL(10,2)): Total revenue generated
- `total_profit` (DECIMAL(10,2)): Total profit (revenue - cost)
- `total_orders` (INTEGER): Number of distinct orders
- `average_unit_price` (DECIMAL(10,2)): Average selling price

**Logic**:
```sql
SELECT
  oi.product_id,
  SUM(oi.quantity) AS total_units_sold,
  SUM(oi.line_total) AS total_revenue,
  SUM(oi.line_profit) AS total_profit,
  COUNT(DISTINCT oi.order_id) AS total_orders,
  AVG(oi.unit_price) AS average_unit_price
FROM {{ ref('stg_ecommerce__order_items') }} oi
INNER JOIN {{ ref('stg_ecommerce__orders') }} o
  ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('cancelled', 'returned')
GROUP BY 1
```

---

### 3.3 int_orders__daily_agg

**Purpose**: Daily order aggregations for time-series models
**Grain**: One row per day
**Materialization**: VIEW

**Columns**:
- `order_date` (DATE, NOT NULL, PK)
- `total_orders` (INTEGER): Orders placed that day
- `total_revenue` (DECIMAL(10,2)): Revenue that day
- `total_units` (INTEGER): Units sold that day
- `unique_customers` (INTEGER): Distinct customers that day

**Logic**:
```sql
SELECT
  order_date,
  COUNT(DISTINCT order_id) AS total_orders,
  SUM(order_total) AS total_revenue,
  (SELECT SUM(quantity) FROM {{ ref('stg_ecommerce__order_items') }} WHERE order_id IN (SELECT order_id FROM {{ ref('stg_ecommerce__orders') }} WHERE order_date = o.order_date)) AS total_units,
  COUNT(DISTINCT customer_id) AS unique_customers
FROM {{ ref('stg_ecommerce__orders') }} o
WHERE order_status NOT IN ('cancelled', 'returned')
GROUP BY 1
```

---

## 4. Dimensional Models

**Purpose**: Conformed dimensions for dimensional modeling
**Materialization**: TABLE (per constitution)
**Naming Convention**: `dim_<entity>`

### 4.1 dim_customers

**Purpose**: Customer dimension with current attributes
**Grain**: One row per customer (current snapshot)
**Materialization**: TABLE
**SCD Type**: Type 1 (overwrite) in dim, Type 2 in snapshot

**Columns**:
| Column Name | Data Type | Description | Tests |
|-------------|-----------|-------------|-------|
| customer_key | VARCHAR(64) | Surrogate key (hash of customer_id) | unique, not_null |
| customer_id | INTEGER | Natural key from source | not_null, relationships |
| customer_name | VARCHAR(255) | Full name | not_null |
| email | VARCHAR(255) | Email address | not_null |
| customer_segment | VARCHAR(50) | Current segment | accepted_values |
| state | VARCHAR(2) | State code | - |
| country | VARCHAR(50) | Country | not_null |
| signup_date | DATE | Registration date | not_null |
| is_active | BOOLEAN | Customer has orders | not_null |
| dbt_updated_at | TIMESTAMP | ETL timestamp | not_null |

**Logic**:
```sql
WITH customers AS (
  SELECT * FROM {{ ref('stg_ecommerce__customers') }}
),

orders_agg AS (
  SELECT * FROM {{ ref('int_customers__orders_agg') }}
)

SELECT
  {{ dbt_utils.surrogate_key(['c.customer_id']) }} AS customer_key,
  c.customer_id,
  c.customer_name,
  c.email,
  c.customer_segment,
  c.state,
  c.country,
  c.signup_date,
  CASE WHEN oa.total_orders > 0 THEN TRUE ELSE FALSE END AS is_active,
  CURRENT_TIMESTAMP AS dbt_updated_at
FROM customers c
LEFT JOIN orders_agg oa ON c.customer_id = oa.customer_id
```

---

### 4.2 dim_products

**Purpose**: Product dimension with category hierarchy
**Grain**: One row per product
**Materialization**: TABLE

**Columns**:
| Column Name | Data Type | Description | Tests |
|-------------|-----------|-------------|-------|
| product_key | VARCHAR(64) | Surrogate key | unique, not_null |
| product_id | INTEGER | Natural key | not_null, unique |
| product_name | VARCHAR(255) | Display name | not_null |
| sku | VARCHAR(100) | SKU code | not_null, unique |
| category | VARCHAR(100) | Product category | not_null |
| subcategory | VARCHAR(100) | Subcategory | - |
| unit_cost | DECIMAL(10,2) | Cost per unit | not_null, >= 0 |
| list_price | DECIMAL(10,2) | Retail price | not_null, >= unit_cost |
| profit_margin_pct | DECIMAL(5,2) | Margin percentage | not_null |
| is_active | BOOLEAN | Active status | not_null |
| dbt_updated_at | TIMESTAMP | ETL timestamp | not_null |

---

### 4.3 dim_date

**Purpose**: Date dimension / spine for time-series analysis
**Grain**: One row per day (2022-01-01 to 2024-12-31)
**Materialization**: TABLE
**Generation**: dbt_utils.date_spine macro

**Columns**:
| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| date_key | DATE | Date (PK) |
| day_of_week | INTEGER | 1-7 (Mon-Sun) |
| day_of_week_name | VARCHAR(10) | 'Monday', 'Tuesday', ... |
| day_of_month | INTEGER | 1-31 |
| day_of_year | INTEGER | 1-366 |
| week_of_year | INTEGER | 1-53 |
| month | INTEGER | 1-12 |
| month_name | VARCHAR(10) | 'January', ... |
| quarter | INTEGER | 1-4 |
| year | INTEGER | 2022, 2023, 2024 |
| is_weekend | BOOLEAN | TRUE for Sat/Sun |
| is_holiday | BOOLEAN | Major US holidays (manual flag) |

**Logic**:
```sql
{{ dbt_utils.date_spine(
    datepart="day",
    start_date="cast('2022-01-01' as date)",
    end_date="cast('2024-12-31' as date)"
) }}
```

---

## 5. Fact Tables

**Purpose**: Transactional facts for analytics
**Materialization**: TABLE or INCREMENTAL
**Naming Convention**: `fact_<entity>`

### 5.1 fact_orders

**Purpose**: Order header facts
**Grain**: One row per order
**Materialization**: TABLE

**Columns**:
| Column Name | Data Type | Description | FK Reference |
|-------------|-----------|-------------|--------------|
| order_id | INTEGER | PK from source | - |
| customer_key | VARCHAR(64) | FK to dim_customers | dim_customers.customer_key |
| date_key | DATE | FK to dim_date | dim_date.date_key |
| order_date | DATE | Order date | - |
| order_status | VARCHAR(50) | Current status | - |
| order_total | DECIMAL(10,2) | Total amount | - |
| campaign_id | INTEGER | Campaign FK (NULL allowed) | - |
| dbt_updated_at | TIMESTAMP | ETL timestamp | - |

**Tests**:
- `order_id`: unique, not_null
- `customer_key`: not_null, relationships: dim_customers
- `date_key`: not_null, relationships: dim_date
- `order_total`: not_null, >= 0

---

### 5.2 fact_order_items

**Purpose**: Line item facts
**Grain**: One row per order item
**Materialization**: INCREMENTAL (demonstrates incremental models)
**Unique Key**: `order_item_id`
**Incremental Strategy**: append (new orders only)

**Columns**:
| Column Name | Data Type | Description | FK Reference |
|-------------|-----------|-------------|--------------|
| order_item_id | INTEGER | PK from source | - |
| order_id | INTEGER | FK to fact_orders | fact_orders.order_id |
| product_key | VARCHAR(64) | FK to dim_products | dim_products.product_key |
| quantity | INTEGER | Units ordered | - |
| unit_price | DECIMAL(10,2) | Price per unit | - |
| discount | DECIMAL(10,2) | Discount applied | - |
| line_total | DECIMAL(10,2) | Line total revenue | - |
| line_profit | DECIMAL(10,2) | Line total profit | - |
| dbt_updated_at | TIMESTAMP | ETL timestamp | - |

**Incremental Logic**:
```sql
{% if is_incremental() %}
  WHERE order_id > (SELECT MAX(order_id) FROM {{ this }})
{% endif %}
```

**Tests**:
- `order_item_id`: unique, not_null
- `order_id`: not_null, relationships: fact_orders
- `product_key`: not_null, relationships: dim_products
- `quantity`: not_null, > 0
- `line_total`: not_null, >= 0

---

## 6. Analytics Marts

**Purpose**: Business-ready analytics tables
**Materialization**: TABLE (per constitution)
**Naming Convention**: `<entity>_<grain>` or `<domain>_<entity>`

### 6.1 customer_analytics

**Purpose**: Customer RFM analysis and lifetime value
**Grain**: One row per customer
**User Story**: P1 - Customer Analytics Foundation

**Columns**:
| Column Name | Data Type | Description | Business Meaning |
|-------------|-----------|-------------|------------------|
| customer_id | INTEGER | Natural key | Customer identifier |
| customer_name | VARCHAR(255) | Full name | Display name |
| email | VARCHAR(255) | Email address | Contact email |
| customer_segment | VARCHAR(50) | Current segment | VIP, active, at-risk, etc. |
| signup_date | DATE | Registration date | When customer signed up |
| first_order_date | DATE | First purchase | Conversion date |
| last_order_date | DATE | Most recent purchase | Recency date |
| days_since_last_order | INTEGER | Recency (R in RFM) | Days since last order |
| total_orders | INTEGER | Frequency (F in RFM) | Number of orders |
| lifetime_value | DECIMAL(10,2) | Monetary (M in RFM) | Total revenue from customer |
| average_order_value | DECIMAL(10,2) | AOV | Average order size |
| rfm_score | INTEGER | Combined RFM score | 1-5 scale (5 = best) |
| is_active | BOOLEAN | Has recent orders | TRUE if ordered in last 90 days |
| dbt_updated_at | TIMESTAMP | ETL timestamp | Model refresh time |

**Logic**: Joins dim_customers + int_customers__orders_agg + RFM calculation

**Tests**:
- `customer_id`: unique, not_null
- `lifetime_value`: >= 0
- Custom: lifetime_value = SUM(orders.order_total)

---

### 6.2 product_performance

**Purpose**: Product sales performance and rankings
**Grain**: One row per product
**User Story**: P2 - Product Performance Analysis

**Columns**:
| Column Name | Data Type | Description | Business Meaning |
|-------------|-----------|-------------|------------------|
| product_id | INTEGER | Natural key | Product identifier |
| product_name | VARCHAR(255) | Display name | Product name |
| category | VARCHAR(100) | Product category | Category classification |
| subcategory | VARCHAR(100) | Subcategory | Sub-classification |
| total_units_sold | INTEGER | Volume | Units sold to date |
| total_revenue | DECIMAL(10,2) | Revenue | Total sales revenue |
| total_profit | DECIMAL(10,2) | Profit | Total profit generated |
| profit_margin_pct | DECIMAL(5,2) | Margin % | (profit / revenue) * 100 |
| total_orders | INTEGER | Order count | Distinct orders containing product |
| average_unit_price | DECIMAL(10,2) | Avg price | Average selling price |
| category_rank | INTEGER | Category rank | Rank by revenue within category |
| overall_rank | INTEGER | Overall rank | Rank by revenue across all products |
| is_active | BOOLEAN | Active status | Currently available |
| dbt_updated_at | TIMESTAMP | ETL timestamp | Model refresh time |

**Logic**: Joins dim_products + int_products__sales_agg + window functions for ranking

**Tests**:
- `product_id`: unique, not_null
- `total_revenue`: >= 0
- `profit_margin_pct`: >= 0 AND <= 100

---

### 6.3 orders_daily / orders_weekly / orders_monthly

**Purpose**: Time-series order aggregations
**Grain**: One row per day / week / month
**User Story**: P3 - Time-Series Order Analytics

**Common Columns**:
| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| date_key | DATE | Date (daily) or start of period |
| total_orders | INTEGER | Orders in period |
| total_revenue | DECIMAL(10,2) | Revenue in period |
| total_units | INTEGER | Units sold in period |
| unique_customers | INTEGER | Distinct customers in period |
| average_order_value | DECIMAL(10,2) | AOV for period |
| cumulative_revenue | DECIMAL(10,2) | Running total revenue (YTD) |
| yoy_growth_pct | DECIMAL(5,2) | Year-over-year growth % |
| mom_growth_pct | DECIMAL(5,2) | Month-over-month growth % (monthly only) |
| dbt_updated_at | TIMESTAMP | ETL timestamp |

**Logic**:
- Join dim_date + int_orders__daily_agg
- Window functions for cumulative metrics
- LAG() for period-over-period growth calculations
- Left join to dim_date ensures all dates present (zero-sale days included)

**Tests**:
- `date_key`: unique, not_null
- `total_orders`: >= 0
- Custom: SUM(daily.total_revenue) = SUM(orders.order_total) (totals must reconcile)

---

### 6.4 marketing_attribution

**Purpose**: Campaign performance and customer acquisition analysis
**Grain**: One row per campaign
**User Story**: P4 - Marketing Campaign Attribution

**Columns**:
| Column Name | Data Type | Description | Business Meaning |
|-------------|-----------|-------------|------------------|
| campaign_id | INTEGER | Campaign identifier | Unique campaign ID |
| campaign_name | VARCHAR(100) | Campaign name | Display name |
| channel | VARCHAR(50) | Marketing channel | email, social, search, etc. |
| campaign_budget | DECIMAL(10,2) | Budget allocated | Campaign spend |
| start_date | DATE | Campaign start | Launch date |
| end_date | DATE | Campaign end | End date |
| customers_acquired | INTEGER | Acquisition count | Customers attributed to campaign |
| total_orders | INTEGER | Orders from campaign | Total orders attributed |
| total_revenue | DECIMAL(10,2) | Revenue generated | Total revenue attributed |
| customer_lifetime_value | DECIMAL(10,2) | Total LTV | LTV of acquired customers |
| cost_per_acquisition | DECIMAL(10,2) | CAC | Budget / customers_acquired |
| return_on_investment | DECIMAL(5,2) | ROI % | (revenue - budget) / budget * 100 |
| is_active | BOOLEAN | Campaign active | TRUE if end_date >= CURRENT_DATE |
| dbt_updated_at | TIMESTAMP | ETL timestamp | Model refresh time |

**Logic**:
- Join campaign_metadata seed + fact_orders (first order per customer) + customer_analytics (LTV)
- Attribution: First-touch (customer's first order with campaign_id)
- ROI calculation: (total_revenue - campaign_budget) / campaign_budget * 100

**Tests**:
- `campaign_id`: unique, not_null
- `campaign_budget`: not_null, > 0
- `cost_per_acquisition`: >= 0
- Custom: end_date >= start_date

---

## 7. Snapshots (SCD Type 2)

**Purpose**: Track historical changes over time
**Materialization**: SNAPSHOT
**Strategy**: timestamp (using updated_at column)

### 7.1 customer_snapshot

**Source**: `raw_data.customers`
**Unique Key**: `customer_id`
**Updated At**: `updated_at`
**Target Schema**: `snapshots`

**Columns** (dbt adds metadata):
- All columns from source
- `dbt_valid_from` (TIMESTAMP): Start of validity
- `dbt_valid_to` (TIMESTAMP): End of validity (NULL for current)
- `dbt_updated_at` (TIMESTAMP): Snapshot run timestamp

**Use Case**: Track customer segment changes over time for historical analysis

---

### 7.2 product_snapshot

**Source**: `raw_data.products`
**Unique Key**: `product_id`
**Updated At**: `updated_at`
**Target Schema**: `snapshots`

**Use Case**: Track product category changes and price changes over time

---

## 8. Singular Tests

**Purpose**: Custom business logic validation
**Location**: `tests/` directory
**Execution**: `dbt test --select test_type:singular`

### Test List:

1. **assert_order_totals_match_line_items.sql**:
   - Validates: `orders.order_total` = SUM(`order_items.line_total`)
   - Returns failing `order_id` if mismatch

2. **assert_no_negative_revenue.sql**:
   - Validates: All revenue fields >= 0 across all models
   - Returns failing rows with negative values

3. **assert_customer_ltv_matches_orders.sql**:
   - Validates: `customer_analytics.lifetime_value` = SUM(`orders.order_total`)
   - Returns failing `customer_id` if mismatch

4. **assert_no_future_order_dates.sql**:
   - Validates: `orders.order_date` <= CURRENT_DATE
   - Returns failing `order_id` with future dates

---

## 9. Model Lineage Summary

```
Sources
  ├── raw_data.customers → stg_ecommerce__customers
  │                         ├── int_customers__orders_agg
  │                         │   └── customer_analytics
  │                         ├── dim_customers
  │                         └── customer_snapshot
  │
  ├── raw_data.orders → stg_ecommerce__orders
  │                      ├── int_customers__orders_agg
  │                      ├── int_orders__daily_agg
  │                      │   ├── orders_daily
  │                      │   ├── orders_weekly
  │                      │   └── orders_monthly
  │                      ├── fact_orders
  │                      └── marketing_attribution
  │
  ├── raw_data.order_items → stg_ecommerce__order_items
  │                            ├── int_products__sales_agg
  │                            │   └── product_performance
  │                            └── fact_order_items (incremental)
  │
  ├── raw_data.products → stg_ecommerce__products
  │                        ├── dim_products
  │                        └── product_snapshot
  │
  └── Seeds
      ├── product_categories.csv → (referenced by stg_ecommerce__products)
      └── campaign_metadata.csv → marketing_attribution
```

---

## 10. Test Coverage Summary

| Layer | Models | Generic Tests | Singular Tests | Total Tests |
|-------|--------|---------------|----------------|-------------|
| Sources | 4 | 12 | 0 | 12 |
| Staging | 4 | 20 | 0 | 20 |
| Intermediate | 3 | 8 | 0 | 8 |
| Dimensions | 3 | 12 | 0 | 12 |
| Facts | 2 | 10 | 4 | 14 |
| Marts | 5 | 15 | 3 | 18 |
| **Total** | **21** | **77** | **7** | **84** |

**Coverage**: >80% column coverage on critical marts (per constitution)

---

## Next Steps

1. Create contracts/ directory with model interface documentation
2. Generate quickstart.md with setup and execution guide
3. Update agent context with dbt-specific guidance
4. Re-evaluate constitution check post-design
