# Research: E-Commerce Analytics dbt Demo

**Phase**: 0 - Research & Technology Selection
**Date**: 2025-10-08
**Feature**: [spec.md](spec.md)

## Overview

This research document consolidates technology choices, best practices, and architectural decisions for building a comprehensive dbt demo project targeting e-commerce analytics. All decisions prioritize testability, documentation, and demonstration of dbt's full feature spectrum.

---

## 1. dbt Version & Core Setup

### Decision

**dbt-core 1.8+ (latest stable)** with **dbt-postgres** adapter

### Rationale

- **Version 1.8+** includes:
  - Enhanced testing capabilities with `store_failures` and `store_failures_as` for debugging
  - Improved incremental model strategies (merge, append, delete+insert)
  - Better error messages and compilation performance
  - Native support for unit tests (dbt 1.8 preview feature)
  - Enhanced Jinja context and macro capabilities

- **dbt-postgres adapter** chosen because:
  - PostgreSQL provides full SQL feature set for complex analytics
  - Docker-friendly for local development without cloud dependencies
  - Excellent support for window functions, CTEs, and aggregations needed for analytics
  - Wide adoption makes demo more relatable to practitioners
  - Strong dbt adapter support and stability

### Alternatives Considered

- **dbt-duckdb**: Excellent for local dev, ultra-fast, but less representative of production environments
- **dbt-snowflake/bigquery**: Cloud-dependent, requires credentials, defeats "local mock data" requirement
- **dbt-sqlite**: Limited SQL feature set, lacks window functions and advanced analytics capabilities

### Implementation Notes

- Install via `pip install dbt-core dbt-postgres`
- Lock version in `requirements.txt`: `dbt-core>=1.8.0,<1.9.0` and `dbt-postgres>=1.8.0,<1.9.0`
- Use `dbt --version` to verify installation in quickstart guide

---

## 2. Docker Compose Environment

### Decision

**Docker Compose** with **PostgreSQL 16** and **MinIO** (unused but available)

### Rationale

**PostgreSQL 16**:
- Latest stable release with performance improvements
- Native support for MERGE (useful for incremental upsert strategies)
- Enhanced JSON capabilities for potential future extensions
- Improved query planner for complex analytics queries
- Standard port 5432, well-documented, stable

**MinIO**:
- S3-compatible object storage
- Included per user requirement but untouched by dbt
- Demonstrates infrastructure readiness for future dbt + object storage integrations (e.g., external tables, dbt artifacts storage)
- Minimal overhead (single container)

**Docker Compose benefits**:
- Single `docker-compose up` command for complete environment
- Reproducible across all platforms (Linux/macOS/Windows)
- Isolated from host system
- Easy teardown and rebuild for testing
- Version-controlled infrastructure-as-code

### Alternatives Considered

- **Postgres.app / local install**: Platform-specific, harder to reproduce, pollutes host system
- **Docker without Compose**: More complex multi-container orchestration
- **Cloud-hosted Postgres**: Defeats "local testing" requirement, requires credentials

### Implementation Notes

**docker-compose.yml structure**:
```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: dbt_user
      POSTGRES_PASSWORD: dbt_password
      POSTGRES_DB: ecommerce_dw
    ports:
      - "5432:5432"
    volumes:
      - ./postgres/init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
      - ./postgres/mock-data:/docker-entrypoint-initdb.d/mock-data

  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    ports:
      - "9000:9000"
      - "9001:9001"
```

**Mock data loading**:
- SQL scripts in `postgres/init-db.sql` create schema: `CREATE SCHEMA raw_data;`
- Scripts in `postgres/mock-data/*.sql` run alphabetically via Docker entrypoint
- Data inserted into `raw_data` schema (customers, orders, order_items, products, campaigns)

---

## 3. Mock Data Generation Strategy

### Decision

**SQL INSERT statements** for reproducible mock data (10k customers, 50k orders, 2-3 years)

### Rationale

- **Reproducibility**: Same data every rebuild, deterministic testing
- **Version control**: SQL files in git, changes tracked
- **Simplicity**: No external data generation tools needed
- **Documentation**: SQL is self-documenting (see column values, understand distributions)
- **Test-friendly**: Easy to add edge cases (nulls, negative values for test failures, boundary conditions)

