# dbt Demo Project Constitution

<!--
Sync Impact Report:
- Version change: [INITIAL] → 1.0.0
- New constitution created for dbt demo project
- Principles added:
  1. Test-First Data Development (NON-NEGOTIABLE)
  2. Data Quality Assurance Gates
  3. Comprehensive dbt Feature Coverage
  4. Documentation-First Models
  5. Incremental Development & Testing
- Templates requiring updates:
  ✅ plan-template.md - constitution check gates added
  ✅ spec-template.md - data quality requirements aligned
  ✅ tasks-template.md - test-first task ordering confirmed
- Follow-up TODOs: None - all placeholders filled
-->

## Core Principles

### I. Test-First Data Development (NON-NEGOTIABLE)

Every dbt model, macro, and transformation MUST follow Test-Driven Development:

- **Tests written first**: Generic tests (unique, not_null, relationships, accepted_values) and custom data tests defined in schema.yml BEFORE model SQL is written
- **User approval required**: Test definitions reviewed and approved before implementation begins
- **Red-Green-Refactor**: Tests MUST fail initially, then pass after implementation, then code refined
- **No untested models**: Every model must have at least one test; critical models require multiple tests covering business logic

**Rationale**: Data pipelines failing silently cause severe downstream impact. TDD ensures quality is built-in from the start, not bolted on later. This prevents data quality issues from reaching production and builds confidence in analytics.

### II. Data Quality Assurance Gates

All data transformations MUST pass quality gates before promotion:

- **Schema validation**: All models must declare expected column types and constraints in schema.yml
- **Data freshness checks**: Source freshness thresholds defined and monitored via `dbt source freshness`
- **Referential integrity**: Foreign key relationships validated using `relationships` tests
- **Business rule validation**: Custom singular tests for domain-specific rules (e.g., revenue >= 0, dates within valid ranges)
- **Zero tolerance for critical failures**: Models with failing tests cannot be deployed to production
- **Documented exceptions**: Any quality check overrides must be explicitly documented with business justification

**Rationale**: Data quality is non-negotiable in analytics. Gates prevent bad data from propagating through the pipeline and damaging trust in analytics products.

### III. Comprehensive dbt Feature Coverage

This demo project MUST showcase dbt's full capability spectrum:

**Core Features (REQUIRED)**:
- Sources, staging models, intermediate models, marts
- Generic tests (unique, not_null, relationships, accepted_values)
- Custom singular tests
- Incremental models with appropriate materialization strategies
- Snapshots for slowly changing dimensions (SCD Type 2)
- Macros for reusable SQL logic
- Jinja templating and control structures
- Analysis files for ad-hoc queries
- Seeds for small reference data
- Documentation (schema.yml descriptions, markdown docs)
- Exposures tracking downstream usage

**Advanced Features (ENCOURAGED)**:
- Custom generic tests
- Packages (dbt_utils, dbt_expectations)
- Pre/post-hooks
- Custom materializations
- Multiple target environments (dev/prod)
- dbt Cloud features if applicable (CI jobs, slim CI)

**Rationale**: A demo must demonstrate real-world best practices across dbt's feature set to serve as a learning resource and reference implementation.

### IV. Documentation-First Models

Every dbt model MUST be documented BEFORE or DURING initial development:

- **Model purpose**: Clear description in schema.yml explaining what the model does and why it exists
- **Column descriptions**: Every column documented with business meaning, not just technical definition
- **Assumptions documented**: Data assumptions, business rules, and logic decisions captured
- **Lineage implicit**: dbt's `ref()` and `source()` functions create automatic lineage
- **Generated docs site**: `dbt docs generate && dbt docs serve` must produce complete, navigable documentation

**Rationale**: Undocumented data models become technical debt. Documentation during development ensures knowledge transfer, enables self-service analytics, and makes the demo valuable as a teaching tool.

### V. Incremental Development & Testing

Development workflow enforces quality at every step:

- **Fail fast**: Run `dbt parse` and `dbt compile` early to catch syntax errors
- **Iterate on subsets**: Use `dbt run --select` to develop and test individual models
- **Test continuously**: Run `dbt test --select` on models as they're developed
- **Preview results**: Use `dbt show` or direct database queries to inspect model outputs
- **Full pipeline validation**: Before committing, run `dbt build` (run + test) on entire project
- **CI validation**: Automated CI runs `dbt build` on pull requests to prevent regression

**Rationale**: Incremental testing catches issues early when they're cheap to fix. Waiting until full pipeline runs to test causes slow feedback cycles and compounds errors.

## Data Quality Standards

### Required Test Coverage

