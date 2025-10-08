# Quickstart Guide: E-Commerce Analytics dbt Demo

**Purpose**: Step-by-step guide to set up, build, test, and explore the dbt demo project
**Date**: 2025-10-08
**Estimated Time**: 30 minutes

---

## Prerequisites

Before starting, ensure you have:

- **Docker** and **Docker Compose** installed
  - Verify: `docker --version` and `docker-compose --version`
  - Docker 20+ and Docker Compose 2+ recommended

- **Python 3.11+** installed
  - Verify: `python3 --version`

- **Git** installed (if cloning repository)
  - Verify: `git --version`

- **Terminal/Command Line** access
  - macOS/Linux: Use Terminal
  - Windows: Use PowerShell, Command Prompt, or WSL2

---

## Step 1: Environment Setup (5 minutes)

### 1.1 Start Docker Services

Navigate to the project root and start PostgreSQL + MinIO:

```bash
# Navigate to project root
cd /path/to/claude-sql-dbt

# Start services in detached mode
docker-compose -f docker/docker-compose.yml up -d

# Verify services are running
docker-compose -f docker/docker-compose.yml ps

# Expected output:
# NAME                IMAGE             STATUS
# postgres_dbt        postgres:16       Up (healthy)
# minio_dbt           minio/minio       Up
```

**What happened?**
- PostgreSQL 16 started on `localhost:5432`
- Database `ecommerce_dw` created with user `dbt_user` / password `dbt_password`
- Schema `raw_data` created
- Mock data loaded from `docker/postgres/mock-data/*.sql`
- MinIO started on `localhost:9000` (available but unused by dbt)

### 1.2 Install Python Dependencies

Create virtual environment and install dbt:

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
# macOS/Linux:
source venv/bin/activate
# Windows:
# venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Verify dbt installation
dbt --version

# Expected output:
# Core:
#   - installed: 1.8.x
#   - latest:    1.8.x
# Plugins:
#   - postgres: 1.8.x
```

**requirements.txt contents**:
```
dbt-core>=1.8.0,<1.9.0
dbt-postgres>=1.8.0,<1.9.0
```

---

## Step 2: Configure dbt (5 minutes)

### 2.1 Verify profiles.yml

Check that `profiles.yml` exists in project root:

```yaml
ecommerce_analytics:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      port: 5432
      user: dbt_user
      password: dbt_password
      dbname: ecommerce_dw
      schema: analytics_dev
      threads: 4
      keepalives_idle: 0
      connect_timeout: 10
```

**Key settings**:
- `target: dev` - Default to development environment
- `schema: analytics_dev` - Models built in this schema
- `threads: 4` - Parallel model execution (adjust for your machine)

### 2.2 Test Connection

Verify dbt can connect to PostgreSQL:

```bash
cd dbt_project
dbt debug

# Expected output (scroll to bottom):
# All checks passed!
```

**Troubleshooting**:
- If connection fails: Check Docker is running (`docker-compose ps`)
- If schema error: PostgreSQL may still be initializing (wait 30 seconds, retry)
- If password error: Verify profiles.yml matches docker-compose.yml credentials

---

## Step 3: Install dbt Packages (2 minutes)

### 3.1 Install dbt_utils

```bash
# Still in dbt_project/ directory
dbt deps

# Expected output:
# Installing dbt-labs/dbt_utils@1.2.0
# Installed 1 package
```

**What happened?**
- dbt read `packages.yml`
- Downloaded `dbt_utils` package to `dbt_packages/` directory
- Package provides utility macros (surrogate_key, date_spine, testing macros)

---

## Step 4: Verify Source Data (3 minutes)

### 4.1 Check Source Freshness

Verify mock data is loaded and "fresh":

```bash
dbt source freshness

# Expected output:
# Checked freshness of 5 sources:
#   - raw_data.customers (PASS)
#   - raw_data.orders (PASS)
#   - raw_data.order_items (PASS)
#   - raw_data.products (PASS)
#   - raw_data.campaigns (PASS - seed, no freshness check)
```

**What this checks**:
- Source tables exist in PostgreSQL
- Data is "fresh" per configured thresholds (warn_after: 24h, error_after: 48h)
- Validates connection to source schema `raw_data`

### 4.2 Inspect Source Data (Optional)

Connect to PostgreSQL to view mock data:

```bash
# Using psql (if installed)
psql -h localhost -U dbt_user -d ecommerce_dw

# Or using Docker exec
docker exec -it postgres_dbt psql -U dbt_user -d ecommerce_dw
```

```sql
-- Check row counts
SELECT 'customers' AS table_name, COUNT(*) FROM raw_data.customers
UNION ALL
SELECT 'orders', COUNT(*) FROM raw_data.orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM raw_data.order_items
UNION ALL
SELECT 'products', COUNT(*) FROM raw_data.products;

