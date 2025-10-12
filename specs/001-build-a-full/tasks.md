# Tasks: E-Commerce Analytics dbt Demo

**Input**: Design documents from `/specs/001-build-a-full/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Per constitution requirement, ALL dbt models MUST have tests defined in schema.yml BEFORE SQL implementation. Test-first development is NON-NEGOTIABLE.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions
- **dbt project**: `dbt_project/` at repository root
- **Docker environment**: `docker/` directory
- **Project config**: Root level (`profiles.yml`, `packages.yml`, `requirements.txt`, `README.md`)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and environment setup needed by all user stories

- [X] T001 Create Docker Compose environment in `docker/docker-compose.yml` with PostgreSQL 16 + MinIO services
- [X] T002 [P] Create PostgreSQL initialization script `docker/postgres/init-db.sql` (creates `raw_data` schema and `ecommerce_dw` database)
- [X] T003 [P] Create MinIO directory structure `docker/minio/.gitkeep` (unused but available per requirement)
- [X] T004 [P] Generate mock data SQL scripts in `docker/postgres/mock-data/` directory:
  - `customers.sql` (10,000 records with generate_series)
  - `orders.sql` (50,000 records spanning 2022-2024)
  - `order_items.sql` (150,000 records, ~3 per order)
  - `products.sql` (100 products across 5 categories)
- [X] T005 Create dbt project structure at `dbt_project/` with standard directories:
  - `models/staging/`, `models/intermediate/`, `models/marts/core/`, `models/marts/analytics/`
  - `tests/`, `macros/`, `seeds/`, `snapshots/`, `analyses/`
- [X] T006 [P] Create `dbt_project/dbt_project.yml` with project configuration (materialization defaults per layer)
- [X] T007 [P] Create `profiles.yml` in repository root with PostgreSQL connection profile (dev target, analytics_dev schema)
- [X] T008 [P] Create `packages.yml` with dbt_utils dependency (version 1.2.0)
- [X] T009 [P] Create `requirements.txt` with dbt-core>=1.8.0 and dbt-postgres>=1.8.0
- [X] T010 [P] Create `.gitignore` for dbt artifacts (`target/`, `dbt_packages/`, `logs/`, `venv/`)
- [X] T011 [P] Create project `README.md` with setup instructions and project overview
- [ ] T012 Test Docker environment startup: `docker-compose up -d` and verify mock data loaded (REQUIRES DOCKER)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core dbt setup that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T013 Install dbt packages: Run `dbt deps` to install dbt_utils (REQUIRES DBT INSTALLED)
- [X] T014 [P] Create seed file `dbt_project/seeds/product_categories.csv` with 5 categories (Electronics, Clothing, Home & Garden, Books, Toys)
- [X] T015 [P] Create seed file `dbt_project/seeds/campaign_metadata.csv` with 10 marketing campaigns across 6 channels
- [ ] T016 Load seeds into database: Run `dbt seed` (REQUIRES DBT + DATABASE)
- [X] T017 [P] Create custom macro `dbt_project/macros/calculate_days_between.sql` for date difference calculations
- [X] T018 [P] Create custom macro `dbt_project/macros/calculate_revenue_with_tax.sql` for consistent revenue calculations
- [X] T019 [P] Create custom macro `dbt_project/macros/generate_date_spine.sql` using dbt_utils for complete date ranges
- [ ] T020 Test dbt connection: Run `dbt debug` to verify PostgreSQL connectivity (REQUIRES DBT + DATABASE)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Customer Analytics Foundation (Priority: P1) 🎯 MVP

**Goal**: Enable data analysts to understand customer behavior and purchasing patterns through dimensional customer data and lifetime value analytics

**Independent Test**: Query `customer_analytics` mart showing unique customers, LTV calculations, RFM segmentation, and purchase frequency metrics

### Tests for User Story 1 (MANDATORY per constitution) ⚠️

**NOTE: Write these tests FIRST in schema.yml files, ensure they FAIL before implementation**

- [X] T021 [P] [US1] Create source tests in `dbt_project/models/staging/_stg_ecommerce__sources.yml`:
  - Define `raw_data` source with customers and orders tables
  - Add freshness checks (warn_after: 24h, error_after: 48h)
  - Add source-level tests: customers.customer_id (unique, not_null), orders.order_id (unique, not_null)
  - Document source descriptions and column business meanings
- [X] T022 [P] [US1] Create staging model tests in same `_stg_ecommerce__sources.yml`:
  - `stg_ecommerce__customers`: customer_id (unique, not_null), email (not_null), customer_segment (accepted_values)
  - `stg_ecommerce__orders`: order_id (unique, not_null), customer_id (relationships to stg_customers), order_status (accepted_values), order_total (expression_is_true: >= 0)
  - Document all staging model purposes and column descriptions
- [X] T023 [P] [US1] Create dimension tests in `dbt_project/models/marts/core/_core__models.yml`:
  - `dim_customers`: customer_key (unique, not_null), customer_id (unique, not_null, relationships to staging)
  - Document dim_customers purpose (SCD Type 1 current snapshot) and all column business meanings
- [X] T024 [P] [US1] Create mart tests in `dbt_project/models/marts/analytics/_analytics__models.yml`:
  - `customer_analytics`: customer_id (unique, not_null), lifetime_value (not_null, expression_is_true: >= 0), total_orders (not_null, expression_is_true: >= 0), rfm_score (expression_is_true: BETWEEN 1 AND 5)
  - Document customer_analytics purpose, grain (one row per customer), and all column business meanings (>80% column coverage required)
- [X] T025 [P] [US1] Create singular test `dbt_project/tests/assert_customer_ltv_matches_orders.sql` validating lifetime_value = SUM(order_total) per customer

### Implementation for User Story 1

- [X] T026 [P] [US1] Create staging model `dbt_project/models/staging/stg_ecommerce__customers.sql` (view materialization):
  - SELECT from raw_data.customers source
  - Rename columns to standard naming (customer_name, customer_segment)
  - Cast types consistently
  - Add dbt_updated_at metadata column
  - Add inline SQL comments explaining transformations
- [X] T027 [P] [US1] Create staging model `dbt_project/models/staging/stg_ecommerce__orders.sql` (view materialization):
  - SELECT from raw_data.orders source
  - Standardize column names and types
  - Add dbt_updated_at metadata
  - Add comments for order_status values
- [X] T028 [US1] Create intermediate model `dbt_project/models/intermediate/int_customers__orders_agg.sql` (ephemeral materialization):
  - Aggregate order metrics per customer (first_order_date, last_order_date, total_orders, total_order_value, average_order_value)
  - Use calculate_days_between macro for days_since_last_order
  - Filter out cancelled/returned orders
  - Add comments explaining business logic
  - Depends on T026, T027
- [X] T029 [US1] Create dimension model `dbt_project/models/marts/core/dim_customers.sql` (table materialization):
  - Join stg_ecommerce__customers with int_customers__orders_agg
  - Generate surrogate key using dbt_utils.surrogate_key
  - Include is_active flag (orders in last 90 days)
  - Add dbt_updated_at metadata
  - Add model-level comments explaining dimension purpose and SCD Type 1 approach
  - Depends on T028
- [X] T030 [US1] Create analytics mart `dbt_project/models/marts/analytics/customer_analytics.sql` (table materialization):
  - Calculate RFM metrics (Recency, Frequency, Monetary)
  - Implement customer segmentation logic (scoring algorithm: 1-5 scale for R, F, M)
  - Compute lifetime_value from total order value
  - Include all customer attributes from dim_customers
  - Add comprehensive inline comments explaining RFM calculation and segmentation rules
  - Depends on T029
- [X] T031 [US1] Create snapshot `dbt_project/snapshots/customer_snapshot.sql` for SCD Type 2 tracking:
  - Configure timestamp strategy using updated_at column
  - Target schema: snapshots
  - Unique key: customer_id
  - Add comments explaining SCD Type 2 purpose and usage
- [ ] T032 [US1] Run User Story 1 models: `dbt run --select +customer_analytics` (builds all upstream dependencies)
- [ ] T033 [US1] Test User Story 1 models: `dbt test --select +customer_analytics` (all tests should PASS)
- [ ] T034 [US1] Run customer snapshot: `dbt snapshot --select customer_snapshot`

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently. Analysts can query customer_analytics mart for customer insights.

---

## Phase 4: User Story 2 - Product Performance Analysis (Priority: P2)

**Goal**: Enable product managers to track product sales performance, inventory turnover, and category trends for merchandising decisions

**Independent Test**: Query `product_performance` mart showing sales trends, top/bottom performers by category, profit margins, and category rankings

### Tests for User Story 2 (MANDATORY per constitution) ⚠️

- [ ] T035 [P] [US2] Add product source tests to `dbt_project/models/staging/_stg_ecommerce__sources.yml`:
  - Define raw_data.products and raw_data.order_items sources
  - Add freshness checks
  - Add source tests: products.product_id (unique, not_null), order_items.order_item_id (unique, not_null)
- [ ] T036 [P] [US2] Create staging tests in `_stg_ecommerce__sources.yml`:
  - `stg_ecommerce__products`: product_id (unique, not_null), sku (unique, not_null), category (relationships to seed), list_price (expression_is_true: >= unit_cost)
  - `stg_ecommerce__order_items`: order_item_id (unique, not_null), order_id (relationships), product_id (relationships), quantity (expression_is_true: > 0)
- [ ] T037 [P] [US2] Create dimension tests in `dbt_project/models/marts/core/_core__models.yml`:
  - `dim_products`: product_key (unique, not_null), product_id (unique, relationships), sku (unique)
  - `fact_order_items`: order_item_id (unique, not_null), order_id (relationships), product_key (relationships)
- [ ] T038 [P] [US2] Create mart tests in `dbt_project/models/marts/analytics/_analytics__models.yml`:
  - `product_performance`: product_id (unique, not_null), total_revenue (expression_is_true: >= 0), profit_margin_pct (expression_is_true: BETWEEN 0 AND 100), category_rank (expression_is_true: >= 1)
  - Document product_performance with >80% column coverage
- [ ] T039 [P] [US2] Create singular test `dbt_project/tests/assert_order_totals_match_line_items.sql` validating order_total = SUM(line_total) per order

### Implementation for User Story 2

- [ ] T040 [P] [US2] Create staging model `dbt_project/models/staging/stg_ecommerce__products.sql` (view):
  - Standardize product columns from raw_data.products
  - Calculate profit_margin_pct inline ((list_price - unit_cost) / list_price * 100)
  - Join to product_categories seed for category validation
  - Add comments explaining catalog structure
- [ ] T041 [P] [US2] Create staging model `dbt_project/models/staging/stg_ecommerce__order_items.sql` (view):
  - Standardize order item columns
  - Calculate line_profit (line_total - quantity * unit_cost from products)
  - Add dbt_updated_at metadata
  - Add comments for discount and pricing logic
- [ ] T042 [US2] Create intermediate model `dbt_project/models/intermediate/int_products__sales_agg.sql` (view):
  - Aggregate sales metrics per product (total_units_sold, total_revenue, total_profit, total_orders, average_unit_price)
  - Join order_items to orders, filter cancelled/returned
  - Add comments explaining aggregation logic
  - Depends on T040, T041
- [ ] T043 [US2] Create dimension model `dbt_project/models/marts/core/dim_products.sql` (table):
  - Join products to category hierarchy
  - Generate product_key surrogate key
  - Include is_active flag, profit margins
  - Add comments on product hierarchy
  - Depends on T040
- [ ] T044 [US2] Create fact model `dbt_project/models/marts/core/fact_order_items.sql` (incremental, unique_key: order_item_id):
  - Join order_items to product_key and order_key
  - Configure incremental strategy: append (filter WHERE order_id > MAX)
  - Include quantity, pricing, profit columns
  - Add is_incremental() block with comments explaining incremental logic
  - Depends on T043
- [ ] T045 [US2] Create analytics mart `dbt_project/models/marts/analytics/product_performance.sql` (table):
  - Join dim_products with int_products__sales_agg
  - Calculate category_rank and overall_rank using window functions (RANK() OVER)
  - Compute profit margins and turnover rates
  - Add extensive comments on ranking logic and performance calculations
  - Depends on T043, T042
- [ ] T046 [US2] Create snapshot `dbt_project/snapshots/product_snapshot.sql` for product price/category changes:
  - Timestamp strategy on updated_at
  - Track category migrations and price changes
  - Add comments on SCD Type 2 usage for historical pricing
- [ ] T047 [US2] Run User Story 2 models: `dbt run --select +product_performance`
- [ ] T048 [US2] Test User Story 2 models: `dbt test --select +product_performance`
- [ ] T049 [US2] Validate incremental model: `dbt run --select fact_order_items --full-refresh` then compare to incremental run

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently. Product managers can analyze product performance metrics.

---

## Phase 5: User Story 3 - Time-Series Order Analytics (Priority: P3)

**Goal**: Enable business analysts to analyze order trends over time with seasonality, growth rates, and fulfillment cycle times for forecasting

**Independent Test**: Query time-series marts (`orders_daily`, `orders_weekly`, `orders_monthly`) showing period aggregations, YoY growth, and zero-sale day coverage via date spine

### Tests for User Story 3 (MANDATORY per constitution) ⚠️

- [ ] T050 [P] [US3] Create dimension tests in `dbt_project/models/marts/core/_core__models.yml`:
  - `dim_date`: date_key (unique, not_null), year (expression_is_true: BETWEEN 2022 AND 2024)
  - `fact_orders`: order_id (unique, not_null), customer_key (relationships), date_key (relationships), order_total (expression_is_true: >= 0)
- [ ] T051 [P] [US3] Create mart tests in `dbt_project/models/marts/analytics/_analytics__models.yml`:
  - `orders_daily`: date_key (unique, not_null), total_orders (expression_is_true: >= 0), total_revenue (expression_is_true: >= 0)
  - `orders_weekly`: week_start_date (unique, not_null), week_number (expression_is_true: BETWEEN 1 AND 53)
  - `orders_monthly`: month_start_date (unique, not_null), month (expression_is_true: BETWEEN 1 AND 12)
  - Document all time-series models with grain definitions
- [ ] T052 [P] [US3] Create singular test `dbt_project/tests/assert_no_future_order_dates.sql` validating order_date <= CURRENT_DATE

### Implementation for User Story 3

- [ ] T053 [US3] Create intermediate model `dbt_project/models/intermediate/int_orders__daily_agg.sql` (view):
  - Aggregate orders by date (total_orders, total_revenue, total_units, unique_customers)
  - Filter cancelled/returned orders
  - Add comments explaining daily aggregation logic
  - Depends on T027, T041
- [ ] T054 [US3] Create dimension model `dbt_project/models/marts/core/dim_date.sql` (table):
  - Use generate_date_spine macro for 2022-01-01 to 2024-12-31
  - Extract date parts (day_of_week, day_of_month, week_of_year, month, quarter, year)
  - Add is_weekend and is_holiday flags
  - Add comments explaining date dimension purpose and spine approach
- [ ] T055 [US3] Create fact model `dbt_project/models/marts/core/fact_orders.sql` (table):
  - Join orders to customer_key and date_key
  - Include order header facts (order_status, order_total, campaign_id)
  - Add comments on fact grain (one row per order)
  - Depends on T029, T054
- [ ] T056 [US3] Create analytics mart `dbt_project/models/marts/analytics/orders_daily.sql` (table):
  - LEFT JOIN dim_date to int_orders__daily_agg (ensures all dates present, even zero-sale days)
  - Calculate cumulative_revenue_ytd using window function (SUM() OVER partition by year ORDER BY date)
  - Calculate yoy_growth_pct using LAG() window function
  - Add comprehensive comments on time-series calculations and window functions
  - Depends on T054, T053
- [ ] T057 [US3] Create analytics mart `dbt_project/models/marts/analytics/orders_weekly.sql` (table):
  - Aggregate from orders_daily using DATE_TRUNC('week', date_key)
  - Calculate week_start_date, week_end_date, week_number
  - Compute wow_growth_pct (week-over-week) using LAG()
  - Add comments on weekly aggregation logic
  - Depends on T056
- [ ] T058 [US3] Create analytics mart `dbt_project/models/marts/analytics/orders_monthly.sql` (table):
  - Aggregate from orders_daily using DATE_TRUNC('month', date_key)
  - Calculate month metrics (month_start_date, month, month_name, year)
  - Compute mom_growth_pct and yoy_growth_pct using LAG()
  - Add comments on monthly seasonality and growth calculations
  - Depends on T056
- [ ] T059 [US3] Run User Story 3 models: `dbt run --select +orders_daily +orders_weekly +orders_monthly`
- [ ] T060 [US3] Test User Story 3 models: `dbt test --select +orders_daily +orders_weekly +orders_monthly`

**Checkpoint**: At this point, all time-series models work independently. Business analysts can perform trend analysis and forecasting.

---

## Phase 6: User Story 4 - Marketing Campaign Attribution (Priority: P4)

**Goal**: Enable marketing analysts to track campaign performance, customer acquisition channels, and ROI for marketing spend optimization

**Independent Test**: Query `marketing_attribution` mart showing campaign ROI, acquisition costs (CAC), customer LTV by channel, and first-touch attribution

### Tests for User Story 4 (MANDATORY per constitution) ⚠️

- [ ] T061 [P] [US4] Add campaign tests to `dbt_project/models/marts/analytics/_analytics__models.yml`:
  - `marketing_attribution`: campaign_id (unique, not_null), channel (accepted_values: [email, social, search, display, affiliate, direct]), campaign_budget (expression_is_true: > 0), customers_acquired (expression_is_true: >= 0)
  - Document marketing_attribution with >80% column coverage including ROI calculation explanations
- [ ] T062 [P] [US4] Create singular test `dbt_project/tests/assert_campaign_dates_valid.sql` validating end_date >= start_date for all campaigns

### Implementation for User Story 4

- [ ] T063 [US4] Create analytics mart `dbt_project/models/marts/analytics/marketing_attribution.sql` (table):
  - Join campaign_metadata seed with fact_orders (first order per customer = acquisition attribution)
  - Join to customer_analytics for customer_lifetime_value
  - Calculate customers_acquired (COUNT DISTINCT customers with first order to campaign)
  - Calculate total_orders, total_revenue from attributed orders
  - Calculate cost_per_acquisition (campaign_budget / customers_acquired)
  - Calculate return_on_investment ((total_revenue - campaign_budget) / campaign_budget * 100)
  - Add is_active flag (end_date >= CURRENT_DATE)
  - Add extensive comments explaining first-touch attribution logic and ROI calculations
  - Depends on T030, T055
- [ ] T064 [US4] Create exposure `dbt_project/models/marts/analytics/_analytics__exposures.yml`:
  - Define marketing_dashboard exposure depending on marketing_attribution
  - Include owner (Analytics Team), description, mock URL
  - Demonstrates exposure tracking for downstream BI tools
- [ ] T065 [US4] Run User Story 4 models: `dbt run --select +marketing_attribution`
- [ ] T066 [US4] Test User Story 4 models: `dbt test --select +marketing_attribution`

**Checkpoint**: All user stories should now be independently functional. Marketing analysts can perform campaign ROI analysis.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and final validation

- [ ] T067 [P] Create analysis query `dbt_project/analyses/top_customers_by_ltv.sql`:
  - SELECT top 10 customers by lifetime_value from customer_analytics
  - Include comments explaining business question answered
- [ ] T068 [P] Create analysis query `dbt_project/analyses/product_sales_trends.sql`:
  - SELECT products with revenue trends (YoY growth) from product_performance
  - Include comments on trend identification
- [ ] T069 [P] Create analysis query `dbt_project/analyses/campaign_roi_analysis.sql`:
  - SELECT campaigns by ROI from marketing_attribution
  - Include comments on ROI interpretation
- [ ] T070 [P] Create singular test `dbt_project/tests/assert_no_negative_revenue.sql` checking all revenue fields >= 0 across all models
- [ ] T071 [P] Add pre-hook example in `dbt_project/dbt_project.yml` for staging models (logging model execution start)
- [ ] T072 [P] Add post-hook example in `dbt_project/dbt_project.yml` for mart models (demonstrate permissions grant syntax)
- [ ] T073 Generate dbt documentation: Run `dbt docs generate` to create catalog.json and manifest.json
- [ ] T074 Validate documentation completeness: Check that all models have descriptions, all columns documented (100% coverage)
- [ ] T075 Run full dbt build: `dbt build` (runs all models, snapshots, and tests from scratch)
- [ ] T076 Verify all tests pass: Check run_results.json shows PASS=84, ERROR=0
- [ ] T077 Validate performance target: Confirm full build completes in <5 minutes
- [ ] T078 Create quickstart validation script: Bash script that runs setup steps from quickstart.md and validates success criteria
- [ ] T079 [P] Update README.md with:
  - Project description and dbt features demonstrated
  - Quick start command sequence
  - Links to documentation (spec.md, data-model.md, quickstart.md)
  - Success criteria checklist
- [ ] T080 [P] Create `.github/workflows/dbt-ci.yml` example (documentation only, not executed):
  - Example GitHub Actions workflow showing `dbt build --select state:modified+`
  - Comments explaining CI/CD best practices for dbt

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion (T001-T012) - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase (T013-T020) completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3 → P4)
- **Polish (Phase 7)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (T020) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (T020) - No dependencies on other stories (independently testable)
- **User Story 3 (P3)**: Can start after Foundational (T020) - Uses fact_orders which can be built in this phase (independently testable)
- **User Story 4 (P4)**: Can start after Foundational (T020) - References customer_analytics (US1) but can build in parallel with minor sequencing

**Critical Path for MVP**: T001→T012 (Setup) → T013→T020 (Foundational) → T021→T034 (User Story 1) = **34 tasks**

### Within Each User Story

- Tests MUST be written first (schema.yml definitions) and run to FAIL before implementation (per constitution)
- Staging models before intermediate models
- Intermediate models before dimensions
- Dimensions before facts
- Facts before marts
- All models before snapshots
- Story implementation complete before moving to next priority

### Parallel Opportunities

- **Setup (Phase 1)**: Tasks T002-T011 can all run in parallel (different files)
- **Foundational (Phase 2)**: Tasks T014-T019 can run in parallel (seeds, macros)
- **User Story 1 Tests**: Tasks T021-T024 can run in parallel (different schema.yml files)
- **User Story 1 Models**: Tasks T026-T027 can run in parallel (different staging models)
- **Once Foundational completes**: All four user stories CAN start in parallel (if team capacity allows and minor sequencing managed)
- **Polish tasks**: Tasks T067-T072, T079-T080 can run in parallel (analyses, docs, README)

---

## Parallel Example: User Story 1

```bash
# Phase: Tests (write schema.yml files in parallel)
Task T021: Define source tests in _stg_ecommerce__sources.yml
Task T022: Define staging tests in _stg_ecommerce__sources.yml
Task T023: Define dimension tests in _core__models.yml
Task T024: Define mart tests in _analytics__models.yml
Task T025: Write assert_customer_ltv_matches_orders.sql

