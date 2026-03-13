# Implementation Plan: Sleep Stage Composition Analysis

## Overview

This plan addresses the gaps between the current codebase and the specifications, organized into 8 phases with clear milestones. Each phase builds on the previous one.

**Current State Summary:**
- ✅ Simulated data infrastructure implemented (Phase 0 Tier 1 core)
- ✅ Bootstrap / g-computation substitution pipeline exists and has produced plots
- ✅ Experimental LMTP / TMLE survival pipeline exists
- ✅ LMTP path now includes an explicit no-intervention reference fit for contrast estimation
- ✅ LMTP dynamic branching now uses the mapped substitution branch value
- ✅ LMTP 0-minute substitution sanity check gives risk ratio approximately 1
- ✅ LMTP survival-wide `Y_t` / `D_t` coding now follows cumulative event conventions more closely
- ✅ LMTP baseline adjustment now excludes SHHS-1 `slp_time` and includes SHHS-2 `slp_time_s2`
- ✅ Intended SHHS-2 exposure composition is the 5-part set `(n1_s2, n2_s2, n3_s2, waso_s2, rem_s2)`
- ✅ LMTP shifted-data censoring handling matches the package expectation: censoring columns in `shifted` should be `1`
- ✅ Default LMTP learners were simplified to `SL.mean + SL.glm` for outcomes and `SL.glm` for treatment after localizing sparse-class `SL.glmnet` failures
- ✅ LMTP substitution code and branched targets now rethrow errors with explicit substitution context
- ✅ Phase 0: Model fitting on simulated data working (make_cuts/survSplit guardrails)
- Active issue: the direct LMTP substitution path is now more stable, but the full `targets`-branched `lmtp_tmle_substitutions` target still intermittently errors with a generic branch-level message
- Active issue: the exact remaining `targets` branching failure mechanism is not yet isolated even after simplifying learners
- Active issue: ideal-composition and simulation/test scaffolding still carry some older 4-part assumptions despite the intended 5-part exposure
- Missing: full confounders, ILR×Time interactions, ILR×Age interactions, sleep-duration covariate cleanup
- Missing: proper MI pooling, MRI outcomes, bootstrap inference, ideal composition search

---

## Phase 0: Simulated Data Infrastructure

**Goal:** Create simulated data capability for privacy-safe development and pipeline validation. This allows agents to work with data freely and enables testing that the pipeline recovers known causal effects.

**Specification:** See `specs/simulation.md` for full details.

### Tier 1: Core Implementation

- [x] **0.1** Create `R/simulate_data.R` - Core simulation functions
  - Function: `make_sim_spec()` - Create simulation specification with defaults
    - Parameters: n, seed, true causal effects (effect_R1_dem, effect_R2_dem, effect_R3_dem, etc.)
    - Default effects: null (all zeros) for baseline scenario
  - Function: `simulate_dataset(spec)` - Main entry point
    - Calls sub-functions for each data component
    - Returns data.table matching structure of real `dt`

- [x] **0.2** Implement `simulate_baseline()` - Demographics and confounders
  - Generate: age_s1 (truncated normal, μ=65, σ=10, range [40,90])
  - Generate: gender (Bernoulli, p=0.5)
  - Generate: bmi_s1 (normal, μ=28, σ=5, correlated with age)
  - Generate: IDTYPE (Bernoulli, p=0.9 for Offspring)
  - Generate: educat (ordinal, age-dependent)
  - Include correlations between variables

- [x] **0.3** Implement `simulate_sleep_stages()` - SHHS-1 and SHHS-2 compositions
  - Use Dirichlet distribution for compositional data
  - SHHS-1: Base composition with age effect (older → less N3, more N1)
  - SHHS-2: Autocorrelated with S1 (ρ≈0.6), plus additional aging
  - Generate total sleep time (normal, μ=400, σ=60 minutes)
  - Compute stage minutes from proportions × TST

- [x] **0.4** Implement `simulate_outcomes()` - Dementia and death from known DGP
  - Dementia hazard model (discrete-time):
    ```
    logit(h_dem) = baseline + β_R1*R1 + β_R2*R2 + β_R3*R3 + β_age*age + ...
    ```
  - Death hazard model (competing risk):
    ```
    logit(h_death) = baseline + γ_age*age + γ_bmi*bmi + ...
    ```
  - Generate events sequentially respecting competing risks
  - Track survival times and event indicators