-- Expected output:
-- table_name    | count
-- --------------|-------
-- customers     | 10000
-- orders        | 50000
-- order_items   | 150000
-- products      | 100

-- Exit psql
\q
```

---

## Step 5: Load Seed Data (2 minutes)

### 5.1 Load Reference Data

Load CSV seed files (product categories, campaign metadata):

```bash
dbt seed

# Expected output:
# Running with dbt=1.8.x
# Seeding 2 seed files:
#   - product_categories [INSERT 5]
#   - campaign_metadata [INSERT 10]
# Completed successfully
```

**What happened?**:
- CSV files from `seeds/` directory loaded into database
- Tables created in `analytics_dev` schema
- Referenced by models via `{{ ref('product_categories') }}`

### 5.2 Verify Seeds

```sql
-- In psql
SELECT * FROM analytics_dev.product_categories;
SELECT * FROM analytics_dev.campaign_metadata;
```

---

## Step 6: Build dbt Models (10 minutes)

### 6.1 Run Full Build

Build all models and run all tests:

```bash
# Full build: run models + snapshots + tests
dbt build

# Expected execution order:
# 1. Staging models (views)
# 2. Intermediate models (views/ephemeral)
# 3. Dimensional models (tables)
# 4. Fact tables (tables/incremental)
# 5. Mart models (tables)
# 6. Snapshots (SCD Type 2)
# 7. All tests (generic + singular)

# Expected output:
# Completed successfully
# Done. PASS=84 WARN=0 ERROR=0 SKIP=0 TOTAL=84
```

**What happened?**:
- ~21 models built (staging → intermediate → dims → facts → marts)
- ~2 snapshots executed (customer_snapshot, product_snapshot)
- ~84 tests run (77 generic + 7 singular)
- All artifacts in `target/` directory

**Build Performance**:
- Expected time: 2-5 minutes on modern laptop
- Constitut ion target: <5 minutes ✅

### 6.2 Inspect Built Models

```sql
-- In psql
\dn  -- List schemas
-- Should see: analytics_dev, snapshots

\dt analytics_dev.*  -- List models
-- Should see: stg_*, int_*, dim_*, fact_*, *_analytics, *_performance, etc.

-- Query a mart
SELECT * FROM analytics_dev.customer_analytics LIMIT 5;
```

---

## Step 7: Run Tests (5 minutes)

### 7.1 Run All Tests

```bash
# Run all tests
dbt test

# Expected output:
# Running tests...
# Completed successfully
# Done. PASS=84 WARN=0 ERROR=0 SKIP=0 TOTAL=84
```

**Test breakdown**:
- **Generic tests**: 77 (unique, not_null, relationships, accepted_values)
- **Singular tests**: 7 (custom business logic validation)

### 7.2 Run Specific Test Types

```bash
# Run only generic tests
dbt test --select test_type:generic

# Run only singular tests
dbt test --select test_type:singular

# Run tests for specific model
dbt test --select customer_analytics

# Run tests for model + upstream dependencies
dbt test --select +customer_analytics
```

### 7.3 View Test Results

Check test failures (if any):

```bash
# Tests that failed are stored in database (if configured)
# Check target/run_results.json for detailed results

cat target/run_results.json | grep -A 5 '"status": "fail"'
```

---

## Step 8: Generate Documentation (3 minutes)

### 8.1 Generate Docs Site

```bash
# Generate catalog and manifest
dbt docs generate

# Expected output:
# Building catalog...
# Catalog written to target/catalog.json
# Manifest written to target/manifest.json
```

### 8.2 Serve Docs Locally

```bash
# Start local docs server
dbt docs serve

# Expected output:
# Serving docs at http://localhost:8080
# Press Ctrl+C to exit
```

**Open browser**: Navigate to `http://localhost:8080`

**Explore docs**:
- **Project Overview**: Summary of models, tests, sources
- **Database Tab**: Browse all models, click to see details
- **Lineage Graph**: Visual DAG showing model dependencies
  - Click any model → "View Lineage Graph"
  - See upstream sources and downstream consumers
- **Search**: Search for models, columns, or descriptions
- **Model Details**: Click model → see columns, tests, SQL code

**Key views to explore**:
1. `customer_analytics` lineage (traces from raw_data.customers → staging → marts)
2. `fact_order_items` incremental model (see `is_incremental()` logic)
3. `customer_snapshot` snapshot (see SCD Type 2 columns)

---

