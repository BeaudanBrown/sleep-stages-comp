# Testing Framework Plan

## Purpose

This document defines the verification framework for the sleep-stage compositional analysis pipeline. The test suite must detect scientific regressions, not just syntax regressions, while staying privacy-safe and runnable on synthetic data only.

## Core principles

- Test scientific contracts before full pipeline behavior.
- Prefer deterministic unit tests over expensive end-to-end runs.
- Use synthetic or simulated data only.
- Assert invariants, null behavior, directional recovery, and output contracts.
- Add regression tests for every substantive bug that gets fixed.

## Test layers

### Layer 1: Deterministic unit tests

Target pure helpers in `R/utils.R`, `R/constants.R`, and data preparation helpers that can be exercised with tiny synthetic fixtures.

Primary targets:

- `make_ilrs()`
- `make_comp_limits()`
- `apply_substitution()`
- `make_lmtp_shift()`
- `make_cuts()`
- `expand_surv_dt()`
- `make_surv_wide()`
- `get_lmtp_surv_cols()`
- `predict_risks()`
- `bootstrap_resample()`

### Layer 2: Narrow integration tests

Exercise small analysis slices on simulated data or compact synthetic inputs.

Primary targets:

- pooled-logistic model fitting and prediction
- LMTP reference and substitution helpers
- bootstrap summarizers
- plotting/output schema contracts

### Layer 3: Simulation-backed oracle tests

Verify the pipeline recovers known null or directional effects under the simulated DGP.

Primary targets:

- null-effect scenario
- protective-N3 scenario
- later: age interaction scenario

### Layer 4: `{targets}` contract tests

Verify target graph shape and critical command contracts without depending on the confidential pipeline.

Primary targets:

- critical target names exist
- mapped targets branch over the intended objects
- substitution targets use branch-specific substitution values
- simulated targets run as a smoke test

## Planned phases

Status:

- Phases 1 through 4 are implemented and passing in `testthat`.
- Phases 5 through 7 are still pending.

### Phase 1: Composition and substitution contracts

Goal: verify that raw composition helpers preserve algebraic invariants and intervention semantics.

Required tests:

- `make_ilrs()` returns the expected number of ILR columns and names.
- `make_ilrs()` is deterministic.
- `apply_substitution()` preserves the component total.
- `apply_substitution()` changes only the `from` and `to` parts.
- `apply_substitution()` flags feasible and infeasible substitutions correctly.
- `apply_substitution()` handles negative durations as the reverse shift.
- `make_lmtp_shift()` reproduces the treatment columns from `apply_substitution()`.
- `make_lmtp_shift()` only changes the treatment columns passed in `trt`.

Current status: implemented and passing.

### Phase 2: Survival encoding contracts

Goal: verify long-to-wide survival construction and censoring/event semantics.

Required tests:

- cut vectors are increasing and finite
- long survival expansion yields valid timegroups
- dementia and death remain mutually exclusive
- LMTP wide outcomes and competing events carry forward correctly
- natural-data censoring columns are `1` while observed and `0` after censoring, matching installed `lmtp` behavior
- shifted-data LMTP paths with explicit `shifted=` keep censoring columns at `1`, matching installed `lmtp` checks

Current status: implemented and passing.

### Phase 3: Risk prediction and model contracts

Goal: verify stable prediction behavior without pinning noisy coefficients.

Required tests:

- formulas contain required structural terms
- fitted models predict with `type = "response"`
- predicted risks remain in `[0, 1]`
- predicted mean risk is non-decreasing across time
- fixed-hazard toy cases behave as expected

Current status: implemented and passing.

### Phase 4: LMTP estimand contracts

Goal: verify that the LMTP path estimates contrast-based risk ratios and preserves intervention semantics.

Required tests:

- no-intervention reference fit exists
- 0-minute shift gives risk ratio approximately 1
- reported LMTP effect comes from `lmtp_contrast()`
- shifted datasets modify treatment columns only
- mapped substitution targets use branch-specific substitution values

Current status: implemented and passing for helper-level LMTP contracts. `{targets}` branch wiring is still reserved for phase 7 contract tests.

### Phase 5: Bootstrap contracts

Goal: verify deterministic resampling logic and summary schemas.

Required tests:

- bootstrap resampling is reproducible by seed
- bootstrap IDs are reassigned correctly
- summary outputs contain expected columns and finite ratios where defined

### Phase 6: Simulation oracle tests

Goal: verify direction and null behavior against the DGP.

Required tests:

- null scenario gives approximately null contrasts
- protective-N3 scenario gives the expected directional contrast
- future interaction scenario changes direction by age strata

### Phase 7: Pipeline contract tests

Goal: verify target graph shape and a minimal end-to-end simulated smoke test.

Required tests:

- critical targets exist in the manifest
- mapped target patterns reference the intended upstream targets
- simulated substitution path runs successfully

## Test folder structure

```text
tests/
├── AGENTS.md
├── testthat.R
└── testthat/
    ├── AGENTS.md
    ├── helper-load.R
    ├── helper-fixtures.R
    ├── test-composition.R
    ├── test-substitutions.R
    ├── test-survival-encoding.R
    ├── test-risk-prediction.R
    ├── test-lmtp-contracts.R
    ├── test-bootstrap.R
    ├── test-simulation.R
    └── test-targets-contracts.R
```

## Running tests

Use the Nix-wrapped environment only.

```bash
./nixr.sh -f tests/testthat.R
```

For targeted runs during development:

```bash
./nixr.sh "testthat::test_file('tests/testthat/test-substitutions.R')"
```

## Privacy rules

- Never load real-data fixtures into tests.
- Never print row-level confidential data from pipeline targets.
- Use synthetic tables or simulated data only.
- Keep regression tests narrow and privacy-safe.

## LMTP censoring convention

The installed `lmtp` code expects natural censoring indicators to use `1` for observed and `0` after censoring. Internally, `NA` censoring values are converted to `0`. For `shifted=` workflows, `lmtp` requires censoring columns in the shifted data to be `1`.