- [x] **0.5** Create `prepare_simulated_dataset()` - Match real data preparation
  - Apply same transformations as `prepare_dataset()`
  - Create ILR coordinates, derived variables
  - Ensure column names and types match real data

- [x] **0.6** Create `simulation_targets.R` - Pipeline integration
  - Define `sim_specs` target with predefined scenarios:
    - `null_effect`: All sleep effects = 0
    - `protective_n3`: effect_R2_dem = -0.3 (N3 protective)
  - Map simulated data generation over specs
  - Run analysis pipeline on simulated data (branched targets)

- [x] **0.7** Create `R/validate_simulation.R` - Validation functions (skeleton)
  - Function: `validate_simulation(estimated, true_spec)` - Compare estimated vs true
  - Check: Effect direction correct
  - Check: True effect within confidence interval
  - Return: Validation summary table
  - **NOTE:** Skeleton implemented, needs full logic for comparing estimated to true effects

- [ ] **0.8** Add validation targets to `simulation_targets.R`
  - Target: `validation_results` - Run validation for each scenario
  - Target: `validation_summary` - Aggregate pass/fail status
  - **BLOCKED:** Waiting for isotemporal substitution targets to work

**Milestone 0.1:** Basic simulation generates data, pipeline runs on it, validation checks pass for null and protective_n3 scenarios.

**Notes for Next Agent:**
- Simulation targets `sim_specs` through `sim_comp_limits` all work correctly
- `sim_fitted_models` now works; if it fails again, re-check `make_cuts()`/`survSplit()` cutpoints
- To test: `./nixr.sh "targets::tar_make(names = starts_with('sim_'))"`
- Fixed during testing: `targets::map()` → `map()`, `rDirichlet()` → `rDirichlet.acomp()`, named list handling, survival time minimum safeguard

### Tier 2: Essential Extensions

- [ ] **0.9** Add effect modification by age
  - Parameter: `effect_interaction_age_R2` in spec
  - Implement in DGP: age × R2 interaction term
  - Add scenario: `age_interaction`

- [ ] **0.10** Add additional predefined scenarios
  - `harmful_n1`: effect_R3_dem = 0.2 (more N1 relative to N2 harmful)
  - `competing_death`: Higher death hazard to test competing risk handling

- [ ] **0.11** Implement non-linear effects in DGP (optional)
  - Allow quadratic terms: `effect_R2_squared_dem`
  - Enables U-shaped relationship testing

**Milestone 0.2:** Simulation supports effect modification, multiple scenarios validated.

### Tier 3: Advanced (If Needed)

- [ ] **0.12** Simulate SHHS-1 battery failure missingness
  - ~10% MCAR missingness in S1 stage minutes
  - Set slp_time to NA for affected rows
  - Test imputation pipeline

- [ ] **0.13** Add MRI outcome simulation
  - Generate brain volumes with known ILR effects
  - Include time-to-MRI variation

- [ ] **0.14** Time-varying effects in DGP
  - Allow effect_R2_dem to change over follow-up time

**Milestone 0.3:** Full simulation capability including missingness and MRI.

---

## Phase 1: Stabilize 5-Part Composition and ILR Infrastructure

**Goal:** Lock the intended SHHS-2 exposure definition to the 5-part composition `(N1, N2, N3, WASO, REM)` and keep downstream code and docs aligned.

- [x] **1.1** Update `R/constants.R` - Composition Variables
  - Ensure `comp_vars` is `c("n1_s2", "n2_s2", "n3_s2", "waso_s2", "rem_s2")`
  - Rationale: the intended SHHS-2 exposure composition includes WASO