## Step 9: Run Analyses (2 minutes)

### 9.1 Compile Analytical Queries

Analyses are ad-hoc queries that demonstrate model usage:

```bash
# Compile analyses (doesn't execute, just validates SQL)
dbt compile --select analysis:*

# Expected output:
# Compiling 3 analyses...
# Completed successfully
```

**Compiled SQL location**: `target/compiled/ecommerce_analytics/analyses/`

### 9.2 Run Sample Analyses

Copy compiled SQL and run in psql:

```bash
# Example: Top customers by LTV
cat target/compiled/ecommerce_analytics/analyses/top_customers_by_ltv.sql
```

```sql
-- In psql, paste compiled SQL
-- Example output:
-- customer_name | lifetime_value | total_orders
-- --------------|----------------|-------------
-- Customer 5432 | 12,450.50     | 45
-- Customer 1234 | 11,230.75     | 38
-- ...
```

---

## Step 10: Incremental Model Testing (3 minutes)

### 10.1 Test Incremental Build

Demonstrate incremental model efficiency:

```bash
# Full refresh (rebuild from scratch)
dbt run --select fact_order_items --full-refresh

# Expected output:
# Building fact_order_items (table, full refresh)
# Rows: 150,000

# Incremental run (only new data)
dbt run --select fact_order_items

# Expected output:
# Building fact_order_items (incremental)
# Rows: 0 (no new data since last run)
```

### 10.2 Validate Incremental Correctness

Compare incremental vs full refresh results:

```sql
-- In psql
-- Full refresh
SELECT COUNT(*), SUM(line_total) FROM analytics_dev.fact_order_items;

-- Record results, then run incremental
-- Results should match (validates incremental correctness)
```

---

## Step 11: Snapshot Testing (2 minutes)

### 11.1 Run Snapshots

```bash
# Run snapshots
dbt snapshot

# Expected output:
# Snapshotting 2 snapshots...
# - customer_snapshot (created, 10000 rows)
# - product_snapshot (created, 100 rows)
```

### 11.2 View Snapshot Data

```sql
-- In psql
SELECT
  customer_id,
  customer_segment,
  dbt_valid_from,
  dbt_valid_to,
  dbt_updated_at
FROM snapshots.customer_snapshot
WHERE customer_id = 1;

-- Expected: One row with dbt_valid_to = NULL (current version)
```

### 11.3 Simulate Data Change

```sql
-- Update source data (simulate customer segment change)
UPDATE raw_data.customers
SET segment = 'vip', updated_at = NOW()
WHERE customer_id = 1;
```

```bash
# Re-run snapshot
dbt snapshot

# Expected output:
# - customer_snapshot (updated, 1 new row)
```

```sql
-- View snapshot history
SELECT
  customer_id,
  customer_segment,
  dbt_valid_from,
  dbt_valid_to
FROM snapshots.customer_snapshot
WHERE customer_id = 1
ORDER BY dbt_valid_from;

-- Expected: Two rows
-- Row 1: old segment, dbt_valid_to = NOW (closed)
-- Row 2: 'vip' segment, dbt_valid_to = NULL (current)
```

---

## Step 12: Development Workflow (5 minutes)

### 12.1 Iterative Development

Demonstrate iterative model development:

```bash
# Develop single model
dbt run --select stg_ecommerce__customers

# Test single model
dbt test --select stg_ecommerce__customers

# Build model + upstream dependencies
dbt build --select +customer_analytics

# Build model + downstream consumers
dbt build --select customer_analytics+
```

### 12.2 Modify a Model

Example: Add new column to `customer_analytics`

1. Edit `models/marts/analytics/customer_analytics.sql`
2. Add column: `days_since_signup`
3. Update `schema.yml` with column description + tests
4. Run iterative build:

```bash
# Rebuild only customer_analytics
dbt run --select customer_analytics

# Test changes
dbt test --select customer_analytics

# Verify in docs
dbt docs generate
dbt docs serve
```

### 12.3 Pre-Commit Validation

Before committing changes, run full validation:

```bash
# Constitution-mandated pre-commit checks
dbt deps                              # Ensure packages installed
dbt parse                             # Check syntax
dbt compile --select state:modified+  # Compile changed models (requires state)
dbt run --select state:modified+      # Run changed models
dbt test --select state:modified+     # Test changed models
dbt docs generate                     # Update docs
```

**Note**: `state:modified` requires manifest from previous run. For first-time, use `dbt build` instead.

---

## Common Tasks Reference

### Build Commands

```bash
# Build everything (models + tests)
dbt build

# Build specific model
dbt build --select customer_analytics

# Build model + dependencies
dbt build --select +customer_analytics+

# Build by tag
dbt build --select tag:daily

# Build by directory
dbt build --select models/marts/analytics/*
```