**Data volume targets**:
- 10,000 customers: Enough to test aggregations, not too large for quick builds
- 50,000 orders: ~5 orders per customer average, realistic for analytics
- 150,000 order items: ~3 items per order average
- 100 products: Manageable catalog size, sufficient for category analysis
- 10 campaigns: Demonstrates seed file functionality

**Date range**: 2022-01-01 to 2024-12-31 (3 years)
- Enables year-over-year comparisons
- Includes seasonality patterns (holiday spikes)
- Sufficient history for trend analysis

### Alternatives Considered

- **Faker/Python generators**: Requires separate script, adds dependency, harder to review
- **CSV imports**: Less flexible for SQL functions (date generation, random distributions)
- **dbt seeds for all data**: Seeds intended for small reference data, not large fact tables

### Implementation Notes

**customers.sql** example structure:
```sql
INSERT INTO raw_data.customers (customer_id, email, name, signup_date, segment, state, country)
SELECT
  generate_series(1, 10000) AS customer_id,
  'customer' || generate_series(1, 10000) || '@example.com' AS email,
  'Customer ' || generate_series(1, 10000) AS name,
  '2022-01-01'::date + (random() * 1095)::int AS signup_date,
  (ARRAY['new', 'active', 'at-risk', 'dormant', 'vip'])[floor(random() * 5 + 1)] AS segment,
  (ARRAY['CA', 'NY', 'TX', 'FL', 'WA'])[floor(random() * 5 + 1)] AS state,
  'USA' AS country;
```

**Edge case data** (for test validation):
- Customer with zero orders (test orphaned dimension handling)
- Order with null product (should fail referential integrity test)
- Order with negative line item (should fail business rule test)
- Future-dated order (should fail date validation test)

---

## 4. dbt Package Selection

### Decision

**dbt_utils only** (minimal packages per user requirement)

### Rationale

**dbt_utils** provides essential utilities:
- **Testing macros**: `unique_combination_of_columns`, `expression_is_true`, `recency` for source freshness
- **SQL helpers**: `generate_surrogate_key`, `pivot`, `star` (select * except)
- **Date utilities**: `date_spine` for time-series analysis (critical for orders_daily/weekly/monthly)
- **Cross-database compatibility**: Macros abstract SQL dialect differences (future-proofs demo)

**Minimal approach rationale**:
- User explicitly requested "minimal number of libraries"
- dbt_utils is near-universal in production projects (demonstrates real-world usage)
- Avoids package bloat and version conflicts
- Keeps demo focused on core dbt features, not third-party magic

### Alternatives Considered

- **dbt_expectations**: Powerful but adds significant complexity (50+ test types), overkill for demo
- **dbt_metrics**: Deprecated in favor of dbt Semantic Layer (not needed for demo scope)
- **codegen**: Useful for development but not runtime requirement
- **audit_helper**: Testing utility, not needed for initial build

### Implementation Notes

**packages.yml**:
```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.2.0  # Lock version for reproducibility
```

**Usage examples in project**:
- `{{ dbt_utils.surrogate_key(['customer_id', 'valid_from']) }}` for SCD Type 2 keys
- `{{ dbt_utils.date_spine(...) }}` for generating complete date range in time-series models
- `{{ dbt_utils.unique_combination_of_columns(...) }}` for composite key testing

---

## 5. Testing Strategy

### Decision

**Three-tier testing**: Generic tests (schema.yml) + Singular tests (SQL files) + Mock data validation

### Rationale

**Generic tests** (80% of coverage):
- Built-in: `unique`, `not_null`, `relationships`, `accepted_values`
- dbt_utils: `unique_combination_of_columns` for composite keys
- Defined in schema.yml alongside model documentation (documentation-first principle)
- Fast execution, standard patterns

**Singular tests** (20% of coverage, complex business logic):
- Custom SQL queries returning failing rows
- Examples:
  - `assert_order_totals_match_line_items.sql`: Validates order.total = sum(order_items.line_total)
  - `assert_customer_ltv_matches_orders.sql`: Validates customer_analytics.lifetime_value = sum(orders.order_total)
  - `assert_no_negative_revenue.sql`: Validates all revenue fields >= 0
  - `assert_no_future_order_dates.sql`: Validates order_date <= current_date