- [x] **1.2** Update `R/constants.R` - SBP Matrix
  - Maintain the code-defined 5x4 SBP in the fixed component order `(N1, N2, N3, WASO, REM)`:
    ```r
    # Component order: (N1, N2, N3, WASO, REM)
    #        N1  N2  N3  WASO REM
    sbp <- matrix(c(
      -1, -1,  1,  1,  0,
      -1,  0,  0,  1,  1,
       0, -1,  1,  0,  1,
       0,  0, -1,  1,  1
    ), ncol = 5, byrow = TRUE)
    ```
  - Rebuild ILR basis: `v <- gsi.buildilrBase(t(sbp))`

- [x] **1.3** Update `R/utils.R` - `make_ilrs()` function
  - Function should use `comp_vars` (now SHHS-2 variables)
  - Output: 4 ILR coordinates (R1, R2, R3, R4)
  - Ensure `compositions::acomp()` handles any zero values

- [x] **1.4** Update `R/prepare_dataset.R` - ILR creation
  - Assign ILR columns via `ilr_names` so the 5-part basis yields `c("R1", "R2", "R3", "R4")`

- [~] **1.5** Clarify SHHS-2 duration covariate semantics under the 5-part composition
  - Primary models currently adjust for `slp_time_s2`
  - Ideal-composition work must explicitly decide whether to constrain `slp_time_s2` or a sleep-period-time measure that includes `waso_s2`

- [ ] **1.6** Add S1 incomplete indicator
  - Create: `s1_incomplete <- as.integer(is.na(slp_time))`
  - Location: In `prepare_dataset()` function
  - Use: Will be covariate in models

- [~] **1.7** Update all downstream functions using ILR columns
  - Files affected: `R/utils.R`
  - Functions: `apply_substitution()`, `fit_density_model()`, `check_density()`, `get_primary_formula()`
  - Change: downstream code should assume `c("R1", "R2", "R3", "R4")`
  - Update density df: Chi-squared df from 3 to 4 wherever the dimension is hard-coded
  - **FIXED:** Also updated `death_date` → `death_surv_date` in `expand_surv_dt()`

**Milestone 1:** Pipeline and docs agree on the intended 5-part SHHS-2 composition producing 4 ILR coordinates.

**Notes for Next Agent - CRITICAL:**
Previously `sim_fitted_models` failed with a "fewer than 3 unique knots" error due to degenerate `timegroup` after `survSplit()`.

**Resolved:** Updated `make_cuts()`/`survSplit()` usage to avoid including 0 as a cutpoint and to enforce minimum follow-up/unique cutpoints.

If this resurfaces, confirm that:
1. `cut` passed to `survSplit()` excludes 0 and excludes `max_time`
2. `timegroup` has sufficient variation for `rcs(timegroup, ...)`

---

## Phase 2: Update Model Specifications

**Goal:** Implement the full model formula as specified, including interactions and proper covariate adjustment.

- [ ] **2.1** Create `R/formulas.R` - Centralized formula construction
  - New file to separate formula logic from fitting logic
  - Define knot calculation functions for each variable type
  - Benefit: Easier to maintain and test formulas

- [ ] **2.2** Implement SHHS-1 adjustment terms
  - Add to formula: Raw SHHS-1 sleep times with RCS
    ```r
    rcs(n1, knots_n1_s1) + rcs(n2, knots_n2_s1) + rcs(n3, knots_n3_s1) +
    rcs(rem, knots_rem_s1) + s1_incomplete
    ```
  - Handle missingness: When `s1_incomplete == 1`, S1 stage variables may be imputed

- [ ] **2.3** Implement ILR × Time interactions (non-proportional hazards)
  - Add to dementia/death formulas:
    ```r
    rcs(R1, k_r1) * rcs(timegroup, k_time) +
    rcs(R2, k_r2) * rcs(timegroup, k_time) +
    rcs(R3, k_r3) * rcs(timegroup, k_time) +
    rcs(R4, k_r4) * rcs(timegroup, k_time)
    ```

- [ ] **2.4** Implement ILR × Age interactions (effect modification)
  - Add to formulas:
    ```r
    rcs(R1, k_r1) * rcs(age_s1, k_age) +
    rcs(R2, k_r2) * rcs(age_s1, k_age) +
    rcs(R3, k_r3) * rcs(age_s1, k_age) +
    rcs(R4, k_r4) * rcs(age_s1, k_age)
    ```

