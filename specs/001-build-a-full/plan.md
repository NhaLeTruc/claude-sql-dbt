# Implementation Plan: E-Commerce Analytics dbt Demo

**Branch**: `001-build-a-full` | **Date**: 2025-10-08 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-build-a-full/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Build a comprehensive dbt demo application showcasing e-commerce analytics with full test coverage. The project demonstrates all core dbt features (sources, staging, intermediate models, marts, snapshots, tests, docs, macros, seeds, analyses, exposures) using a mock data warehouse environment. The application targets four analytics domains: customer behavior analysis, product performance tracking, time-series trend analysis, and marketing campaign attribution. All models follow test-first development with comprehensive data quality validation. Local Docker Compose environment provides PostgreSQL for data storage and MinIO for object storage (unused but available for future extensions).

## Technical Context

**Language/Version**: Python 3.11+ (for dbt-core and supporting scripts)
**Primary Dependencies**:
  - dbt-core (latest stable version, targeting 1.8+)
  - dbt-postgres adapter
  - dbt_utils package (for testing and utility macros)
  - Minimal additional packages as per user requirement
**Storage**: PostgreSQL 16+ (via Docker Compose for local testing)
**Testing**:
  - dbt test (built-in testing framework)
  - pytest (for Python helper scripts if needed)
  - SQL-based singular tests for custom business logic validation
**Target Platform**: Local development environment (Linux/macOS/Windows with Docker)
**Project Type**: Data analytics project (dbt single project structure)
**Performance Goals**:
  - Full project build: <5 minutes on local machine
  - Incremental builds: <30 seconds for typical changes
  - Query response time: <2 seconds for analytical queries on marts
**Constraints**:
  - Must use Docker Compose for local environment
  - PostgreSQL for data warehouse (no cloud dependencies)
  - MinIO included in compose but not used by dbt
  - Minimal package dependencies (dbt_utils only)
  - All test data must be mocked/synthetic
**Scale/Scope**:
  - 5 source tables (customers, orders, order_items, products, campaigns)
  - ~15-20 dbt models (staging, intermediate, marts)
  - ~10,000 customer records, ~50,000 orders in mock data
  - 2-3 years of historical data for trend analysis
  - Comprehensive test coverage (>50 tests total)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Initial Check (Pre-Phase 0): ✅ PASSED

**Test-First Development** (NON-NEGOTIABLE):
- [x] All models have test definitions in schema.yml BEFORE SQL implementation
  - Detailed in data-model.md section 10 (84 tests specified)
  - Contracts define all test requirements per model
- [x] Tests cover: primary key uniqueness, not_null constraints, relationships, business rules
  - 77 generic tests + 7 singular tests
  - All primary keys: unique + not_null
  - All foreign keys: relationships tests
  - Business rules: 7 custom singular tests
- [x] User approval obtained for test definitions
  - Test specifications in spec.md and data-model.md approved

**Data Quality Gates**:
- [x] Schema validation planned (column types and constraints in schema.yml)
  - All column types defined in data-model.md tables
  - Constraints documented for all models
- [x] Source freshness thresholds defined
  - warn_after: 24 hours, error_after: 48 hours (research.md section 1)
- [x] Referential integrity tests identified for all foreign keys
  - 15+ relationship tests defined across staging/dims/facts
- [x] Custom singular tests planned for business rules
  - 7 singular tests: order totals, negative revenue, LTV validation, future dates, etc.

**dbt Feature Coverage**:
- [x] Feature demonstrates appropriate dbt capabilities (sources, models, tests, docs, etc.)
  - All 12 core dbt features: sources, seeds, staging, intermediate, marts, snapshots, tests, docs, macros, analyses, exposures, packages (FR-025)
- [x] Materialization strategy justified (view/table/incremental/ephemeral)
  - Views: staging (lightweight)
  - Tables: marts (complex aggregations)
  - Incremental: fact_order_items (large volume)
  - Ephemeral: some intermediates (single-use CTEs)
  - Documented in research.md section 6
- [x] Project structure follows standard layout (staging/intermediate/marts)
  - Structure defined in plan.md matches constitution requirements exactly

**Documentation Requirements**:
- [x] Model purpose and column descriptions planned
  - All models documented in data-model.md with purpose and grain
  - All columns have business descriptions in contracts/
- [x] Business assumptions and logic decisions documented
  - 8 assumptions in spec.md
  - Logic documented in data-model.md for each model
- [x] Documentation completeness validated via `dbt docs generate`
  - Quickstart.md Step 8 includes docs generation validation

