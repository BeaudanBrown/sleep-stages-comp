# AGENTS.md - Tests

## Scope

This folder contains the runnable test harness for the analysis pipeline.

## Rules

- Use synthetic or simulated data only.
- Keep tests deterministic with explicit seeds.
- Prefer unit and narrow integration tests to broad end-to-end runs.
- Add regression tests for every substantive scientific bug fixed in the code.
- Do not assert full model printouts or unstable coefficients from fitted models.

## Running tests

- Run the full suite with `./nixr.sh -f tests/testthat.R`.
- Run a single file with `./nixr.sh "testthat::test_file('tests/testthat/<file>.R')"`.
- If a test requires package changes, update `flake.nix` first.

## Current status

- Phases 1 through 4 are implemented and currently pass.
- The implemented files are `test-composition.R`, `test-substitutions.R`, `test-survival-encoding.R`, `test-risk-prediction.R`, and `test-lmtp-contracts.R`.
- The next expected additions are `test-bootstrap.R`, `test-simulation.R`, and `test-targets-contracts.R`.

## Expanding the suite

- Put shared fixtures in `tests/testthat/helper-fixtures.R`.
- Put shared sourcing/setup in `tests/testthat/helper-load.R`.
- Keep one main behavior family per `test-*.R` file.
- When adding a new phase, update the docs in `docs/testing/` in the same change.
- For LMTP survival tests, follow the installed package convention: natural `C_t` columns are `1` while observed and `0` after censoring; shifted datasets with `cens` supplied are all `1`.
- Check [actual-imp-variable-names.md](/home/beau/monash/stages_compositional/docs/actual-imp-variable-names.md) before adding or renaming fixture columns. Tests should follow the real prepared-data schema, not simulation-only names.