- [ ] **2.5** Add SHHS-2 sleep-duration covariate
  - Add to formulas: `rcs(slp_time_s2, knots_tst)`

- [ ] **2.6** Add cohort indicator
  - Add to formulas: `IDTYPE` (already available, just needs inclusion)

- [ ] **2.7** Add available confounders (minimal set)
  - Include: `gender`, `educat`, `rcs(bmi_s1, k_bmi)`, `IDTYPE`
  - Note: Full confounder set deferred (race/ethnicity, hypertension, diabetes, CVD, smoking, alcohol, APOE, medications to be added when variable names identified)

- [ ] **2.8** Update `get_primary_formula()` to return complete formula
  - Consolidate all terms into single formula function
  - Accept data to calculate quantile-based knots

- [ ] **2.9** Update `fit_models()` to use new formula
  - Ensure dementia model fits on `death == 0` subset
  - Ensure death model fits on full data

**Milestone 2:** Models fit with proper formula including S1 adjustment, interactions, and TST covariate.

---

## Phase 2.5: Stabilize LMTP Dementia/MCI Pipeline

**Goal:** Make the experimental LMTP/TMLE path estimate and plot the correct substitution-vs-reference dementia/MCI risk ratios.

- [x] **2.5.1** Add explicit no-intervention LMTP reference fit
  - Implement `run_lmtp_tmle_reference()`
  - Estimate observed-risk reference using `lmtp_tmle(..., shift = NULL)`

- [x] **2.5.2** Contrast each substitution fit against the reference
  - Use `lmtp_contrast(sub_fit, ref = ref_fit, type = "rr")`
  - Treat the contrast output as the risk ratio estimand

- [x] **2.5.3** Fix dynamic branching in `analysis_targets.R`
  - `lmtp_tmle_substitutions` now consumes the mapped substitution branch value directly

- [~] **2.5.4** Validate wide survival outcome encoding for `lmtp`
  - `Y_t` and `D_t` are now carried forward after events, matching package examples more closely
  - Later columns can remain `NA` after censoring or terminal events instead of being forced to 0
  - Remaining work: confirm any remaining survival-wide expectations beyond the now-confirmed censoring requirement

- [x] **2.5.5** Confirm LMTP-required censoring changes in shifted data
  - `lmtp:::check_shifted_data()` requires the only differences between `data` and `shifted` to be the `trt` and `cens` columns
  - When censoring is supplied, `shifted[cens]` must be all `1`
  - Current code in `run_lmtp_tmle_substitution()` matches that package expectation

- [ ] **2.5.6** Separate LMTP plotting from bootstrap g-computation plotting
  - Current helper re-use hides whether the plotted quantity is an intervention mean or a contrast
  - Create an LMTP-specific plotting helper if needed

- [x] **2.5.7** Verify that duration 0 gives risk ratio approximately 1
  - Observed smoke test result was approximately `1.0007` with a tight CI around 1

- [ ] **2.5.8** Localize the remaining LMTP fit failure
  - `SL.glmnet`-containing stacks were the main source of sparse-class `lognet()` failures; defaults were simplified
  - Direct calls to `run_lmtp_tmle_substitution()` now succeed for at least the previously failing early substitution branches
  - Remaining problem: the full branched `lmtp_tmle_substitutions` target can still error with a generic `argument is of length zero`
  - Next debugging step:
    1. use the new branch-aware error messages to identify the exact failing substitution branch in `targets`
    2. compare that branch under direct execution vs `targets` execution
    3. determine whether the residual issue is in `targets` branching/aggregation rather than the LMTP fit itself

**Milestone 2.5:** LMTP substitution outputs are true risk ratios against no intervention, and the plotted values match that estimand.

---

## Phase 3: Fix Multiple Imputation Infrastructure

**Goal:** Implement proper m=10 multiple imputation with Rubin's rules pooling.

- [ ] **3.1** Restructure `impute_data()` to return mids object
  - Change: Return `mice` mids object, not single completed dataset
  - Keep: m=10 imputations
  - Keep: Truncated normal method with lower bounds

