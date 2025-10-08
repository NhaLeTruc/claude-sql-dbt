# Feature Specification: E-Commerce Analytics dbt Demo

**Feature Branch**: `001-build-a-full`
**Created**: 2025-10-08
**Status**: Draft
**Input**: User description: "Build a full demo dbt application which interacts with a mock data warehouse. All code must be tested. Any test data must be mocked - you do not need to pull anything from any real sources. Assume most common usecases for this dbt application."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Customer Analytics Foundation (Priority: P1)

As a data analyst, I need to understand customer behavior and purchasing patterns so that I can make data-driven recommendations for marketing campaigns.

**Why this priority**: Customer analytics is the foundation of most business intelligence workloads. This provides the core dimensional model that all other analytics build upon. Without customer metrics, no downstream analysis is possible.

**Independent Test**: Can be fully tested by running customer mart queries showing unique customers, lifetime value calculations, and purchase frequency metrics. Delivers immediate value through customer segmentation insights.

**Acceptance Scenarios**:

1. **Given** raw customer and order data in source tables, **When** dbt models are executed, **Then** a customer dimension table is created with unique customer records including first/last purchase dates and total order counts
2. **Given** multiple orders per customer across different dates, **When** customer metrics are calculated, **Then** lifetime value, average order value, and recency metrics are accurately computed
3. **Given** customers with various purchase patterns, **When** segmentation logic runs, **Then** customers are correctly classified into segments (high-value, at-risk, new, dormant)
4. **Given** test data with edge cases (single purchase, returns, null values), **When** quality tests execute, **Then** all data quality assertions pass (no nulls in keys, valid date ranges, positive monetary values)

---

### User Story 2 - Product Performance Analysis (Priority: P2)

As a product manager, I need to track product sales performance, inventory turnover, and category trends so that I can optimize product mix and pricing strategies.

**Why this priority**: Product analytics enables inventory and merchandising decisions. This builds on customer data (P1) but can demonstrate incremental modeling and different materialization strategies for large fact tables.

**Independent Test**: Can be tested independently by querying product performance marts showing sales trends, top/bottom performers by category, and inventory metrics. Validates incremental model functionality.

**Acceptance Scenarios**:

1. **Given** product catalog and order line items, **When** product analytics models run, **Then** product dimension includes all active products with accurate category hierarchies and attributes
2. **Given** sales transactions over multiple time periods, **When** product sales facts are built incrementally, **Then** new transactions are added without reprocessing historical data and all metrics remain accurate
3. **Given** products across different categories, **When** performance rankings are calculated, **Then** products are correctly ranked by revenue, units sold, and profit margin within each category
4. **Given** products with varying sales volumes, **When** inventory turnover is computed, **Then** turnover rates accurately reflect sales velocity and identify slow-moving items

---

### User Story 3 - Time-Series Order Analytics (Priority: P3)

As a business analyst, I need to analyze order trends over time including seasonality, growth rates, and fulfillment metrics so that I can forecast demand and optimize operations.

**Why this priority**: Time-series analytics provide trend visibility for forecasting and operational planning. This demonstrates advanced dbt features like date spines, window functions, and slowly changing dimensions.

**Independent Test**: Can be tested by running time-series queries showing daily/weekly/monthly order aggregations, year-over-year growth calculations, and fulfillment cycle times. Validates snapshot functionality for tracking changes over time.

**Acceptance Scenarios**:

1. **Given** orders placed across multiple months, **When** time-series models aggregate by day/week/month, **Then** all time periods are represented (including zero-sale days via date spine) with accurate order counts and revenue totals
2. **Given** order status changes over time, **When** snapshots capture status transitions, **Then** historical status changes are preserved for lifecycle analysis showing average time in each status
3. **Given** current period data compared to prior periods, **When** growth rate calculations execute, **Then** period-over-period and year-over-year growth percentages are accurately computed
4. **Given** orders with fulfillment timestamps, **When** cycle time metrics are calculated, **Then** average time from order to shipment and shipment to delivery are correctly computed by product category

