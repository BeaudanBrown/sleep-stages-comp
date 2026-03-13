# Testing Implementation Roadmap

## Current status

Completed:

1. Added the `testthat` toolchain to `flake.nix`.
2. Created the `tests/testthat/` scaffold with shared helpers.
3. Implemented phases 1 through 4.
4. Added a durable prepared-data schema reference in `docs/actual-imp-variable-names.md`.
5. Fixed several helper-level issues uncovered by the tests:
   `make_lmtp_shift()` reverse-shift feasibility,
   `make_cuts()` no-event handling,
   `make_surv_wide()` LMTP censoring convention,
   simulation schema drift from `death_surv_date` to `death_date`,
   `nixr.sh -f` script execution.

## Near-term work

### Phase 5

- test bootstrap resampling and summary helpers

### Phase 6

- activate simulation-oracle tests against the predefined scenarios
- use wide tolerances and directional assertions rather than exact values

### Phase 7

- add `{targets}` manifest and smoke tests for the simulated pipeline only

## Expected failure classes

- component definition drift between specs and code
- substitution helpers that mishandle negative durations or bounds
- long-to-wide survival encoding mismatches for LMTP
- censoring columns encoded with `NA` after censoring instead of the installed `lmtp` convention of `0` in natural data
- intervention means mislabeled as comparative effects
- target branching that accidentally reuses a fixed substitution row

## Maintenance rule

Every time a scientific bug is fixed, add one focused regression test in the smallest relevant test file.
