# Analysis Specification

## Overview

Two main analyses:
1. **Isotemporal substitutions:** Effect of reallocating time between specific sleep stages
2. **Ideal composition:** Finding the sleep stage distribution associated with best outcomes

Both use **g-computation** with **density-bounded interventions** to ensure counterfactual compositions are plausible.

## Current Development Status

The repository currently contains two partially overlapping implementations for the dementia/MCI substitution analysis:

1. A more mature **g-computation / pooled logistic** pipeline.
2. An experimental **LMTP / TMLE** pipeline.

The immediate development goal is to make the LMTP path estimate the same scientific contrast that the g-computation path reports:

> the risk ratio comparing each substitution policy to the no-intervention dementia/MCI risk.

This means the LMTP path must estimate:

1. A **reference fit** under no intervention.
2. A **substitution fit** for each policy.
3. A **contrast** between the two, using `lmtp_contrast(..., type = "rr")`.

### Current LMTP notes

- `lmtp_tmle()` estimates the mean outcome under a single intervention.
- `lmtp_contrast()` is required to convert those intervention means into risk ratios relative to a reference.
- The plotted LMTP quantity should be the **contrast-based risk ratio**, not the raw intervention mean.
- A 0-minute substitution is now the primary smoke test for the LMTP contrast path and should give a risk ratio approximately equal to 1.

### Known LMTP issues still to fix

- The mapped substitutions target has been corrected, but the full LMTP branch still needs end-to-end validation after rebuild.
- The survival-wide `Y_t` and `D_t` construction has been updated to use cumulative event coding, closer to the `lmtp` package examples.
- The intended exposure composition is the 5-part SHHS-2 set `(N1, N2, N3, WASO, REM)`, so substitution grids and density checks should use 4 ILR coordinates.
- SHHS-1 `slp_time` should not be adjusted for when SHHS-1 stage components are already included.
- SHHS-2 `slp_time_s2` should be adjusted for explicitly because the ILR coordinates encode composition, not duration.
- The current contract keeps `s1_incomplete` as a separate indicator and treats the broader non-sleep confounder set as additive-only until the final confounder sweep is done.
- The `lmtp` package expects the only differences between `data` and `shifted` to be the treatment and censoring columns; when censoring is supplied, the shifted censoring columns should be all `1`.
- The current plotting code still reuses the bootstrap plotting helper and should be treated as provisional until the LMTP outputs are stabilized.
- Simplifying the default learners away from `SL.glmnet` improved the direct LMTP substitution path materially.
- The remaining unresolved issue is now the full `targets`-branched `lmtp_tmle_substitutions` target, which can still fail with a generic branch-level error even when the same substitution call succeeds directly.
- The LMTP substitution code and the branched target now rethrow errors with explicit substitution context to support the next debugging pass.
- Immediate next step: rerun the branched LMTP target and use the new branch-aware error messages to determine whether the residual failure is in `targets` branching/aggregation rather than the LMTP fit.

---

## Isotemporal Substitutions

### Concept
An isotemporal substitution answers: "What would happen if we increased time in stage A by X minutes, with that time coming from stage B, holding everything else constant?"

### Algorithm

1. **Fit models** on observed data:
   - Dementia hazard model
   - Death hazard model (competing risk)
   - (For MRI: linear regression)

2. **Fit density model:**
   - Multivariate normal on ILR coordinates
   - Used to determine if shifted compositions are plausible

3. **Calculate baseline risk:**
   - Predict outcomes under observed (no intervention) compositions
   - This is the reference for comparison