---

### User Story 4 - Marketing Campaign Attribution (Priority: P4)

As a marketing analyst, I need to track campaign performance and customer acquisition channels so that I can measure ROI and optimize marketing spend allocation.

**Why this priority**: Marketing analytics demonstrate joining external reference data (campaigns via seeds) with transactional data. This showcases exposures for downstream BI tool integration.

**Independent Test**: Can be tested by querying campaign performance showing acquisition costs, customer lifetime value by channel, and conversion rates. Validates seed data integration and exposure tracking.

**Acceptance Scenarios**:

1. **Given** orders linked to marketing campaigns and customer acquisition channels, **When** attribution models run, **Then** each customer's first order is correctly attributed to their acquisition campaign and channel
2. **Given** campaign budget data loaded via seeds, **When** ROI calculations execute, **Then** campaign performance metrics show total revenue generated vs. campaign costs with ROI percentages
3. **Given** multi-touch customer journeys, **When** attribution logic processes touchpoints, **Then** revenue is appropriately attributed across campaigns using first-touch and last-touch models
4. **Given** campaign performance mart as an exposure, **When** BI tool integration is validated, **Then** exposure documentation correctly tracks downstream dashboard dependencies

---

### Edge Cases

- What happens when a customer has all orders refunded? (Customer should remain in dimension with zero lifetime value)
- How does the system handle orders with null/missing product information? (Should fail data quality tests, preventing bad data propagation)
- What if incremental models receive out-of-order data? (Incremental strategy should handle late-arriving facts correctly)
- How are timezone differences handled in timestamp comparisons? (Assumption: all timestamps normalized to UTC, documented in model descriptions)
- What happens when a product changes categories? (Slowly changing dimension logic in snapshots captures historical values)
- How does the system handle test data refresh? (Seeds can be reloaded; models rebuild from scratch in dev environment)

## Requirements *(mandatory)*

### Functional Requirements

**Data Sources & Staging**:
- **FR-001**: System MUST define mock data sources for customers, orders, order_items, products, and campaigns
- **FR-002**: System MUST create staging models that standardize source data (rename columns, cast types, apply basic transformations)
- **FR-003**: System MUST load reference data (product categories, campaign metadata) via seed files
- **FR-004**: System MUST document source freshness expectations (warning thresholds for data staleness)

**Dimensional Models**:
- **FR-005**: System MUST create a customer dimension with slowly changing dimension (SCD Type 2) tracking for customer attributes
- **FR-006**: System MUST create a product dimension with hierarchical category structure
- **FR-007**: System MUST create a date dimension or date spine covering the full range of transaction dates
- **FR-008**: System MUST create order fact tables with appropriate grain (order header and order line item levels)

**Analytics Marts**:
- **FR-009**: System MUST create a customer analytics mart calculating lifetime value, recency, frequency, and monetary metrics
- **FR-010**: System MUST create a product performance mart showing sales, returns, and inventory turnover by product and category
- **FR-011**: System MUST create time-series aggregations at daily, weekly, and monthly grains
- **FR-012**: System MUST create a marketing attribution mart linking customers to acquisition campaigns with ROI metrics

**Transformations & Logic**:
- **FR-013**: System MUST implement customer segmentation logic (e.g., high-value, at-risk, new, dormant based on recency and monetary thresholds)
- **FR-014**: System MUST calculate derived metrics using macros for reusability (e.g., days_between, revenue calculation with tax)
- **FR-015**: System MUST use Jinja templating for dynamic SQL generation (e.g., generating metric columns, date range filters)
- **FR-016**: System MUST implement incremental models for large fact tables to optimize build performance