# Run tests to ensure they FAIL (models don't exist yet)
dbt test --select source:raw_data stg_ecommerce__customers stg_ecommerce__orders dim_customers customer_analytics

# Phase: Staging (build staging models in parallel)
Task T026: Create stg_ecommerce__customers.sql
Task T027: Create stg_ecommerce__orders.sql

# Phase: Sequential implementation (dependencies)
Task T028: Create int_customers__orders_agg.sql (depends on T026, T027)
Task T029: Create dim_customers.sql (depends on T028)
Task T030: Create customer_analytics.sql (depends on T029)
Task T031: Create customer_snapshot.sql (depends on source)

# Validate
Task T032: dbt run --select +customer_analytics
Task T033: dbt test --select +customer_analytics (all should PASS now)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only - Recommended)

1. Complete Phase 1: Setup (T001-T012)
2. Complete Phase 2: Foundational (T013-T020) - CRITICAL, blocks all work
3. Complete Phase 3: User Story 1 (T021-T034)
4. **STOP and VALIDATE**:
   - Run `dbt build --select +customer_analytics`
   - Verify all 84 tests pass (full coverage)
   - Query customer_analytics mart and validate business logic
   - Generate docs and review lineage graph
5. Deploy/demo customer analytics capabilities

**MVP Estimated Time**: 10-12 hours (Setup: 2h, Foundational: 2h, US1: 6-8h)

