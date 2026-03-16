# Codebase Map

This file is the clean handoff map for new agents working in this repository.

## Canonical entrypoints

- Targets pipeline:
  - `_targets.R`
  - `data_targets.R`
  - `analysis_targets.R`
  - `simulation_targets.R`
- Analysis code:
  - focused modules under `R/`
- Tests:
  - `tests/testthat.R`
  - `tests/testthat/`
- Local one-off debugging:
  - `scripts/`

The old root-level `test_*.R`, `debug_*.R`, and traceback scripts were intentionally removed. New ad hoc workflows should live in `scripts/`, not the repository root.

## Module ownership

- `R/constants.R`
  - shared constants such as `comp_vars`, `ilr_names`, `sbp`, `stage_labels`
- `R/composition_utils.R`
  - ILR creation and component bounds
  - `make_ilrs()`, `make_comp_limits()`
- `R/substitution_utils.R`
  - substitution-grid construction and bounded composition shifts
  - `make_substitution_grid()`, `make_lmtp_shift()`, `apply_substitution()`, `compute_substituted_risk()`
- `R/survival_utils.R`
  - pooled-logistic survival data shaping, formulas, fitting, prediction
  - `make_cuts()`, `expand_surv_dt()`, `make_surv_wide()`, `get_primary_formula()`, `fit_models()`, `predict_risks()`
- `R/lmtp_utils.R`
  - LMTP/TMLE reference fit, shifted-data construction, contrasts
  - `run_lmtp_tmle_reference()`, `run_lmtp_tmle_substitution()`
- `R/lmtp_experimental.R`
  - experimental LMTP scratch path that is not part of the main pipeline
- `R/bootstrap_utils.R`
  - bootstrap resampling helpers
- `R/plot_utils.R`
  - bootstrap/LMTP plot construction and PNG writing
- `R/imputation.R`
  - custom MICE imputation method and `impute_data()`
- `R/prepare_dataset.R`
  - outcome derivation and dataset preparation from merged raw inputs
- `R/make_dataset_from_raw_files.R`
  - source-specific raw-data loading and the top-level merge into `dt_raw`
- `R/simulate_data.R`
  - privacy-safe simulated data generation
- `R/validate_simulation.R`
  - simulation validation scaffolding

## Pipeline layout

- `data_targets.R`
  - file targets, raw-data assembly, dataset preparation, imputation
- `analysis_targets.R`
  - grouped into:
    - analysis config targets
    - survival data targets
    - LMTP targets
    - bootstrap targets
- `simulation_targets.R`
  - simulation specs and the currently active simulation analysis targets

## Testing rules

- The authoritative test suite is `tests/testthat/`.
- Tests must be privacy-safe and use synthetic data only.
- If you change statistical logic, prefer adding a narrow contract or invariant test rather than a large snapshot.
- Use the `r-analysis-test-suites` skill when modifying tests.

## Known structural follow-ups

- `R/make_dataset_from_raw_files.R` is still too large and should be split by data source.
- `IMPLEMENTATION_PLAN.md` is now a compact technical roadmap; live task tracking moved to coordinator Beads epic `coordinator-xyb`.
- `R-bak/` is not canonical and should not be used for new work.
