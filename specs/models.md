# Model Specification

## Overview

| Outcome | Model | Link | Notes |
|---------|-------|------|-------|
| Dementia | Pooled logistic regression | Logit | Discrete-time survival |
| Death | Pooled logistic regression | Logit | Competing risk |
| MRI volumes | Linear regression | Identity | Cross-sectional |

---

## Dementia Model (Primary)

### Structure
Pooled logistic regression approximating a Cox proportional hazards model with time-varying baseline hazard.

```r
glm(dem_or_mci ~ [formula], data = surv_dt[death == 0], family = binomial())
```

**Note:** Fit only among those who haven't died (`death == 0`), as death is a competing risk.

**Competing risk approach:** We use a **cause-specific hazard** framework (dementia hazard among those alive and dementia-free), combined with an explicit death hazard model for g-computation.

### Formula Structure

The primary analysis uses a **reduced interaction** specification to avoid overfitting:

1. **ILR coordinates** (R1, R2, R3) with restricted cubic splines (RCS)
2. **Time** (`timegroup`) with RCS, interacted with ILR RCS terms (non-proportional hazards)
3. **Age** (`age_s1`) with RCS, interacted with ILR RCS terms (effect modification by age)
4. **Full confounder set** as *main effects* (see `specs/data.md`)
5. **SHHS-1 sleep adjustment** as *main effects* (raw minutes, RCS)
6. **SHHS-2 total sleep time** as a separate covariate (RCS)

### Proposed formula (schematic)

```r
primary_formula <- ~ 
  # ILR main effects with RCS (SHHS-2 exposure composition)
  rcs(R1, knots_R1) +
  rcs(R2, knots_R2) +
  rcs(R3, knots_R3) +

  # Time-varying effects (non-proportional hazards): ILR × Time
  rcs(R1, knots_R1) * rcs(timegroup, knots_time) +
  rcs(R2, knots_R2) * rcs(timegroup, knots_time) +
  rcs(R3, knots_R3) * rcs(timegroup, knots_time) +

  # Effect modification by age: ILR × Age
  rcs(R1, knots_R1) * rcs(age_s1, knots_age) +
  rcs(R2, knots_R2) * rcs(age_s1, knots_age) +
  rcs(R3, knots_R3) * rcs(age_s1, knots_age) +

  # Main effects: required confounders (exact variable list in specs/data.md)
  IDTYPE +
  educat +
  gender +
  ethnicity +
  apoe_e4 +
  rcs(bmi_s1, knots_bmi) +
  hypertension +
  diabetes +
  smoking_status +
  alcohol_use +
  physical_activity +
  waist_circumference +
  sedative_use +
  sleeping_pill_use +
  antidepressant_use +

  # SHHS-1 sleep adjustment (raw times; battery failures handled via MI + indicator)
  rcs(n1, knots_n1_s1) +
  rcs(n2, knots_n2_s1) +
  rcs(n3, knots_n3_s1) +
  rcs(rem, knots_rem_s1) +
  rcs(slp_time, knots_slp_s1) +
  s1_incomplete +

  # SHHS-2 total sleep time (TST) as separate covariate
  rcs(total_sleep_time_s2, knots_tst)
```

Notes:
- `R1`, `R2`, `R3` are ILR coordinates derived from the **SHHS-2** 4-part composition `(N1, N2, N3, REM)`.
- The confounder variable names above are placeholders until the definitive names are confirmed.

### Knot Placement

Use quantile-based knots for RCS:
- **3 knots** at 10th, 50th, 90th percentiles (default)
- **4 knots** for variables with complex relationships (consider for age)

```r
knots_R1 <- quantile(dt$R1, c(0.10, 0.50, 0.90))
knots_time <- quantile(dt$timegroup, c(0.10, 0.50, 0.90))
knots_age <- quantile(dt$age_s1, c(0.10, 0.50, 0.90))
# etc.
```

---

## Death Model (Competing Risk)

Same structure as dementia model, but fit on all observations:

```r
glm(death ~ [formula], data = surv_dt, family = binomial())
```

Uses the same formula as the dementia model.

Interpretation:
- The dementia model estimates the **cause-specific dementia hazard** among those alive.
- The death model estimates the **cause-specific death hazard**.
- G-computation combines both to yield cumulative incidence accounting for competing death.

---

## MRI Models (Secondary)

### Structure
Linear regression for each MRI outcome:

```r
lm(mri_outcome ~ [formula], data = dt_mri)
```

### Formula Modifications from Dementia Model

1. **No `timegroup`:** Cross-sectional, not survival
2. **Add time-to-MRI:** Adjust for when MRI was taken
3. **Add ICV:** Adjust for intracranial volume (volumetric outcomes only)
4. **No competing risk modeling:** N/A for cross-sectional MRI outcomes

```r
mri_formula <- ~
  # ILR effects
  rcs(R1, knots_R1) + rcs(R2, knots_R2) + rcs(R3, knots_R3) +
  
  # ILR × key modifier interactions
  rcs(R1, knots_R1) * rcs(age_s1, knots_age) + ... +
  
  # Time since SHHS-2

  rcs(time_to_mri, knots_mri_time) +
  
  # Intracranial volume (for volumetric outcomes)
  rcs(icv, knots_icv) +
  
  # Same confounders as dementia model
  ...
```

---

## Discrete Time Intervals

For survival analysis, continuous time is discretized into intervals:

```r
# Annual intervals (365 days) from SHHS-2
timegroup_cuts <- seq(0, max_followup, by = 365)

# Expand data to person-period format
surv_dt <- survSplit(
  Surv(time = dem_or_mci_surv_date, event = dem_or_mci_status) ~ .,
  data = dt,
  cut = timegroup_cuts,
  episode = "timegroup"
)
```

---

## Model Storage

Large model objects are stripped of unnecessary components before caching:

```r
# Remove data, residuals, fitted values to reduce size
model <- strip_glm(model)  # See R/utils.R
```

This preserves coefficients and prediction ability while reducing storage.

---

## Prediction

For g-computation, predictions are made on the full person-period dataset:

```r
# Predict hazards
surv_dt$haz_dem <- predict(model_dem, newdata = surv_dt, type = "response")
surv_dt$haz_death <- predict(model_death, newdata = surv_dt, type = "response")

# Calculate cumulative incidence with competing risks
# See R/utils.R → predict_risks()
```

---

## Code References

- **Formula construction:** `R/utils.R` → `get_primary_formula()`
- **Model fitting:** `R/utils.R` → `fit_models()`
- **Model stripping:** `R/utils.R` → `strip_glm()`, `strip_lm()`
- **Prediction:** `R/utils.R` → `predict_risks()`
