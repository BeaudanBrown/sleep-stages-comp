# Analysis Specification

## Overview

Two main analyses:
1. **Isotemporal substitutions:** Effect of reallocating time between specific sleep stages
2. **Ideal composition:** Finding the sleep stage distribution associated with best outcomes

Both use **g-computation** with **density-bounded interventions** to ensure counterfactual compositions are plausible.

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
    - If distance exceeds the 95% chi-squared threshold (df = 3), the shifted composition is implausible.
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

### Substitution Grid

Default substitutions to evaluate:

| Duration | All pairwise substitutions |
|----------|---------------------------|
| 15 min | N1↔N2, N1↔N3, N1↔REM, N2↔N3, N2↔REM, N3↔REM |
| 30 min | Same pairs |
| 60 min | Same pairs |

**Configuration:** Duration values are configurable in `analysis_targets.R`.

### Density Threshold

```r
# MVN density check
threshold_quantile <- 0.05
threshold <- qchisq(1 - threshold_quantile, df = 3)  # df = number of ILR coords

# Check if shifted composition is plausible
d2 <- mahalanobis(ilr_sub, center = mu, cov = sigma)
is_plausible <- d2 <= threshold
```

---

## Ideal Composition Search

### Concept
Find the composition (N1, N2, N3, REM) associated with the best (and worst) expected outcomes.

### Algorithm

### Primary analysis: constrain total sleep time (TST)

Primary ideal-composition analysis constrains total sleep time to the **median observed SHHS-2 TST** for interpretability.

1. **Generate grid of compositions at fixed TST:**

   a. Set `resolution <- 15` minutes.

   b. Define component bounds (default: 2.5th–97.5th percentiles for each stage).

   c. Enumerate integer-minute (or `resolution`-grid) compositions `(n1, n2, n3, rem)` such that:
   - `n1 + n2 + n3 + rem == TST_fixed`
   - each component lies within its bounds

   Implementation note: generate valid tuples directly (e.g., loop over 3 components and solve the 4th as `rem = TST_fixed - n1 - n2 - n3`) to avoid an infeasible 4D Cartesian grid.

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

### Total Sleep Time Handling

### Sensitivity analysis: allow TST to vary

As a sensitivity analysis, allow TST to vary across grid points, and report `total_sleep = n1 + n2 + n3 + rem` alongside predicted mean outcomes.

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

- **Substitution logic:** `R/utils.R` → `apply_substitution()`, `perform_isotemporal_substitution()`
- **Density checking:** `R/utils.R` → `fit_density_model()`, `check_density()`
- **Risk prediction:** `R/utils.R` → `predict_risks()`
- **Grid definition:** `analysis_targets.R` → `substitution_grid`

---

## Output Structure

### Isotemporal Results

```r
# Per substitution:
data.table(
  from = "rem",
  to = "n3",
  duration = 15,
  mean_risk_baseline = 0.XX,
  mean_risk_substituted = 0.XX,
  risk_difference = 0.XX,
  risk_ratio = 0.XX,
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