### Incremental Delivery (Recommended Sequence)

1. Complete Setup + Foundational → Foundation ready (4 hours)
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!) (6-8 hours)
3. Add User Story 2 → Test independently → Deploy/Demo (5-6 hours)
4. Add User Story 3 → Test independently → Deploy/Demo (5-6 hours)
5. Add User Story 4 → Test independently → Deploy/Demo (3-4 hours)
6. Polish phase → Final validation (2-3 hours)

**Total Estimated Time**: 25-31 hours for complete feature

### Parallel Team Strategy

With multiple developers (after Foundational phase T020 complete):

1. **Team completes Setup + Foundational together** (4 hours)
2. **Once T020 done, parallel work**:
   - Developer A: User Story 1 (T021-T034) - 6-8 hours
   - Developer B: User Story 2 (T035-T049) - 5-6 hours
   - Developer C: User Story 3 (T050-T060) - 5-6 hours
   - Developer D: User Story 4 (T061-T066) - 3-4 hours
3. **Stories complete and integrate independently**
4. **Team completes Polish together** (T067-T080) - 2-3 hours

**Parallel Estimated Time**: 14-17 hours (with 4 developers)

---

## Notes

- [P] tasks = different files, no dependencies, can run in parallel
- [Story] label maps task to specific user story (US1, US2, US3, US4) for traceability
- Each user story should be independently completable and testable
- **CRITICAL**: Verify tests FAIL before implementing models (test-first workflow per constitution)
- **CRITICAL**: All models must have schema.yml documentation with purpose, grain, and column descriptions
- Commit after each task or logical group (e.g., after completing staging layer for a user story)
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- dbt incremental models (fact_order_items) should be tested with both full-refresh and incremental runs to validate correctness

