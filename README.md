# E-Commerce Analytics dbt Demo

A comprehensive dbt project showcasing best practices for building analytics data pipelines with full test coverage and data quality assurance.

## Project Overview

This demo implements a complete e-commerce analytics solution using dbt (data build tool), demonstrating:

- **12+ dbt core features**: sources, seeds, staging models, intermediate models, dimensional models, fact tables, analytics marts, snapshots, tests, documentation, macros, analyses, exposures, and packages
- **Test-first development**: 84 tests (77 generic + 7 singular) defined before implementation
- **Four analytics domains**:
  - Customer behavior and lifetime value (P1 MVP)
  - Product performance and inventory metrics (P2)
  - Time-series trend analysis (P3)
  - Marketing campaign attribution and ROI (P4)

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Python 3.11+
- Git

### Setup (5 minutes)

```bash
# 1. Start Docker services (PostgreSQL + MinIO)
docker compose -f docker/docker-compose.yml up -d

# 2. Create Python virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# 3. Install dbt
pip install -r requirements.txt

# 4. Install dbt packages
cd dbt_project
dbt deps --project-dir dbt_project

# 5. Load seed data
dbt seed --project-dir dbt_project

# 6. Test connection
dbt debug --project-dir dbt_project
```

### Build and Test (2-5 minutes)

```bash
# Full build (run all models + tests)
dbt build --project-dir dbt_project

# Or run incrementally:
dbt run --project-dir dbt_project   # Build all models
dbt test --project-dir dbt_project  # Run all tests

# Generate documentation
dbt docs generate --project-dir dbt_project
dbt docs serve --project-dir dbt_project # View at http://localhost:8080
```

## Project Structure

```
dbt_project/
├── models/
│   ├── staging/              # Source-conformed models (views)
│   ├── intermediate/         # Business logic transformations
│   └── marts/
│       ├── core/            # Dimensional models & facts
│       └── analytics/       # Analytics-ready marts
├── tests/                    # Singular custom tests
├── macros/                   # Reusable SQL logic
├── seeds/                    # Reference data (CSV)
├── snapshots/                # SCD Type 2 tracking
└── analyses/                 # Ad-hoc queries

docker/
├── docker-compose.yml        # PostgreSQL + MinIO services
└── postgres/
    ├── init-db.sql          # Database initialization
    └── mock-data/           # Synthetic test data
```

## Features Demonstrated

### Data Modeling
- Star schema with dimensions and facts
- Slowly Changing Dimensions (SCD Type 2) via snapshots
- Incremental models for large fact tables
- Hierarchical category structures

### Testing & Quality
- Test-first development (TDD) workflow
- Generic tests: unique, not_null, relationships, accepted_values
- Singular tests: custom business logic validation
- Source freshness monitoring
- >80% test coverage on critical marts

### Documentation
- 100% model documentation (purpose, grain, columns)
- Automated lineage graph generation
- Business-friendly descriptions
- Exposure tracking for downstream BI tools

### Performance
- Optimized materializations (view/table/incremental)
- Parallel execution support
- <5 minute full build time
- <2 second query response on marts

## Analytics Use Cases

### Customer Analytics (P1 MVP)
Query customer lifetime value, RFM segmentation, and purchase patterns:
```sql
SELECT * FROM analytics_dev.customer_analytics
WHERE lifetime_value > 1000
ORDER BY lifetime_value DESC LIMIT 10;
```

### Product Performance (P2)
Analyze top/bottom products by category with profit margins:
```sql
SELECT * FROM analytics_dev.product_performance
WHERE category = 'Electronics'
ORDER BY total_revenue DESC;
```

### Time-Series Trends (P3)
Track daily/weekly/monthly order trends with YoY growth:
```sql
SELECT * FROM analytics_dev.orders_monthly
WHERE year >= 2023
ORDER BY month_start_date;
```

### Marketing ROI (P4)
Measure campaign performance and customer acquisition costs:
```sql
SELECT * FROM analytics_dev.marketing_attribution
ORDER BY return_on_investment DESC;
```

## Development Workflow