### Test Commands

```bash
# Run all tests
dbt test

# Test specific model
dbt test --select customer_analytics

# Test with increased verbosity
dbt test --select customer_analytics --store-failures

# Test and save failures to table
dbt test --store-failures-as table
```

### Documentation Commands

```bash
# Generate docs
dbt docs generate

# Serve docs
dbt docs serve --port 8080

# Generate and serve
dbt docs generate && dbt docs serve
```

### Cleaning Commands

```bash
# Remove target/ directory (compiled files)
dbt clean

# Drop all models (clean database)
dbt run-operation drop_all_models  # Custom macro (if defined)

# Or manually in psql:
# DROP SCHEMA analytics_dev CASCADE;
```

---

## Troubleshooting

### Issue: Connection Refused

**Symptoms**: `dbt debug` fails with "connection refused"

**Solution**:
```bash
# Check Docker services
docker-compose -f docker/docker-compose.yml ps

# Restart services
docker-compose -f docker/docker-compose.yml restart postgres_dbt

# Check logs
docker-compose -f docker/docker-compose.yml logs postgres_dbt
```

### Issue: Models Not Building

**Symptoms**: `dbt run` fails with "relation does not exist"

**Solution**:
```bash
# Check source data loaded
dbt source freshness

# Rebuild from scratch
dbt clean
dbt build
```

### Issue: Tests Failing

**Symptoms**: `dbt test` shows failures

**Solution**:
```bash
# Identify failing test
dbt test --select test_name --store-failures

# Query failed rows (stored in database)
SELECT * FROM analytics_dev.test_name;

# Fix underlying data issue or model logic
```

### Issue: Docs Not Loading

**Symptoms**: `dbt docs serve` shows blank page

**Solution**:
```bash
# Regenerate docs
dbt docs generate

# Clear browser cache
# Try incognito/private browsing

# Check port not in use
# Change port: dbt docs serve --port 8081
```

---

## Next Steps

After completing the quickstart, explore:

1. **Modify models**: Add new columns, change logic, rebuild
2. **Add custom tests**: Create singular tests for business rules
3. **Experiment with materializations**: Change table → view, observe performance
4. **Create new analyses**: Write ad-hoc queries using marts
5. **Define exposures**: Document downstream BI dashboards
6. **Customize macros**: Write reusable SQL logic in `macros/`
7. **Explore packages**: Try `dbt_expectations` for advanced testing

---

## Production Deployment (Future)

While this demo runs locally, production deployment would include:

1. **CI/CD Integration**:
   ```yaml
   # .github/workflows/dbt-ci.yml
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

2. **Scheduled Runs**:
   - dbt Cloud: Configure daily/hourly jobs
   - Airflow: DAG with dbt CLI commands
   - Cron: `0 2 * * * cd /dbt && dbt build`

3. **Production Profiles**:
   ```yaml
   ecommerce_analytics:
     target: prod
     outputs:
       prod:
         type: postgres
         host: prod-db.example.com
         schema: analytics_prod
         # Use environment variables for credentials
         user: "{{ env_var('DBT_USER') }}"
         password: "{{ env_var('DBT_PASSWORD') }}"
   ```

4. **Monitoring**:
   - dbt Cloud: Built-in monitoring and alerting
   - dbt artifacts: Parse `run_results.json` for failures
   - Custom: Send metrics to Datadog/Grafana

---

## Resources

- **dbt Documentation**: https://docs.getdbt.com/
- **dbt_utils Package**: https://hub.getdbt.com/dbt-labs/dbt_utils/
- **dbt Discourse Community**: https://discourse.getdbt.com/
- **Project Constitution**: [.specify/memory/constitution.md](../.specify/memory/constitution.md)
- **Data Model Spec**: [data-model.md](data-model.md)
- **Model Contracts**: [contracts/](contracts/)

---

## Success Criteria Validation

After completing this quickstart, verify success criteria met:

- [ ] **SC-001**: All 12+ core dbt features demonstrated ✅
- [ ] **SC-002**: All models have complete documentation (check docs site) ✅
- [ ] **SC-003**: Test coverage >50 tests (84 tests run) ✅
- [ ] **SC-004**: All tests pass (PASS=84, ERROR=0) ✅
- [ ] **SC-007**: Full build completes in <5 minutes ✅
- [ ] **SC-010**: Docs site is navigable (lineage graph works) ✅
- [ ] **SC-012**: Project structure understood in <15 minutes ✅

**Congratulations!** You've successfully built and validated a production-quality dbt demo project.