4. **For each substitution (e.g., +15 min N3 from REM):**
   
   a. **Apply substitution in composition space:**
   ```r
   dt_sub <- copy(dt)
   dt_sub$n3_s2 <- dt_sub$n3_s2 + 15
   dt_sub$rem_s2 <- dt_sub$rem_s2 - 15
   ```
   
    b. **Check validity (feasibility constraints):**
    - Stage minutes must remain non-negative.
    - Each component must stay within plausible range (default: 1st-99th percentile of observed values).
   
   c. **Transform to ILR:**
   ```r
   ilr_sub <- make_ilrs(dt_sub)
   ```
   
    d. **Check density (plausibility constraint):**
    - Calculate Mahalanobis distance from MVN center.
    - If distance exceeds the 95% chi-squared threshold (df = 4), the shifted composition is implausible.
    - For implausible cases, **keep original composition** (no intervention for that participant).
   
   e. **Predict counterfactual outcomes:**
   - Use shifted ILRs (or original if implausible) to predict
   
    f. **Calculate contrast:**
    - Risk difference: mean(risk_substituted) - mean(risk_baseline)
    - Risk ratio: mean(risk_substituted) / mean(risk_baseline)

### Estimand / interpretation
Because we revert to the original composition when a shift is infeasible or implausible, the estimand corresponds to the policy:

> “Apply the requested shift if feasible and plausible; otherwise leave the composition unchanged.”

We will report `n_intervened` (number of participants whose composition was actually shifted) for transparency.

### LMTP implementation target

For the experimental LMTP path, the substitution analysis should be implemented as:

```r
psi_null <- lmtp_tmle(..., shift = NULL, outcome_type = "survival")
psi_sub  <- lmtp_tmle(..., shifted = shifted_data, outcome_type = "survival")
rr_sub   <- lmtp_contrast(psi_sub, ref = psi_null, type = "rr")
```

The plotted and reported primary estimand should be the **risk ratio from `rr_sub`**.
The intervention-specific mean risk from `psi_sub` may still be retained as metadata, but it is not the main contrast.

### Sleep duration adjustment

For the intended dementia/MCI analysis:

- **SHHS-1:** adjust for the component minutes (`n1`, `n2`, `n3`, `rem`) and do **not** also adjust for `slp_time`, since it is already determined by the components.
- **SHHS-2:** adjust for `slp_time_s2` separately, because the SHHS-2 ILR coordinates encode the sleep-stage composition but not the total sleep duration.
- **Missing SHHS-1 whole:** encode incomplete SHHS-1 stage history with `s1_incomplete` as a separate main-effect indicator rather than trying to spline a missing `slp_time`.

### Substitution Grid

Default substitutions to evaluate:

| Duration | All pairwise substitutions |
|----------|---------------------------|
| 15 min | All pairwise substitutions among N1, N2, N3, WASO, REM |
| 30 min | Same pairs |
| 60 min | Same pairs |

**Configuration:** Duration values are configurable in `analysis_targets.R`.

### Density Threshold

```r
# MVN density check
threshold_quantile <- 0.05
threshold <- qchisq(1 - threshold_quantile, df = 4)  # df = number of ILR coords

# Check if shifted composition is plausible
d2 <- mahalanobis(ilr_sub, center = mu, cov = sigma)
is_plausible <- d2 <= threshold
```

---

## Ideal Composition Search

### Concept
Find the composition (N1, N2, N3, WASO, REM) associated with the best (and worst) expected outcomes.

### Algorithm

### Primary analysis: constrain a fixed duration/whole definition

Primary ideal-composition analysis still needs an explicit definition of the fixed "whole" under the 5-part composition. Before implementation, decide whether to constrain `slp_time_s2` or a derived sleep-period-time measure that includes `waso_s2`.

1. **Generate grid of compositions at a fixed duration/whole:**

   a. Set `resolution <- 15` minutes.

   b. Define component bounds (default: 2.5th–97.5th percentiles for each stage).

   c. Enumerate integer-minute (or `resolution`-grid) compositions `(n1, n2, n3, waso, rem)` such that:
   - the chosen duration/whole definition is held fixed
   - each component lies within its bounds

   Implementation note: once the fixed-whole definition is finalized, generate valid tuples directly (e.g., loop over 4 components and solve the 5th) instead of attempting a full 5D Cartesian grid.

2. **Filter by density:**
   
   a. Transform each grid composition to ILR
   b. Calculate Mahalanobis distance
   c. Keep only compositions with d2 <= threshold (same threshold as isotemporal)