- [ ] **3.2** Update imputation predictors
  - Include in imputation model:
    - SHHS-2 exposure variables (`n1_s2`, `n2_s2`, `n3_s2`, `waso_s2`, `rem_s2`, `slp_time_s2`)
    - Outcomes (`dem_or_mci_status`, log-transformed `dem_or_mci_surv_date`)
    - Confounders (`age_s1`, `gender`, `bmi_s1`, `educat`)
  - Exclude from imputation: PID, raw backup variables

- [ ] **3.3** Create `R/pooling.R` - Rubin's rules utilities
  - Function: `pool_models(fits_list)` - pool coefficients from m model fits
  - Function: `pool_contrasts(contrasts_list)` - average contrasts across imputations
  - Use: `mice::pool()` internally where applicable

- [ ] **3.4** Create `fit_models_mi()` function
  - Input: mids object, timegroup_cuts
  - Process: 
    1. Loop over m imputations
    2. Fit dementia + death model in each
    3. Return list of m model pairs
  - Storage: Consider memory - may need to pool immediately

- [ ] **3.5** Create `predict_risks_mi()` function
  - Input: mids object, list of m model pairs, timegroup_cuts
  - Process:
    1. For each imputation: predict risks
    2. Average predictions across m imputations
  - Output: Pooled risk estimates

- [ ] **3.6** Update `data_targets.R` - imputation target
  - Change: `imp` target now returns mids object
  - Add: Target for imputed data list if needed for other operations

- [ ] **3.7** Update `analysis_targets.R` - model fitting
  - Change: `fitted_models` becomes `fitted_models_mi` using new function
  - Add: Pooled coefficient summaries target

**Milestone 3:** Pipeline produces m=10 imputations with pooled model estimates.

---

## Phase 4: Fix Isotemporal Substitution Pipeline

**Goal:** Correct substitution logic and restructure targets for efficiency.

- [ ] **4.1** Update `analysis_targets.R` - substitution grid
  - Remove: `wake` from grid
  - Update components: `c("n1_s2", "n2_s2", "n3_s2", "waso_s2", "rem_s2")`
  - Update durations: `c(15, 30, 60)` (specs say 15 min resolution)
  - Result: 10 pairs × 2 directions × 3 durations = 60 substitutions

- [ ] **4.2** Update `apply_substitution()` for S2 variables
  - Change: Operate on `*_s2` variables
  - Change: Output 4 ILR columns (R1, R2, R3, R4)
  - Keep: Validity checking (non-negative, within percentile bounds)

- [ ] **4.3** Update `make_comp_limits()` for S2 variables
  - Change: Calculate limits from `n1_s2`, `n2_s2`, `n3_s2`, `waso_s2`, `rem_s2`
  - Update percentiles: 1st-99th for feasibility

- [ ] **4.4** Create substitution targets with dynamic branching
  - Structure:
    ```r
    tar_target(substitution_grid, {...})  # Define grid
    tar_target(
      substituted_data,
      apply_substitution(imp, from, to, duration, comp_limits),
      pattern = map(substitution_grid)
    )
    ```
  - Note: Handle MI - apply substitution to each imputed dataset

- [ ] **4.5** Update density checking for 4 ILRs
  - Change: df=4 for chi-squared threshold
  - Change: Use 4 ILR columns

- [ ] **4.6** Create substitution risk prediction target
  - Input: Substituted data branches, fitted models
  - Process: Predict risks for each substitution
  - Output: Risk difference and risk ratio for each substitution

- [ ] **4.7** Add `n_intervened` tracking
  - Track: How many participants had their composition actually shifted
  - Report: Include in output for transparency

- [ ] **4.8** Create summary target for isotemporal results
  - Combine: All substitution results into single summary table
  - Format as specified in `specs/analysis.md`:
    ```r
    data.table(
      from = "rem_s2",
      to = "n3_s2",
      duration = 15,
      mean_risk_baseline = 0.XX,
      mean_risk_substituted = 0.XX,
      risk_difference = 0.XX,
      risk_ratio = 0.XX,
      n_intervened = XXX,
      n_total = XXX
    )
    ```

**Milestone 4:** Isotemporal substitutions run correctly with proper 4-component S2 composition.

---

## Phase 5: Implement MRI Outcomes Analysis

**Goal:** Add secondary MRI outcome models.

