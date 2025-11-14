# claude-sql-dbt Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-11-14

## Active Technologies
- **dbt-core** >= 1.10.13 (data transformation framework)
- **dbt-postgres** >= 1.9.1 (PostgreSQL adapter)
- **Python 3.11+** (runtime environment)
- **PostgreSQL 16** (analytical database)
- **Docker & Docker Compose** (local development)

## Project Structure
```
claude-sql-dbt/
├── dbt_project/              # Main dbt project directory
│   ├── models/               # SQL transformation models
│   │   ├── staging/          # Source-conformed views
│   │   ├── intermediate/     # Business logic (ephemeral)
│   │   └── marts/            # Analytics-ready tables
│   │       ├── core/         # Dimensional models & facts
│   │       └── analytics/    # Analytics marts
│   ├── tests/                # Singular custom data quality tests
│   ├── macros/               # Reusable SQL functions
│   ├── seeds/                # Reference data (CSV files)
│   ├── snapshots/            # SCD Type 2 implementations
│   ├── analyses/             # Ad-hoc analytical queries
│   └── dbt_project.yml       # Project configuration
├── docker/                   # Local development environment
│   ├── docker-compose.yml    # PostgreSQL + MinIO services
│   └── postgres/             # DB initialization & mock data
├── specs/                    # Feature specifications & planning
├── profiles.yml              # dbt connection profiles
├── requirements.txt          # Python dependencies
├── Makefile                  # Development automation
└── README.md                 # Project documentation
```

## Quick Start Commands

### Setup
```bash
make setup          # Automated setup (recommended)
make shutdown       # Stop and clean up Docker services
```

### Development
```bash
make build          # Build all models + run all tests
make test           # Run all tests only
make docs           # Generate and serve documentation
```

### Manual dbt Commands
```bash
./dbt_env/bin/dbt run --project-dir dbt_project
./dbt_env/bin/dbt test --project-dir dbt_project
./dbt_env/bin/dbt build --project-dir dbt_project
./dbt_env/bin/dbt docs generate --project-dir dbt_project
```

## Code Style & Best Practices

### SQL (dbt models)
- Use consistent naming: `stg_`, `int_`, `dim_`, `fact_`, mart names
- Staging: Views (lightweight, source-conformed)
- Intermediate: Ephemeral (business logic, not persisted)
- Core & Analytics: Tables (frequently queried)
- Always add `dbt_updated_at` metadata timestamp
- Document all models in schema.yml files

### Testing
- **Test-first development**: Define tests before implementation
- Generic tests: unique, not_null, relationships, accepted_values
- Singular tests: Custom SQL for complex business rules
- All models must have at least one test
- Target: 300+ tests passing (PASS=300 WARN=0 ERROR=0)

### Documentation
- Every model must have description and grain definition
- Every column must be documented with business meaning
- Use inline comments for complex SQL logic
- Update schema.yml when adding/modifying models

## Development Workflow

1. **Create/modify models** in appropriate layer (staging/intermediate/marts)
2. **Define tests** in schema.yml (test-first approach)
3. **Run specific model**: `./dbt_env/bin/dbt run --select model_name --project-dir dbt_project`
4. **Test changes**: `./dbt_env/bin/dbt test --select model_name --project-dir dbt_project`
5. **Full validation**: `make build` (runs all models + all tests)
6. **Update documentation**: `make docs`
7. **Commit changes** with descriptive message

## Quality Gates

- ✅ All tests must pass before committing
- ✅ All models must be documented
- ✅ SQL must be formatted consistently
- ✅ No hard-coded credentials (use env vars for prod)
- ✅ Follow layered architecture (staging → intermediate → marts)

## Recent Changes
- 2025-11-14: Added Makefile automation with improved error handling
- 2025-11-14: Added security warnings for credential usage
- 2025-11-14: Updated project structure documentation
- 001-build-a-full: Initial project implementation with 12+ dbt features

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->