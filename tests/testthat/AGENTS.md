# AGENTS.md - testthat Files

## Purpose

This folder contains the individual `testthat` files and helper fixtures for the analysis pipeline.

## File conventions

- `helper-load.R`: load packages and source project files needed by tests.
- `helper-fixtures.R`: build synthetic datasets and reusable assertions.
- `test-composition.R`: compositional transformations and invariants.
- `test-substitutions.R`: raw substitution logic and LMTP shift helper behavior.
- `test-survival-encoding.R`: long-to-wide survival encoding and LMTP censoring conventions.
- `test-risk-prediction.R`: formula, model, and cumulative-risk contracts.
- `test-lmtp-contracts.R`: LMTP reference, shifted-data, and contrast semantics.
- Future files should follow the same single-behavior-family convention.

## Writing guidance

- Prefer `expect_equal(..., tolerance = ...)` for floating point checks.
- Use explicit synthetic fixtures with obvious expected values.
- Keep assertions at the level of scientific meaning: totals, bounds, identity, direction, schema.
- If a helper has a known historical bug, add a narrow regression test that names the behavior.
- Avoid hidden dependencies on the current working directory; use project-root-aware helpers.
- For LMTP censoring assertions, use the package's observed-data convention: `1` while observed, `0` after censoring, not `NA`.
- Before changing fixture schemas, verify column names against [actual-imp-variable-names.md](/home/beau/monash/stages_compositional/docs/actual-imp-variable-names.md).
