# Model Contracts: E-Commerce Analytics dbt Demo

**Purpose**: Define model interfaces, contracts, and dependencies for all dbt models

**Date**: 2025-10-08
**Feature**: [spec.md](../spec.md)
**Data Model**: [data-model.md](../data-model.md)

## Overview

This directory contains contract specifications for all dbt models, defining:
- Model grain (what does one row represent?)
- Column specifications (name, type, nullable, description)
- Relationships and foreign keys
- Business rules and constraints
- Test requirements

Contracts serve as the interface specification between models, enabling:
1. **Contract-driven development**: Tests written from contracts before model SQL
2. **Impact analysis**: Understanding downstream effects of schema changes
3. **Documentation**: Single source of truth for model interfaces
4. **Validation**: Automated checks that models meet contract specifications

---

## Contract Files

| File | Models Covered | Purpose |
|------|----------------|---------|
| [staging_models.md](staging_models.md) | stg_ecommerce__* | Staging layer contracts |
| [intermediate_models.md](intermediate_models.md) | int_*__* | Intermediate layer contracts |
| [dimensional_models.md](dimensional_models.md) | dim_* | Dimension table contracts |
| [fact_models.md](fact_models.md) | fact_* | Fact table contracts |
| [mart_models.md](mart_models.md) | *_analytics, *_performance, *_attribution | Analytics mart contracts |
| [snapshot_models.md](snapshot_models.md) | *_snapshot | Snapshot contracts |

---

## Contract Format

Each model contract follows this structure:

```markdown
## Model: <model_name>

**Purpose**: [What does this model do?]
**Grain**: [What does one row represent?]
**Materialization**: [view / table / incremental / ephemeral]
**User Story**: [P1, P2, P3, P4 - which user story does this serve?]

### Columns

| Column Name | Data Type | Nullable | Description | Business Rules |
|-------------|-----------|----------|-------------|----------------|
| ... | ... | ... | ... | ... |

### Relationships

- **Upstream Dependencies** (what this model depends on):
  - `ref('model_name')` or `source('schema', 'table')`

- **Downstream Consumers** (what depends on this model):
  - `ref('consumer_model')`

### Tests Required

**Generic Tests**:
- `column_name`: unique, not_null, relationships, accepted_values

**Singular Tests**:
- Custom SQL test descriptions

### Sample Query

```sql
-- Example query showing how to use this model
SELECT ...
```
```

---

## Usage Guidelines

### For Developers

1. **Before implementing a model**: Read its contract to understand requirements
2. **Write tests first**: Use contract to define tests in schema.yml
3. **Implement model SQL**: Build model to fulfill contract specifications
4. **Validate contract**: Run tests to verify model meets contract

### For Reviewers

1. **Check contract adherence**: Model should match contract specifications exactly
2. **Verify tests**: All required tests from contract should be present
3. **Validate documentation**: Model description should match contract purpose

### For Analysts

1. **Understand model purpose**: Read contract to know what model provides
2. **Review grain**: Ensure you understand what one row represents
3. **Check relationships**: Understand upstream dependencies and data lineage
4. **Use sample queries**: Leverage examples for common analytical patterns

---

## Contract Versioning

**Version**: 1.0.0 (Initial contracts for MVP implementation)

**Change Policy**:
- **Breaking changes** (remove column, change type, change grain): Requires major version bump
- **Non-breaking additions** (add column, add test): Minor version bump
- **Documentation updates**: Patch version bump

**Contract enforcement**:
- Models must implement ALL required columns from contract
- Models may add additional columns not in contract (document in PR)
- Removing contracted columns requires contract update + impact analysis

---

## Next Steps

1. Review individual contract files for detailed model specifications
2. Use contracts to write schema.yml test definitions
3. Implement models following contract specifications
4. Validate models pass all contracted tests