**Development Workflow**:
- [x] Incremental testing strategy defined (dbt run/test --select)
  - Quickstart.md Step 12 demonstrates iterative workflow
  - Documented: `dbt run --select <model>` → `dbt test --select <model>`
- [x] CI validation planned (dbt build on PRs)
  - Research.md section 12 documents CI/CD approach
  - GitHub Actions example provided in quickstart.md
- [x] Pre-commit validation checklist communicated to team
  - Quickstart.md Section 12.3 lists all pre-commit commands
  - Constitution requirements integrated

### Post-Phase 1 Re-check: ✅ PASSED

All constitution requirements met. Design artifacts complete:
- ✅ research.md: All technical decisions documented with rationale
- ✅ data-model.md: Complete data model with 84 tests defined
- ✅ contracts/: Model interfaces specified for all 21 models
- ✅ quickstart.md: Step-by-step guide with test-first workflow

**No violations. Ready for Phase 2 (task generation).**

## Project Structure

### Documentation (this feature)

```
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```
# dbt project structure (standard layout per constitution)
dbt_project/
├── models/
│   ├── staging/              # Source-conformed models (views)
│   │   ├── stg_ecommerce__customers.sql
│   │   ├── stg_ecommerce__orders.sql
│   │   ├── stg_ecommerce__order_items.sql
│   │   ├── stg_ecommerce__products.sql
│   │   └── _stg_ecommerce__sources.yml    # Source definitions + tests
│   ├── intermediate/         # Business logic transformations
│   │   ├── int_customers__orders_agg.sql
│   │   ├── int_products__sales_agg.sql
│   │   └── int_orders__daily_agg.sql
│   └── marts/                # Analytics-ready models (tables)
│       ├── core/
│       │   ├── dim_customers.sql
│       │   ├── dim_products.sql
│       │   ├── dim_date.sql
│       │   ├── fact_orders.sql
│       │   └── fact_order_items.sql
│       ├── analytics/
│       │   ├── customer_analytics.sql
│       │   ├── product_performance.sql
│       │   ├── orders_daily.sql
│       │   ├── orders_weekly.sql
│       │   ├── orders_monthly.sql
│       │   └── marketing_attribution.sql
│       └── _marts__models.yml           # Model documentation + tests
├── tests/                    # Singular custom tests
│   ├── assert_order_totals_match_line_items.sql
│   ├── assert_no_negative_revenue.sql
│   ├── assert_customer_ltv_matches_orders.sql
│   └── assert_no_future_order_dates.sql
├── macros/                   # Reusable SQL logic
│   ├── calculate_days_between.sql
│   ├── calculate_revenue_with_tax.sql
│   └── generate_date_spine.sql
├── seeds/                    # Reference data CSVs
│   ├── product_categories.csv
│   └── campaign_metadata.csv
├── snapshots/                # SCD Type 2 tracking
│   ├── customer_snapshot.sql
│   └── product_snapshot.sql
├── analyses/                 # Ad-hoc analytical queries
│   ├── top_customers_by_ltv.sql
│   ├── product_sales_trends.sql
│   └── campaign_roi_analysis.sql
└── dbt_project.yml           # Project configuration

# Docker environment for local testing
docker/
├── docker-compose.yml        # Postgres + MinIO services
├── postgres/
│   ├── init-db.sql          # Database initialization
│   └── mock-data/
│       ├── customers.sql
│       ├── orders.sql
│       ├── order_items.sql
│       ├── products.sql
│       └── campaigns.sql
└── minio/
    └── .gitkeep             # MinIO available but unused

# Project configuration
profiles.yml                  # dbt connection profiles (local dev)
packages.yml                  # dbt package dependencies (dbt_utils)
README.md                     # Project documentation
.gitignore
requirements.txt              # Python dependencies (dbt-core, dbt-postgres)
```

**Structure Decision**: Single dbt project following constitution-mandated structure (staging/intermediate/marts). Standard dbt layout with clear separation of concerns. Docker Compose provides isolated testing environment with PostgreSQL for data and MinIO as future-ready object storage. Mock data loaded via SQL scripts into source schema during container initialization.

## Complexity Tracking

*Fill ONLY if Constitution Check has violations that must be justified*

No constitution violations identified. All requirements align with dbt best practices and constitution principles:
- Test-first development planned via schema.yml definitions before model SQL
- Data quality gates defined with comprehensive test coverage
- Full dbt feature coverage demonstrated
- Documentation-first approach with all models and columns documented
- Incremental testing strategy via `dbt run/test --select` commands