- [ ] **5.1** Update `R/prepare_dataset.R` - MRI variable selection
  - Identify: First post-SHHS-2 MRI for each participant
  - Create: `time_to_mri` variable (days from SHHS-2)
  - Create: `mri_after_dem_mci` indicator

- [ ] **5.2** Create MRI dataset target
  - Filter: Participants with valid post-SHHS-2 MRI
  - Select: Relevant MRI outcome columns

- [ ] **5.3** Create `get_mri_formula()` function
  - Base: Similar to primary formula but:
    - No timegroup (cross-sectional)
    - Add `time_to_mri` with RCS
    - Add ICV for volumetric outcomes (**FLAG: ICV variable name TBD**)
    - Add `mri_after_dem_mci` indicator
    - Keep ILR × Age interactions

- [ ] **5.4** Create `fit_mri_model()` function
  - Model type: `lm()` for continuous outcomes
  - Outcomes:
    - Total brain volume (`Total_brain_*`)
    - Cerebrum grey matter (`Cerebrum_gray_*`)
    - Cerebrum white matter (`Cerebrum_white_*`)
    - Hippocampal volume (`Hippo_*`)
    - WMH (`FLAIR_wmh_*` or `DSE_wmh_*`, log-transformed)

- [ ] **5.5** Handle WMH transformation
  - Transform: `log1p(wmh)` as primary
  - Create: Function to apply transformation

- [ ] **5.6** Create MRI model targets
  - One target per outcome, or mapped over outcome list
  - Include: MI pooling

- [ ] **5.7** Create MRI isotemporal substitution effects
  - Apply: Same substitution grid to MRI outcomes
  - Predict: Mean outcome under each substitution

- [ ] **5.8** Create MRI summary targets
  - Combine: Results across outcomes and substitutions

**Milestone 5:** MRI outcomes analyzed with same methodology as dementia outcome.

---

## Phase 6: Implement Bootstrap Inference and Ideal Composition

**Goal:** Add uncertainty quantification and ideal composition search.

### Bootstrap Infrastructure

- [ ] **6.1** Define Bootstrap × MI structure
  - **Recommended approach (per specs):**
    1. Bootstrap resample participants (B configurable, default=500, dev=50)
    2. Within each bootstrap sample: run MI (m=10)
    3. Fit models in each imputed dataset
    4. Average contrasts across m imputations → one bootstrap estimate
    5. Compute percentile CIs from B bootstrap estimates
  - **Configuration:** Add `BOOTSTRAP_B` to constants or config (default=500, easily changeable for dev)

- [ ] **6.2** Create `R/bootstrap.R` - Bootstrap utilities
  - Function: `bootstrap_sample(dt, seed)` - resample with replacement by PID
  - Function: `bootstrap_iteration(dt, seed, ...)` - full single bootstrap iteration
  - Output: Minimal results (estimates only, not full model objects)

- [ ] **6.3** Add crew controller to `_targets.R`
  - Setup: `tar_option_set(controller = crew::crew_controller_local(workers = N))`
  - Config: N configurable via environment variable or constant
  - Note: Will be increased on HPC

- [ ] **6.4** Create bootstrap targets structure
  - Use dynamic branching with seeds:
    ```r
    tar_target(bootstrap_seeds, seq_len(BOOTSTRAP_B))
    tar_target(
      bootstrap_estimates,
      bootstrap_iteration(dt, bootstrap_seeds, ...),
      pattern = map(bootstrap_seeds)
    )
    ```

- [ ] **6.5** Create `compute_bootstrap_ci()` function
  - Input: Vector of B estimates
  - Output: Percentile CI (2.5th, 97.5th)
  - Apply to: Risk differences, risk ratios, mean MRI effects

- [ ] **6.6** Create confidence interval targets
  - Combine: Bootstrap estimates
  - Compute: CIs for all primary estimates

### Ideal Composition Search

- [ ] **6.7** Implement ideal composition grid generation
  - Function: `generate_composition_grid(whole_fixed, resolution, bounds)`
    - First define whether `whole_fixed` is `slp_time_s2` or a sleep-period-time measure that includes `waso_s2`
    - Generate all `(n1, n2, n3, waso, rem)` satisfying that fixed-whole definition
    - Resolution = 15 minutes
    - Within 2.5th-97.5th percentile bounds for each component
  - Implementation: Loop over 4 components and solve the 5th once the fixed-whole definition is finalized