3. **Predict for each plausible composition:**
   
   For each composition in the filtered grid:
   a. Assign that composition to all participants (intervention)
   b. Predict mean outcome via g-computation
   c. Store the result

4. **Identify optimal:**
   
   - **Best composition:** Composition with lowest mean dementia risk (or highest brain volume for MRI)
   - **Worst composition:** Composition with highest mean dementia risk

### Grid Resolution

- **Default:** 15 minutes
- **Trade-off:** Finer resolution → more precision, but exponentially more computations
- **Configurable** in `analysis_targets.R`

### Duration Handling

### Sensitivity analysis: allow the whole to vary

As a sensitivity analysis, allow the chosen whole to vary across grid points and report the associated duration measures alongside predicted mean outcomes.

---

## Bootstrap Inference

All estimates are accompanied by bootstrap confidence intervals.

### Procedure

We use **B = 500** participant-level bootstrap resamples.

For each bootstrap sample:
1. Resample participants with replacement.
2. Perform multiple imputation (m = 10) within the bootstrap sample.
3. For each imputed dataset:
   - Re-fit dementia and death models
   - Re-fit density model
   - Re-calculate baseline risk
   - Re-calculate substitution effects / ideal composition
4. Average the estimand(s) across imputations to obtain one bootstrap replicate estimate.

Percentile CIs are computed from the bootstrap distribution.

Rubin's Rules pooling is used for reporting model coefficients (secondary outputs). Primary uncertainty for causal contrasts is obtained from the bootstrap.

### Implementation Notes

- Bootstrap is computationally expensive; local runs are intended for development/iteration.
- Store minimal results per bootstrap (estimates and metadata, not full model objects).
- Parallelization strategy for the final HPC run is managed separately.

---

## G-Computation Details

### For Dementia (Survival Outcome)

Cumulative incidence with competing risks (cause-specific hazards):

```r
# For each person-period:
# P(event by time t) = sum over k<=t of:
#   P(event at k) * P(survived and no death up to k-1)

surv_dt[, risk := cumsum(
  haz_dem * (1 - haz_death) * 
  cumprod((1 - lag(haz_dem, 0)) * (1 - lag(haz_death, 0)))
), by = PID]
```

### For MRI (Continuous Outcome)

Simple mean of predicted values:

```r
mean_outcome <- mean(predict(model, newdata = dt_intervention))
```

---

## Code References

- **Substitution logic:** `R/substitution_utils.R` → `apply_substitution()`, `compute_substituted_risk()`
- **Risk prediction:** `R/survival_utils.R` → `predict_risks()`
- **Grid definition:** `R/substitution_utils.R` → `make_substitution_grid()`, `analysis_targets.R` → `substitutions`

---

## Output Structure

### Isotemporal Results

```r
# Per substitution:
data.table(
  from = "rem",
  to = "n3",
  duration = 15,
  mean_risk_reference = 0.XX,
  mean_risk_substituted = 0.XX,
  risk_difference = 0.XX,
  mean_risk_ratio = 0.XX,
  lower_ci = 0.XX,
  upper_ci = 0.XX,
  n_intervened = XXX,  # Number of participants with plausible shift
  n_total = XXX
)
```

### Ideal Composition Results

```r
# Grid search results:
data.table(
  n1 = XX,
  n2 = XX, 
  n3 = XX,
  rem = XX,
  total_sleep = XX,
  mean_risk = 0.XX
)

# Summary:
list(
  best_composition = c(n1 = XX, n2 = XX, n3 = XX, rem = XX),
  best_risk = 0.XX,
  worst_composition = c(...),
  worst_risk = 0.XX
)
```

---

## Reporting

Deliverables include:
1. Cached results objects produced by the `{targets}` pipeline (e.g., `.qs` outputs for fitted models, risk curves, substitution tables, and grid-search results).
2. An automated rendered report (Quarto/R Markdown) that summarizes the primary results and key diagnostics using only aggregate outputs (no individual-level data).