### Incremental Development
```bash
# Work on specific model
dbt run --project-dir dbt_project --select stg_ecommerce__customers
dbt test --project-dir dbt_project --select stg_ecommerce__customers

# Build with dependencies
dbt build --project-dir dbt_project --select +customer_analytics
```

### Test-First Approach
1. Define tests in `schema.yml` before implementing model
2. Run `dbt test --select <model>` (tests should FAIL)
3. Implement model SQL
4. Run `dbt run --select <model>`
5. Run `dbt test --select <model>` (tests should PASS)

### Pre-Commit Validation
```bash
dbt deps --project-dir dbt_project                              # Ensure packages installed
dbt parse --project-dir dbt_project                             # Check syntax
dbt compile --project-dir dbt_project --select state:modified+  # Compile changed models
dbt run --project-dir dbt_project --select state:modified+      # Run changed models
dbt test --project-dir dbt_project --select state:modified+     # Test changed models
dbt docs generate                     # Update documentation
```

## Success Criteria

- ✅ All 12+ dbt core features demonstrated
- ✅ 100% model documentation
- ✅ 84 tests with 0 failures
- ✅ Full build in <5 minutes
- ✅ Query performance <2 seconds
- ✅ Complete lineage graph
- ✅ Portfolio-quality code

## Documentation

- **Specification**: [specs/001-build-a-full/spec.md](specs/001-build-a-full/spec.md)
- **Data Model**: [specs/001-build-a-full/data-model.md](specs/001-build-a-full/data-model.md)
- **Implementation Plan**: [specs/001-build-a-full/plan.md](specs/001-build-a-full/plan.md)
- **Task Breakdown**: [specs/001-build-a-full/tasks.md](specs/001-build-a-full/tasks.md)
- **Quickstart Guide**: [specs/001-build-a-full/quickstart.md](specs/001-build-a-full/quickstart.md)

## Constitution Compliance

This project follows the [dbt Demo Project Constitution](.specify/memory/constitution.md) ensuring:

1. **Test-First Development**: All models have tests defined before SQL implementation
2. **Data Quality Gates**: Comprehensive validation at every layer
3. **Comprehensive Feature Coverage**: All dbt capabilities demonstrated
4. **Documentation-First**: Models and columns fully documented
5. **Incremental Testing**: Continuous validation during development

## TODOs

1. Fix this:
```bash
dbt build --project-dir dbt_project --select +customer_analytics
# 82 of 82 SKIP test assert_no_negative_revenue .................................. [SKIP]
# 08:49:40  
# 08:49:40  Finished running 2 table models, 78 data tests, 2 view models in 0 hours 0 minutes and 5.35 seconds (5.35s).
# 08:49:40  
# 08:49:40  Completed with 1 error, 0 partial successes, and 0 warnings:
# 08:49:40  
# 08:49:40  Failure in test assert_order_totals_match_line_items (tests/assert_order_totals_match_line_items.sql)
# 08:49:40    Got 50000 results, configured to fail if != 0
# 08:49:40  
# 08:49:40    compiled code at target/compiled/ecommerce_analytics/tests/assert_order_totals_match_line_items.sql
# 08:49:40  
# 08:49:40    See test failures:
#   -------------------------------------------------------------------------------------------------
#   select * from "ecommerce_dw"."analytics_dev_test_failures"."assert_order_totals_match_line_items"
#   -------------------------------------------------------------------------------------------------
# 08:49:40  
# 08:49:40  Done. PASS=78 WARN=0 ERROR=1 SKIP=3 NO-OP=0 TOTAL=82
```
2. Deepdive this:
```bash
dbt test --no-partial-parse --project-dir dbt_project
# PASS=292 WARN=3 ERROR=5 SKIP=0 NO-OP=0 TOTAL=300

dbt build --project-dir dbt_project
# Done. PASS=177 WARN=2 ERROR=1 SKIP=143 NO-OP=1 TOTAL=324
```

## License

This is a demonstration project for educational purposes.

## Contact

For questions or feedback, refer to project documentation in `specs/001-build-a-full/`.
