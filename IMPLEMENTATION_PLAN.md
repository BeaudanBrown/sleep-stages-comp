# Implementation Plan - Compositional Sleep Analysis

## Critical Issue: 4-part vs 5-part Composition
- [x] **CRITICAL**: Refactor from 5-part (with wake) to 4-part composition (n1, n2, n3, rem only)
- [x] Add wake time calculation: `wake = 24*60 - (n1 + n2 + n3 + rem)`
- [x] Store wake separately, not in composition
- [ ] Include TST as covariate in all models

## Priority 1: Core Infrastructure & Parallelization

- [x] **Add crew controller setup** in `_targets.R` with `parallel::detectCores() - 1` workers
- [x] Configure targets with proper seed management (`tar_option_set(seed = 12345)`)
- [x] Implement error handling strategy (`error = "continue"` for non-critical targets)
- [x] Set up deployment strategies (`deployment = "worker"` vs `deployment = "main"`)
- [x] Enable garbage collection (`garbage_collection = TRUE`)

## Priority 2: Data Validation & QC Pipeline

- [x] Create `R/validation.R` with comprehensive checks:
  - [x] Sum constraint: TST components sum to TST ± 1 minute
  - [x] Non-negativity: All sleep stages ≥ 0
  - [x] Biological plausibility: Min sleep 180 min, max wake 1200 min
  - [x] REM percentage: 10-25% of TST
  - [ ] Age-related N3 decline validation
- [x] Add missing indicators (`*_mis` variables) for all key variables
- [x] Implement `valid_comp` density checking with Mahalanobis distance
- [ ] Create QC report generation target with exclusion tracking

## Priority 3: Imputation Layer

- [ ] Implement compositional-aware imputation in `R/imputation.R`:
  - [ ] Use truncated normal for compositional data
  - [ ] Set m = 250 iterations (not 10)
  - [ ] Add convergence monitoring (trace plots, R-hat < 1.05)
  - [ ] Track max change in chain means < 0.05
- [ ] Create dynamic branching target: `pattern = map(data_imputed)`
- [ ] Add sensitivity analysis targets for m = 10, 20, 50, 250

## Priority 4: Compositional Transformation

- [ ] Update ILR transformation for 4-part composition in `R/compositional.R`:
  - [ ] New sequential binary partition for n1, n2, n3, rem
  - [ ] Verify orthogonality and reversibility (error < 1e-10)
  - [ ] Add numerical stability checks
- [ ] Remove wake from composition calculations
- [ ] Create density model fitting for plausibility checks

## Priority 5: Substitution Analysis

- [ ] Implement G-computation framework in `R/substitution.R`:
  - [ ] Counterfactual estimation
  - [ ] Risk differences and ratios calculation
  - [ ] Bootstrap uncertainty (1000 iterations minimum)
- [ ] Update substitution increments to 15, 30, 45, 60 minutes (not 10, 30, 60)
- [ ] Create all 48 scenarios (12 pairs × 4 increments)
- [ ] Add optimal composition grid search (exhaustive over simplex)

## Priority 6: Statistical Modeling

- [ ] Update `R/models.R` for proper outcome handling:
  - [ ] Dementia/MCI combined endpoint with type tracking
  - [ ] Brain MRI volumes with TIV adjustment
  - [ ] Regional volumes (hippocampal, frontal, temporal)
  - [ ] Log-transform WMH due to skewness
- [ ] Add stratification functions for age/sex/APOE4
- [ ] Implement Rubin's rules for combining imputed results
- [ ] Add time-varying effects analysis

## Priority 7: Visualization Suite

- [ ] Create `R/visualization.R` with all required plots:
  - [ ] Risk ratio plots (x-axis: minutes substituted)
  - [ ] Cumulative risk curves
  - [ ] Ternary diagrams for 3-component subcompositions
  - [ ] Radar plots for optimal vs average compositions
  - [ ] Heatmaps of substitution effects
  - [ ] Forest plots for stratified analyses
- [ ] Create `R/themes.R` for consistent styling
- [ ] Add publication export functions (PDF/SVG at 300 DPI)
- [ ] Implement color-blind safe palettes

## Priority 8: Model Diagnostics

- [ ] Create `R/diagnostics.R` with:
  - [ ] Residual plots for continuous outcomes
  - [ ] Calibration plots for survival models
  - [ ] Cook's distance and influential observations
  - [ ] VIF for multicollinearity
  - [ ] Cross-validation stability checks
  - [ ] Bootstrap coefficient of variation

## Priority 9: Output Generation

- [ ] Create table formatting functions in `R/tables.R`
- [ ] Implement Quarto report templates with dynamic results
- [ ] Add supplementary material generation
- [ ] Create interactive Shiny dashboard for exploration

## Priority 10: Reproducibility Infrastructure

- [ ] Add renv for package management
- [ ] Implement comprehensive logging system
- [ ] Document all exclusions at each stage
- [ ] Create platform testing suite
- [ ] Add numerical stability tests

## Technical Debt Resolution

- [ ] Fix numerical precision in extreme compositions
- [ ] Ensure all required packages in flake.nix
- [ ] Verify targets seed propagation
- [ ] Add unit tests for critical functions

## Completed Items
- [x] Basic data loading infrastructure
- [x] File targets for raw data
- [x] Data merging functionality

## Notes
- Old code in `old/R/` provides reference implementations but uses 5-part composition
- All new functions must handle 4-part composition with TST as covariate
- Maintain backward compatibility with existing data loading
- Use dynamic targets exclusively for scalability
- Document all statistical assumptions in code