**Every model must have**:
- At least one test (minimum: primary key uniqueness + not_null)
- Column-level tests for business-critical fields
- Relationship tests for foreign keys

**Critical models (marts, exposures) must have**:
- Comprehensive test coverage (>80% of columns tested)
- Custom data quality tests for business rules
- Volume and distribution checks (using dbt_utils or dbt_expectations)

**Test categorization**:
- **Primary**: Tests that must always pass (unique, not_null on keys)
- **Warning**: Tests that should pass but may have exceptions (data freshness, value ranges)
- **Informational**: Tests tracking data quality trends over time

### Materialization Strategy

**Materialization must be intentional and documented**:
- **Views**: Default for staging models (low transformation, frequently changing)
- **Tables**: For computationally expensive transformations or frequently queried marts
- **Incremental**: For large fact tables with append-only or upsert patterns (REQUIRED for >1M rows)
- **Ephemeral**: For CTEs that should be inlined (use sparingly)

**Performance considerations**:
- Incremental models must have appropriate `unique_key` and `incremental_strategy`
- Large full-refresh models must justify why incremental isn't suitable
- Query performance measured and documented for core marts

## dbt Project Structure

**Standard layout enforced**:

```
models/
├── staging/          # Source-conformed models (1:1 with sources)
├── intermediate/     # Business logic transformations
├── marts/            # Final analytics-ready models
│   ├── core/        # Cross-functional core entities
│   ├── marketing/   # Domain-specific marts
│   └── finance/
└── analysis/         # Ad-hoc analytical queries

tests/                # Singular custom tests
macros/               # Reusable SQL logic
seeds/                # Reference data CSV files
snapshots/            # SCD Type 2 tracking
```

**Naming conventions**:
- Staging: `stg_<source>__<entity>.sql` (e.g., `stg_stripe__payments.sql`)
- Intermediate: `int_<entity>__<verb>.sql` (e.g., `int_orders__pivoted.sql`)
- Marts: `<entity>_<grain>.sql` or `<domain>_<entity>.sql` (e.g., `customers_daily.sql`, `marketing_campaigns.sql`)

## Development Workflow

### Feature Development Process

1. **Specification**: Define requirements, user stories, expected outputs
2. **Test definition**: Write test cases in schema.yml covering success criteria
3. **Model development**: Implement SQL with `ref()` and `source()` functions
4. **Iterative validation**: `dbt run --select <model>+` → `dbt test --select <model>`
5. **Documentation**: Complete model and column descriptions
6. **Integration testing**: `dbt build --select +<model>+` (upstream + downstream)
7. **Full pipeline validation**: `dbt build` on entire project
8. **Pull request**: Automated CI runs tests, manual code review required
9. **Production deployment**: Merge triggers production dbt Cloud job or deployment script

### Code Review Requirements

**Every PR must verify**:
- All models have tests (check schema.yml)
- All tests pass (`dbt test` output in CI)
- Documentation complete (no missing descriptions)
- Follows naming conventions and project structure
- No hard-coded values (use variables or seeds)
- Appropriate materialization strategy chosen and documented
- SQL follows style guide (consistent formatting, CTEs over subqueries)

### Pre-commit Validation

**Before committing, developer must run**:
```bash
dbt deps                    # Ensure packages installed
dbt parse                   # Check syntax
dbt compile --select state:modified+  # Compile changed models
dbt run --select state:modified+      # Run changed models
dbt test --select state:modified+     # Test changed models
dbt docs generate           # Update documentation
```

## Governance

### Constitution Authority

This constitution supersedes all other development practices. When conflicts arise, constitution principles take precedence.

### Amendment Process

**Amendments require**:
1. Written proposal with rationale
2. Review by project maintainers
3. Documentation of impact on existing models
4. Migration plan for non-compliant code
5. Version increment and LAST_AMENDED_DATE update

### Version Increment Rules

- **MAJOR** (X.0.0): Removes or redefines core principles (e.g., removing test requirement)
- **MINOR** (x.Y.0): Adds new principles, sections, or materially expands guidance (e.g., adding new test types)
- **PATCH** (x.y.Z): Clarifications, wording improvements, typo fixes, non-semantic refinements

### Compliance

- All PRs must verify compliance with this constitution
- Non-compliant code requires explicit justification and tracking
- Technical debt from exceptions tracked in project backlog
- Regular audits ensure adherence (quarterly reviews recommended)

### Runtime Guidance

For operational guidance during development (e.g., setting up dbt Cloud, configuring profiles), refer to project README and dbt documentation. This constitution defines *what* and *why*, not *how* (which evolves with dbt versions).

**Version**: 1.0.0 | **Ratified**: 2025-10-08 | **Last Amended**: 2025-10-08