---

## Success Criteria Validation

After completing all tasks, verify constitution compliance:

- [ ] **SC-001**: All 12+ core dbt features demonstrated (sources, seeds, staging, intermediate, marts, snapshots, tests, docs, macros, analyses, exposures, packages) ✅
- [ ] **SC-002**: All models have complete documentation (100% of models have descriptions, 100% of columns documented) ✅
- [ ] **SC-003**: Test coverage meets standards (every model has tests; critical marts >80% column coverage) ✅
- [ ] **SC-004**: All data quality tests pass (0 test failures; 84 tests PASS) ✅
- [ ] **SC-005**: Business logic validation succeeds (singular tests confirm order totals, LTV, etc.) ✅
- [ ] **SC-006**: Incremental models produce identical results to full-refresh ✅
- [ ] **SC-007**: Full project build completes in <5 minutes ✅
- [ ] **SC-008**: Incremental builds process only new/changed records ✅
- [ ] **SC-009**: Query performance on marts <2 seconds ✅
- [ ] **SC-010**: Generated dbt docs site is complete and navigable ✅
- [ ] **SC-011**: Sample analytical queries execute successfully ✅
- [ ] **SC-012**: Project structure understandable in <15 minutes ✅
- [ ] **SC-013**: Code quality demonstrates best practices (suitable for portfolio/demo) ✅
- [ ] **SC-014**: Mock data is realistic and representative ✅
- [ ] **SC-015**: Project serves as learning resource (comprehensive comments and docs) ✅

---

## Quick Reference: Task Counts

- **Phase 1 (Setup)**: 12 tasks
- **Phase 2 (Foundational)**: 8 tasks (BLOCKING)
- **Phase 3 (User Story 1 - P1 MVP)**: 14 tasks (5 tests + 9 implementation)
- **Phase 4 (User Story 2 - P2)**: 15 tasks (5 tests + 10 implementation)
- **Phase 5 (User Story 3 - P3)**: 11 tasks (3 tests + 8 implementation)
- **Phase 6 (User Story 4 - P4)**: 6 tasks (2 tests + 4 implementation)
- **Phase 7 (Polish)**: 14 tasks

**Total**: 80 tasks

**MVP (P1 only)**: 34 tasks (Setup + Foundational + US1)
**Full Feature**: 80 tasks (all user stories + polish)

**Parallel opportunities**: ~35 tasks marked [P] can run in parallel within their phases