**Testing & Quality**:
- **FR-017**: System MUST include generic tests (unique, not_null, relationships, accepted_values) for all primary and foreign keys
- **FR-018**: System MUST include custom singular tests validating business rules (e.g., order_total = sum(line_item_totals), no negative revenue)
- **FR-019**: System MUST test referential integrity between facts and dimensions
- **FR-020**: System MUST validate data distributions and volumes (using dbt_utils or dbt_expectations packages)

**Documentation**:
- **FR-021**: System MUST document every model with purpose, grain, and business logic descriptions
- **FR-022**: System MUST document every column with business meaning
- **FR-023**: System MUST generate dbt docs site with full lineage graph
- **FR-024**: System MUST define exposures for downstream BI dashboards or reports

**dbt Feature Coverage**:
- **FR-025**: System MUST demonstrate all core dbt features: sources, staging models, intermediate models, marts, tests, docs, seeds, snapshots, macros, analyses, exposures
- **FR-026**: System MUST use multiple materialization strategies (view for staging, table for marts, incremental for large facts, ephemeral for CTEs)
- **FR-027**: System MUST include pre-hooks or post-hooks for at least one model (e.g., granting permissions, logging execution)
- **FR-028**: System MUST use dbt packages (dbt_utils at minimum) for advanced testing and utility macros

### Assumptions

- **Assumption 1**: Mock data represents a typical e-commerce business with B2C transactions (not B2B)
- **Assumption 2**: All monetary values are in USD; no multi-currency support needed for demo purposes
- **Assumption 3**: Mock data spans 2-3 years to demonstrate year-over-year comparisons and trends
- **Assumption 4**: Data warehouse target is DuckDB or SQLite for local development (no cloud credentials required)
- **Assumption 5**: Demo focuses on analytical use cases (read queries), not operational/transactional workloads
- **Assumption 6**: Incremental models use simple append strategy; upsert/merge strategies demonstrated but not required for all models
- **Assumption 7**: Customer PII is synthetic/fake data; no actual sensitive information
- **Assumption 8**: Single timezone (UTC) for all timestamp fields

### Key Entities

**Sources (Raw Data)**:
- **Customers**: Represents individual customers with attributes (name, email, signup date, geography, segment)
- **Orders**: Represents order headers (order ID, customer ID, order date, order status, order total)
- **Order Items**: Represents line items within orders (order ID, product ID, quantity, unit price, discount, line total)
- **Products**: Represents product catalog (product ID, product name, SKU, category, subcategory, unit cost, list price)
- **Campaigns**: Reference data for marketing campaigns (campaign ID, campaign name, channel, start/end dates, budget)

**Dimensions (Conformed)**:
- **Dim Customer**: Customer dimension with SCD Type 2 tracking (customer key, natural key, attributes, valid from/to dates, is_current flag)
- **Dim Product**: Product dimension with category hierarchy (product key, natural key, category attributes, is_active flag)
- **Dim Date**: Date dimension or spine (date key, calendar attributes: day/week/month/quarter/year, fiscal periods, holiday flags)

**Facts**:
- **Fact Orders**: Order header fact at order grain (order key, customer key, date key, order status, order metrics)
- **Fact Order Items**: Order line item fact at line grain (order item key, order key, product key, quantity, revenue, discount, profit)

**Marts (Analytics)**:
- **Customer Analytics**: Denormalized customer view with calculated metrics (RFM scores, lifetime value, segment, first/last order dates)
- **Product Performance**: Product sales performance with rankings and trends (total revenue, units sold, return rate, inventory turns, category rank)
- **Time Series Orders**: Time-based aggregations of orders (daily/weekly/monthly order counts, revenue, average order value, cumulative metrics)
- **Marketing Attribution**: Campaign performance and customer acquisition analysis (campaign, channel, acquisition count, total revenue, CAC, LTV, ROI)

### Data Quality Requirements *(mandatory for dbt models)*

**Test Coverage**:

**Primary keys**:
- All dimension tables: surrogate key columns (dim_customer.customer_key, dim_product.product_key)
- All fact tables: grain-defining keys (fact_orders.order_id, fact_order_items.order_item_id)
- Staging models: natural keys from sources (stg_customers.customer_id, stg_products.product_id)
- Must have unique + not_null tests