- [ ] **6.8** Filter grid by density
  - Apply: Mahalanobis distance check (same threshold as isotemporal: 95% chi-sq, df=4)
  - Keep: Only plausible compositions

- [ ] **6.9** Create grid prediction target
  - For each plausible composition:
    - Assign to all participants
    - Predict mean outcome via g-computation
  - Use branching: Over filtered grid points

- [ ] **6.10** Identify best/worst compositions
  - Find: Composition with lowest mean dementia risk (best)
  - Find: Composition with highest mean dementia risk (worst)
  - Report: Both compositions and their predicted risks

- [ ] **6.11** Add bootstrap CIs for ideal composition
  - Within bootstrap: Repeat grid search
  - Output: CI for best composition's predicted risk

**Milestone 6:** Full analysis with bootstrap CIs and ideal composition search.

---

## Phase 7: Reporting and Documentation

**Goal:** Automated report generation and final documentation.

- [ ] **7.1** Create `report.qmd` Quarto report
  - Sections:
    - Data summary (N, exclusions, descriptives - aggregated only, NO individual data)
    - Model fit diagnostics
    - Isotemporal substitution results (table + figures)
    - Ideal composition results
    - MRI results
    - Sensitivity analyses (if any)

- [ ] **7.2** Create report targets
  - Target: `tar_quarto(report, "report.qmd")`
  - Dependencies: All result objects

- [ ] **7.3** Create helper functions for tables/figures
  - Tables: Coefficient summaries, substitution effects with CIs
  - Figures: Risk curves, composition heatmaps/surface plots

- [ ] **7.4** Update `AGENTS.md` with final implementation notes
  - Document: Any deviations from specs
  - Update: Implementation status table to reflect completion

**Milestone 7:** Reproducible report generated from pipeline.

---

## Dependency Graph

```
Phase 0 (Simulation) ←──── Can run in parallel with real data phases
    ↓                      (uses same pipeline code)
    ↓
Phase 1 (Composition) 
    ↓
Phase 2 (Models)
    ↓
Phase 3 (MI) ←──────────────────┐
    ↓                           │
Phase 4 (Substitutions)         │
    ↓                           │
Phase 5 (MRI) ←─────────────────┤
    ↓                           │
Phase 6 (Bootstrap + Ideal) ────┘
    ↓
Phase 7 (Reporting)
```

**Note:** Phase 0 (Simulation) should be implemented first as it enables:
1. Privacy-safe development - agents can query simulated data freely
2. Pipeline validation - verify code works before running on real data
3. Faster iteration - smaller sample sizes for quick testing

---

## Configuration Parameters

These should be easily configurable (e.g., in `R/constants.R` or via environment variables):

| Parameter | Default | Dev/Test | Description |
|-----------|---------|----------|-------------|
| `BOOTSTRAP_B` | 500 | 50 | Number of bootstrap resamples |
| `MI_M` | 10 | 5 | Number of multiple imputations |
| `MI_MAXIT` | 10 | 5 | Max iterations for mice |
| `GRID_RESOLUTION` | 15 | 30 | Minutes resolution for ideal composition grid |
| `CREW_WORKERS` | 4 | 2 | Number of parallel workers |
| `SIM_N` | 1500 | 500 | Sample size for simulated data |
| `SIM_SEED` | 42 | 42 | Random seed for simulation reproducibility |

---

## Deferred Items

These items are noted but deferred for later implementation:

1. **Full confounder set:** Race/ethnicity, hypertension, diabetes, CVD status, smoking, physical activity, alcohol, APOE ε4, sedative/sleeping pill/antidepressant use - variable names need to be identified from data dictionaries

2. **CVD exclusion:** Exclude participants with CVD events before SHHS-2 - requires exploration of available CVD variables

3. **ICV variable for MRI:** Intracranial volume variable name TBD from MRI dataset

4. **TST-varying sensitivity analysis:** For ideal composition, allow TST to vary (currently only TST-fixed primary analysis planned)