**Mock data validation**:
- Intentionally include bad data in separate schema (e.g., `raw_data_bad`) for test demonstration
- Show tests catching issues (nulls, referential integrity violations, business rule breaks)
- Document in quickstart.md how to run `dbt test --select <model>` and interpret failures

### Alternatives Considered

- **Unit tests (dbt 1.8+)**: Still preview feature, not stable enough for demo
- **dbt_expectations only**: Too heavyweight, obscures core dbt testing concepts
- **Manual SQL validation**: Not repeatable, defeats automation benefits

### Implementation Notes

**Test-first workflow** (per constitution):
1. Define tests in `schema.yml` for model (before SQL written)
2. Run `dbt test --select <model>` → tests fail (model doesn't exist)
3. Implement model SQL
4. Run `dbt run --select <model>` → model builds
5. Run `dbt test --select <model>` → tests pass
6. Refine model SQL (refactor step in Red-Green-Refactor)

**Test categorization** (per constitution):
- **Primary** (severity: error): unique, not_null on keys; referential integrity
- **Warning** (severity: warn): data freshness, value ranges, distribution checks
- **Informational**: Tracked over time but don't block builds

---

## 6. Materialization Strategy

### Decision

**Views for staging**, **tables for marts**, **incremental for large facts**

### Rationale

**Staging models → Views**:
- Lightweight transformations (rename, cast, basic filters)
- Source data is small enough to scan quickly
- Ensures staging always reflects current source state
- Minimal storage overhead

**Marts → Tables**:
- Complex aggregations and joins (expensive to recompute)
- Frequently queried by analysts
- Storage cost acceptable for demo (MB not GB)
- Predictable query performance

**Large facts → Incremental**:
- `fact_order_items` (150k rows, growing) → incremental append
- Demonstrates incremental model best practices
- Shows `is_incremental()` Jinja block and `unique_key` configuration
- Validates incremental correctness via full-refresh comparison test

**Ephemeral** (sparingly):
- Use for intermediate CTEs that are only referenced once
- Example: `int_orders__with_metrics` (ephemeral) → inlined into `fact_orders`
- Keeps model count manageable

### Alternatives Considered

- **All views**: Simple but poor query performance on complex marts
- **All tables**: Wasteful storage, slow full builds, defeats incremental demo
- **Materialized views** (Postgres-specific): Not cross-database portable, limits demo applicability

### Implementation Notes

**Materialization config** (in `dbt_project.yml`):
```yaml
models:
  ecommerce_analytics:
    staging:
      +materialized: view
    intermediate:
      +materialized: ephemeral  # or view, case-by-case
    marts:
      core:
        +materialized: table
      analytics:
        +materialized: table
        fact_order_items:
          +materialized: incremental
          +unique_key: order_item_id
          +on_schema_change: fail  # Explicit schema enforcement
```

**Incremental strategy** (Postgres):
- Default: `delete+insert` (safest, handles late-arriving data)
- Alternative: `merge` (upsert) for SCD Type 1 updates (not needed in demo)

---

## 7. Slowly Changing Dimensions (SCD Type 2)

### Decision

**dbt snapshots** for customer and product dimensions

### Rationale

**Customer snapshot**:
- Track changes to customer segment over time (new → active → at-risk → dormant)
- Enables historical analysis: "What segment was this customer in when they made this order?"
- Demonstrates snapshot functionality (one of core dbt features)

**Product snapshot**:
- Track changes to product category (products can be recategorized)
- Track price changes (unit_cost, list_price)
- Enables analysis: "What was this product's category when it was ordered?"

**Snapshot strategy**: `timestamp` (using `updated_at` column)
- More explicit than `check` strategy (which snapshots all column changes)
- Requires `updated_at` in source data (easy to add to mock data)
- Clear audit trail of when changes occurred

### Alternatives Considered

- **SCD Type 1** (overwrite): Simpler but loses history, defeats SCD demo purpose
- **SCD Type 3** (previous value column): Limited history, not standard in analytics
- **Manual SCD logic**: Reinvents wheel, snapshots are built-in and well-tested

### Implementation Notes

**customer_snapshot.sql**:
```sql
{% snapshot customer_snapshot %}

{{
  config(
    target_schema='snapshots',
    target_database='ecommerce_dw',
    unique_key='customer_id',
    strategy='timestamp',
    updated_at='updated_at',
  )
}}

SELECT * FROM {{ source('raw_data', 'customers') }}

{% endsnapshot %}
```

**Snapshot workflow**:
1. Initial run: All records inserted with `dbt_valid_from` and `dbt_valid_to = NULL`
2. Subsequent runs: Changed records get `dbt_valid_to = now()`, new version inserted
3. Joins use `dbt_valid_to IS NULL` or date range for point-in-time queries

**Usage in models**:
```sql
-- Join to customer snapshot at order date
SELECT
  o.order_id,
  cs.customer_id,
  cs.segment AS segment_at_order_time
FROM {{ ref('fact_orders') }} o
LEFT JOIN {{ ref('customer_snapshot') }} cs
  ON o.customer_id = cs.customer_id
  AND o.order_date >= cs.dbt_valid_from
  AND (o.order_date < cs.dbt_valid_to OR cs.dbt_valid_to IS NULL)
```

---

## 8. Documentation & Lineage

### Decision

**schema.yml files** for all documentation + **dbt docs generate** for lineage site

### Rationale

**schema.yml approach**:
- Co-located with models (staging, marts folders)
- Single source of truth for model descriptions, column descriptions, and tests
- Enforces documentation-first workflow (document while planning, not after)
- Searchable in generated docs site

**Documentation requirements** (per constitution):
- **Model description**: Purpose (what), grain (one row per...), business logic summary
- **Column descriptions**: Business meaning, not technical (e.g., "Revenue including tax, excluding discounts" not "DECIMAL(10,2)")
- **Assumptions**: Document calculation logic, exclusions, edge case handling

**Lineage graph benefits**:
- Visual DAG (Directed Acyclic Graph) shows dependencies
- Enables impact analysis ("What breaks if I change this source?")
- Demonstrates dbt's automatic lineage tracking via `ref()` and `source()` functions
- Critical for demo presentation

### Alternatives Considered

- **Markdown docs only**: Doesn't integrate with dbt, no lineage, harder to maintain
- **Inline comments in SQL**: Not queryable, doesn't appear in docs site
- **External documentation tools**: Disconnected from code, stale quickly

### Implementation Notes

**schema.yml example** (staging):
```yaml
version: 2

sources:
  - name: raw_data
    description: Raw e-commerce transactional data loaded from mock sources
    schema: raw_data
    tables:
      - name: customers
        description: Customer master data including demographics and signup info
        columns:
          - name: customer_id
            description: Unique identifier for customer; primary key from source CRM system
            tests:
              - unique
              - not_null

models:
  - name: stg_ecommerce__customers
    description: Staging model for customers; standardizes column names and types from raw source
    columns:
      - name: customer_id
        description: Unique customer identifier; matches source raw_data.customers.customer_id
        tests:
          - unique
          - not_null
```

**Generating docs**:
```bash
dbt docs generate  # Creates catalog.json and manifest.json
dbt docs serve     # Starts local server on port 8080
```

---

## 9. Macros & Jinja Templating

### Decision

**Custom macros** for reusable business logic + **Jinja templating** for dynamic SQL

### Rationale

**Macro use cases**:
1. **calculate_days_between**: Reusable date difference calculation (customer recency, order cycle times)
2. **calculate_revenue_with_tax**: Consistent revenue calculation across all models (avoid copy-paste errors)
3. **generate_date_spine**: Create complete date range for time-series models (handles zero-sale days)

**Jinja templating use cases**:
1. **Conditional logic**: `{% if is_incremental() %}` for incremental models
2. **Loops**: Generate repeated metric columns (e.g., revenue by month for 12 months)
3. **Variables**: Environment-specific config (`{{ var('start_date') }}` for filtering)
4. **Set operations**: Build dynamic WHERE clauses based on configuration

**Benefits**:
- DRY (Don't Repeat Yourself): Business logic defined once, used many times
- Maintainability: Change in one place propagates everywhere
- Testability: Macros can be tested independently
- Demonstrates dbt's power beyond basic SQL

### Alternatives Considered

- **Copy-paste SQL**: Error-prone, hard to maintain, defeats best practices
- **Database functions**: Tied to specific database, not portable
- **External Python scripts**: Overkill for SQL transformations

### Implementation Notes

**calculate_days_between.sql** (macro):
```sql
{% macro calculate_days_between(start_date, end_date) %}
  DATEDIFF('day', {{ start_date }}, {{ end_date }})
{% endmacro %}
```

**Usage in model**:
```sql
SELECT
  customer_id,
  {{ calculate_days_between('first_order_date', 'last_order_date') }} AS days_between_first_last_order
FROM {{ ref('int_customers__orders_agg') }}
```

**Jinja example** (dynamic column generation):
```sql
SELECT
  customer_id,
  {% for month in range(1, 13) %}
    SUM(CASE WHEN EXTRACT(MONTH FROM order_date) = {{ month }} THEN order_total ELSE 0 END) AS revenue_month_{{ month }}
    {{ "," if not loop.last }}
  {% endfor %}
FROM {{ ref('fact_orders') }}
GROUP BY 1
```

---

## 10. Analyses & Exposures

### Decision

**Analyses** for sample analytical queries + **Exposures** for BI dashboard documentation

### Rationale

**Analyses** (ad-hoc queries in `analyses/` directory):
- Demonstrate how analysts use marts (real-world usage examples)
- Provide validation queries for testing (e.g., "Top 10 customers by LTV")
- Serve as documentation for common business questions
- Can be run via `dbt compile --select analysis:*` (compiled to target/ but not executed)

**Example analyses**:
1. `top_customers_by_ltv.sql`: "Who are our most valuable customers?"
2. `product_sales_trends.sql`: "Which products are trending up/down?"
3. `campaign_roi_analysis.sql`: "Which marketing campaigns delivered best ROI?"

**Exposures** (document downstream usage):
- Track dashboards/reports that depend on dbt models
- Enables impact analysis ("If I change customer_analytics, what breaks?")
- Documents exposure owner, URL, dependencies
- Appears in lineage graph as leaf nodes

**Example exposure** (in schema.yml):
```yaml
exposures:
  - name: executive_dashboard
    type: dashboard
    owner:
      name: Analytics Team
      email: analytics@example.com
    description: Executive KPI dashboard showing revenue, customer growth, and product performance
    depends_on:
      - ref('customer_analytics')
      - ref('product_performance')
      - ref('orders_monthly')
    url: https://example.com/dashboards/executive  # Mock URL for demo
```

### Alternatives Considered

- **No analyses**: Misses opportunity to show practical usage, less complete demo
- **No exposures**: Lineage graph incomplete, doesn't show downstream impact
- **Separate documentation**: Disconnected from code, stale quickly

### Implementation Notes

**top_customers_by_ltv.sql** (analysis):
```sql
-- Top 10 customers by lifetime value
-- Useful for VIP customer identification and targeted marketing

SELECT
  customer_id,
  customer_name,
  lifetime_value,
  total_orders,
  average_order_value,
  segment
FROM {{ ref('customer_analytics') }}
WHERE lifetime_value > 0
ORDER BY lifetime_value DESC
LIMIT 10
```

**Running analyses**:
```bash
dbt compile --select analysis:top_customers_by_ltv
# Check compiled SQL in target/compiled/ecommerce_analytics/analyses/
# Copy and run in SQL client for validation
```

---

## 11. Pre/Post Hooks

### Decision

**Pre-hook** on staging models for logging, **Post-hook** on marts for granting permissions

### Rationale

**Use cases for hooks** (demonstrates advanced dbt feature):
1. **Logging**: Track model execution times, row counts (useful for monitoring)
2. **Permissions**: Grant SELECT to analytics role after mart builds (production best practice)
3. **Data quality**: Insert test results into audit table (compliance/monitoring)

**Example pre-hook** (logging):
```sql
-- In dbt_project.yml
models:
  ecommerce_analytics:
    staging:
      +pre-hook: "INSERT INTO audit.model_runs (model_name, run_start) VALUES ('{{ this.name }}', NOW())"
```

**Example post-hook** (permissions):
```sql
-- In dbt_project.yml
models:
  ecommerce_analytics:
    marts:
      +post-hook: "GRANT SELECT ON {{ this }} TO analytics_role"
```

**Constraints** (keep minimal):
- Hooks add complexity, use sparingly
- Demo should show 1-2 hook examples, not hook-heavy architecture
- Focus on demonstrating capability, not production-scale hook framework

### Alternatives Considered

- **No hooks**: Misses core dbt feature demonstration
- **Extensive hook framework**: Overkill for demo, obscures core concepts
- **Database triggers**: Not dbt-managed, defeats infrastructure-as-code principle

### Implementation Notes

For demo purposes, **simplified approach**:
- **Pre-hook on staging**: Log model start to temporary table (demonstrates pre-hook syntax)
- **Post-hook on marts**: Simple comment insertion (demonstrates post-hook syntax without actual permissions)
- Document in quickstart.md: "In production, post-hooks typically grant permissions; here we demonstrate syntax"

---

## 12. CI/CD Considerations (Documentation Only)

### Decision

**Document CI/CD approach** without implementing (out of scope for local demo)

### Rationale

**What to document**:
- How `dbt build` would run in CI on pull requests
- How to use `--select state:modified+` for testing only changed models
- Integration with GitHub Actions / GitLab CI (example yaml)
- Slim CI pattern (comparing against production manifest)

**Why not implement**:
- Requires Git hosting (GitHub/GitLab)
- Requires cloud deployment target (defeats "local only" requirement)
- Adds complexity to demo setup (CI credentials, runners)
- Documentation sufficient to demonstrate understanding

**Quickstart.md section**:
- "In production, you would run dbt build in CI..."
- "Example GitHub Actions workflow: ..."
- "This ensures all tests pass before merging..."

### Alternatives Considered

- **Implement local CI**: Overly complex (Gitea server, local runners)
- **Require cloud CI**: Defeats local development focus
- **Ignore CI entirely**: Misses important best practice education

### Implementation Notes

Include in `quickstart.md`:
```markdown
## CI/CD Best Practices (Not Implemented in Demo)

In production, integrate dbt with CI/CD:

1. **On Pull Request**: Run `dbt build --select state:modified+`
2. **On Merge to Main**: Run full `dbt build` and deploy to production
3. **Example GitHub Actions**:
   ```yaml
   name: dbt CI
   on: [pull_request]
   jobs:
     test:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v2
         - run: pip install -r requirements.txt
         - run: dbt deps
         - run: dbt build --select state:modified+
   ```
```

---

## Summary of Key Decisions

| Category | Decision | Rationale |
|----------|----------|-----------|
| **dbt Version** | dbt-core 1.8+ | Latest features, stability, unit test preview |
| **Database** | PostgreSQL 16 | Full SQL support, Docker-friendly, production-representative |
| **Environment** | Docker Compose | Reproducible, isolated, includes MinIO per requirement |
| **Mock Data** | SQL INSERT scripts | Reproducible, version-controlled, test-friendly |
| **Packages** | dbt_utils only | Minimal per user requirement, essential utilities |
| **Testing** | Generic + Singular + Mock validation | Comprehensive coverage, demonstrates test-first workflow |
| **Materialization** | View/Table/Incremental strategy | Optimizes for demo performance and education |
| **SCD** | Snapshots (Type 2) | Demonstrates core dbt feature, enables historical analysis |
| **Documentation** | schema.yml + dbt docs | Enforces documentation-first, generates lineage graph |
| **Macros** | Custom business logic macros | DRY principle, demonstrates Jinja power |
| **Analyses** | Sample analytical queries | Shows real-world usage, validates marts |
| **Exposures** | BI dashboard documentation | Completes lineage graph, tracks downstream dependencies |
| **Hooks** | Minimal (1-2 examples) | Demonstrates capability without overcomplicating |

---

## Next Steps (Phase 1)

1. **Generate data-model.md**: Define schemas for all entities (sources, dimensions, facts, marts)
2. **Create contracts/**: Document model interfaces (grain, columns, relationships)
3. **Generate quickstart.md**: Step-by-step setup and execution guide
4. **Update agent context**: Add dbt-specific context for implementation phase