**Foreign keys**:
- fact_orders.customer_key → dim_customer.customer_key
- fact_order_items.order_key → fact_orders.order_key
- fact_order_items.product_key → dim_product.product_key
- stg_orders.customer_id → stg_customers.customer_id
- stg_order_items.product_id → stg_products.product_id
- All relationships validated with relationships tests

**Business rules**:
- Order totals must be non-negative (revenue >= 0)
- Quantities must be positive integers (quantity > 0)
- Discount percentages must be between 0 and 100
- Order dates must be <= current date (no future orders)
- Order item line totals must equal quantity * unit_price - discount
- Customer lifetime value must equal sum of order totals
- Product cost must be less than list price
- Campaign end dates must be >= start dates

**Accepted values**:
- Order status: ['pending', 'processing', 'shipped', 'delivered', 'cancelled', 'returned']
- Customer segment: ['new', 'active', 'at-risk', 'dormant', 'vip']
- Campaign channel: ['email', 'social', 'search', 'display', 'affiliate', 'direct']
- Product category: finite list defined in seed data

**Data Freshness**:
- **Source freshness**: All source tables should warn if data older than 24 hours, error if older than 48 hours (simulated for demo; in production would track actual source updates)
- **Update frequency**: Dev environment builds on-demand; mock production schedule would be daily full refresh or incremental builds every 4 hours

**Documentation Requirements**:
- All models must have purpose descriptions explaining what the model does and why it exists
- All columns must have business meaning documented (not just "customer ID" but "Unique identifier for customer; matches source system CRM ID")
- Assumptions and business logic must be captured (e.g., "Lifetime value includes only completed orders, excludes cancelled/returned orders")

## Success Criteria *(mandatory)*

### Measurable Outcomes

**Completeness & Coverage**:
- **SC-001**: All core dbt features are demonstrated (12+ feature types implemented: sources, seeds, staging, intermediate, marts, snapshots, tests, docs, macros, analyses, exposures, packages)
- **SC-002**: All models have complete documentation (100% of models have descriptions, 100% of columns documented)
- **SC-003**: Test coverage meets constitution standards (every model has at least one test; critical marts have >80% column coverage)

**Data Quality & Correctness**:
- **SC-004**: All data quality tests pass when executed (0 test failures on mock data; all assertions validated)
- **SC-005**: Business logic validation succeeds (order totals match line item sums; customer LTV matches order totals; time-series aggregations sum to overall totals)
- **SC-006**: Incremental models produce identical results to full-refresh runs (validate via comparison queries)

**Performance & Build Efficiency**:
- **SC-007**: Full project build completes in under 5 minutes on local development machine (dbt build execution time from clean state)
- **SC-008**: Incremental model builds process only new/changed records (validate via dbt logs showing reduced row counts on incremental runs)
- **SC-009**: Query performance on marts meets interactive thresholds (all mart queries return results in under 2 seconds for typical analytical queries)

**Usability & Documentation**:
- **SC-010**: Generated dbt docs site is complete and navigable (all models appear in lineage graph; documentation renders correctly; data catalog is searchable)
- **SC-011**: Analysts can successfully answer business questions using marts (sample analytical queries provided in analyses/ directory execute successfully)
- **SC-012**: New developers can understand project structure within 15 minutes (README provides clear orientation; folder structure follows conventions; naming is intuitive)

**Demonstration Value**:
- **SC-013**: Project showcases dbt best practices suitable for portfolio/demo purposes (code quality, testing rigor, documentation completeness make it reference-quality)
- **SC-014**: Mock data is realistic and representative (data distributions, relationships, and volumes mimic real-world e-commerce patterns)
- **SC-015**: Project serves as learning resource (comments and docs explain "why" decisions were made; demonstrates multiple approaches where applicable)