5. **Additional sensitivity analyses:** Dementia-only (excluding MCI), different follow-up windows, MRI restricted to pre-dementia scans

6. **Advanced simulation features:** Time-varying effects, covariate-dependent censoring, complex missingness patterns (Tier 3 items)

---

## Notes

- **Data confidentiality:** Never print, display, or log individual-level data. Only aggregated statistics allowed.
- **Simulated data:** Use `sim_dt` targets for development and testing. Agents can freely query simulated data without privacy concerns.
- **Testing:** After each phase, run `tar_make()` and verify pipeline completes without errors.
- **Git:** Commit after each milestone with descriptive message.
- **Validation:** For simulation scenarios, check `validation_summary` target to verify pipeline recovers known effects.

---

## Recent Changes & Notes for Next Agent

### Completed (Last Session)

1. **LMTP contrast path tightened:**
   - Added an explicit no-intervention reference fit
   - Contrasted substitution fits against the reference with `lmtp_contrast(..., type = "rr")`
   - Corrected mapped substitution branching and added a 0-minute smoke test near RR = 1

2. **Survival-wide encoding tightened:**
   - `Y_t` and `D_t` now carry forward after events more consistently with `lmtp` survival examples
   - Confirmed against `lmtp` package source that censoring columns in `shifted` should be set to `1`
   - SHHS-2 `slp_time_s2` is the documented duration covariate; SHHS-1 `slp_time` is not part of the intended baseline adjustment once SHHS-1 stage minutes are included

3. **Learner-stack localization:**
   - `SL.mean/SL.mean`, `SL.glm/SL.glm`, and `SL.mean + SL.glm` with 5 folds all ran on the current substitution path
   - Configurations that included `SL.glmnet` produced repeated sparse-class `lognet()` failures and the associated intermittent `non-conformable arguments` path
   - The default LMTP learner targets were simplified accordingly

4. **Targets-branch debugging support added:**
   - `run_lmtp_tmle_substitution()` now validates substitution inputs and rethrows errors with `from`, `to`, `duration`, folds, and learner details
   - The `lmtp_tmle_substitutions` target now wraps branch errors with the substitution label so future failures are easier to localize
   - Local debug scripts were added for learner-stack sweeps and direct all-substitutions runs outside `targets`

5. **Exposure definition clarified:**
   - The intended SHHS-2 exposure is the 5-part composition `(n1_s2, n2_s2, n3_s2, waso_s2, rem_s2)`
   - Older 4-part plan/spec text was stale and has been corrected
   - Remaining 4-part drift is now mostly in simulation/test scaffolding and ideal-composition planning

### Previously Blocking Issue (Resolved)

**Problem:** `sim_fitted_models` failed with an RCS knot error because `timegroup` was constant (often all zeros) after `survSplit()`.

**Fix:**
- `make_cuts()` now drops 0, enforces minimum follow-up, and guarantees ≥3 unique cutpoints.
- `survSplit()` now receives only internal cutpoints (`< max_time`) to avoid edge-case degeneracy.

**Regression test:** `./nixr.sh "targets::tar_make(names = 'sim_fitted_models')"`

### Quick Commands for Next Agent

```bash
# Run all simulation targets
./nixr.sh "targets::tar_make(names = starts_with('sim_'))"

# Check what's outdated
./nixr.sh "targets::tar_outdated()"

# Load and inspect simulated data
./nixr.sh "targets::tar_load(sim_dt); print(names(sim_dt))"

# Run specific target with debug
./nixr.sh "targets::tar_make(names = 'sim_fitted_models', callr_function = NULL)"
```

### Priority Order for Next Work

1. Rerun `lmtp_tmle_substitutions` through `targets` and use the new branch-aware error messages to isolate the residual branch-level failure.
2. If the direct substitution call still succeeds for that branch, inspect `targets` branching/aggregation rather than the LMTP fit itself.
3. Sweep remaining 4-part assumptions in simulation/test scaffolding and finalize the duration/whole definition needed for ideal-composition work under the 5-part exposure.
4. Separate LMTP plotting from the bootstrap g-computation helper once the fit path is stable.
