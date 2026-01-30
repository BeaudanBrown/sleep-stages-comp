# Data Specification

## Data Sources

### SHHS (Sleep Heart Health Study)
Polysomnography data from two visits:
- **SHHS-1 (1995-1998):** Baseline PSG
- **SHHS-2 (2001-2003):** Follow-up PSG (exposure measurement)

### Framingham
- **Offspring cohort:** Primary cohort
- **Omni cohort:** Included, distinguished by `IDTYPE` variable

---

## Key Identifiers

| Variable | Description |
|----------|-------------|
| `PID` | Framingham participant ID |
| `IDTYPE` | Cohort indicator (1 = Offspring, 7 = Omni) |
| `pptidr` | SHHS randomization ID |
| `pptidu` | SHHS unique ID |

---

## Exposure Variables (SHHS-2)

All times in **minutes**.

| Variable | Description | Raw Name |
|----------|-------------|----------|
| `n1_s2` | Time in N1 (light sleep) | `timest1_s2` |
| `n2_s2` | Time in N2 (light sleep) | `timest2_s2` |
| `n3_s2` | Time in N3/SWS (slow wave sleep) | `timest34_s2` |
| `rem_s2` | Time in REM | `timerem_s2` |
| `slp_time_s2` | Total sleep time | `slp_time_s2` |
| `waso_s2` | Wake after sleep onset | `waso_s2` |

**Note:** The exposure composition for ILR transformation uses **SHHS-2 N1, N2, N3, REM only** (4 components → 3 ILR coordinates) and excludes wake.

Total sleep time is included as a separate covariate:

```r
total_sleep_time_s2 <- n1_s2 + n2_s2 + n3_s2 + rem_s2
```

---

## Adjustment Variables (SHHS-1)

Used as confounders to adjust for prior sleep patterns.

| Variable | Description | Notes |
|----------|-------------|-------|
| `n1` | Time in N1 at S1 | Raw minutes |
| `n2` | Time in N2 at S1 | Raw minutes |
| `n3` | Time in N3 at S1 | Raw minutes |
| `rem` | Time in REM at S1 | Raw minutes |
| `slp_time` | Total sleep time at S1 | NA indicates battery failure |
| `waso` | WASO at S1 | |
| `oahi` | Apnea-hypopnea index at S1 | |

### S1 Battery Issue Flag
Some SHHS-1 recordings were cut short due to battery failure. These are identified by:
```r
s1_incomplete <- is.na(slp_time)
```
An indicator variable should be included in models to adjust for this.

In addition, SHHS-1 stage minutes affected by battery failure are treated as missing and handled via multiple imputation (see Imputation section).

---

## Confounders (Required; to be added)

The primary analysis will adjust for the **full confounder set** below. Variable names and sources must be confirmed in the relevant Framingham/SHHS data dictionaries.

### Demographics
- Age at S1 (`age_s1`) ✅ Already loaded
- Sex (`gender`) ✅ Already loaded  
- Education (`educat`) ✅ Already loaded
- Race/ethnicity *(TBD: variable name/source)*
- Cohort indicator (`IDTYPE`) ✅ Available

### Health/Anthropometric
- BMI (`bmi_s1`) ✅ Already loaded
- Waist circumference *(TBD: variable name/source)*
- Hypertension status *(TBD: variable name/source)*
- Diabetes status *(TBD: variable name/source)*
- CVD status/event history (also used for exclusion) *(TBD: variable name/source and event-date logic)*

### Lifestyle
- Smoking status *(TBD: variable name/source)*
- Physical activity (PAI) *(TBD: variable name/source)*
- Alcohol use *(TBD: variable name/source)*

### Genetic
- APOE ε4 status *(TBD: variable name/source; to be identified from data dictionary)*

### Medications
- Sedative use *(TBD: variable name/source)*
- Sleeping pill use *(TBD: variable name/source)*
- Antidepressant use *(TBD: variable name/source)*

### For MRI outcomes only
- Intracranial volume (ICV) *(TBD: variable name/source)*

---

## Outcome Variables

### Dementia (Primary)
| Variable | Description |
|----------|-------------|
| `DEM_STATUS` | Dementia status (1 = yes) |
| `DEM_SURVDATE` | Date of dementia or censoring (days from reference) |
| `impairment_date_*` | MCI dates (multiple assessments) |

Derived variables:
- `dem_or_mci_status`: Combined dementia/MCI indicator
- `dem_or_mci_surv_date`: Time to event/censoring (days from SHHS-2)

### Death (Competing Risk)
| Variable | Description |
|----------|-------------|
| `death_status` | Derived from `fram_death_status` or `shhs_alive_status` |
| `death_date` | Date of death (days from SHHS-2) |

### MRI (Secondary)
| Variable | Description |
|----------|-------------|
| `Total_brain_*` | Total brain volume |
| `Cerebrum_gray_*` | Grey matter volume |
| `Cerebrum_white_*` | White matter volume |
| `Hippo_*` | Hippocampal volume |
| `FLAIR_wmh_*` / `DSE_wmh_*` | White matter hyperintensities |
| `mri_date_*` | Date of MRI assessment |

**Note:** `_*` suffix indicates multiple assessments (1, 2, 3...). Use the first assessment post-SHHS-2.

---

## Exclusion Criteria

Apply in this order:

1. **Missing SHHS-2 PSG exposure:** Exclude if any of `n1_s2, n2_s2, n3_s2, rem_s2` are missing.
2. **Missing SHHS-1 PSG stage minutes:** Do **not** exclude solely for missingness caused by SHHS-1 battery failure; instead, set affected stage minutes to missing and impute (see Imputation). Exclude only if SHHS-1 stage minutes are missing for other reasons that prevent analysis *(TBD: operational rule once missingness patterns are confirmed)*.

   **Operational rule:**
   - If `slp_time` is `NA` (battery failure), set `n1`, `n2`, `n3`, `rem` to missing for imputation.
   - Otherwise, exclude participants with missing `n1`/`n2`/`n3`/`rem`.
3. **Pre-existing dementia/MCI:** Exclude if `dem_or_mci_surv_date <= 0` (event before SHHS-2).
4. **Pre-existing CVD:** Exclude if **any CVD event** occurred before SHHS-2 *(TBD: define event types and variable(s) once identified)*.

---

## Date Handling

All dates are converted to **days relative to SHHS-2** for analysis:

```r
# Framingham dates (originally days from Framingham enrollment)
fram_date_relative <- fram_date - days_to_psg2

# SHHS dates (originally days from SHHS-1)
shhs_date_relative <- shhs_date - days_psg1_to_psg2
```

Where:
- `days_to_psg1`: Days from Framingham enrollment to SHHS-1
- `days_psg1_to_psg2`: Days from SHHS-1 to SHHS-2
- `days_to_psg2 = days_to_psg1 + days_psg1_to_psg2`

---

## Data Quality Notes

1. **SHHS-1 battery failures:** Some S1 recordings incomplete; identified by `is.na(slp_time)`. Include indicator in models.

2. **Multiple MRI assessments:** Select first post-SHHS-2; adjust for time-since-exposure.

3. **Omni cohort:** Smaller sample, potentially different characteristics. Include `IDTYPE` as covariate.

---

## Imputation

### Goal
Handle missingness in **SHHS-1 sleep-stage minutes** due to battery failure while preserving uncertainty in downstream causal contrasts.

### Approach
Use **multiple imputation** via `{mice}` with **m = 10** imputations, then pool model parameters using **Rubin's Rules**.

### Variables to impute
Primary targets for imputation:
- `n1`, `n2`, `n3`, `rem` (SHHS-1 stage minutes) when missing due to `s1_incomplete`.

Potential additional imputation targets (if missingness is non-trivial):
- Confounders in the required set (demographics, health, lifestyle, medications) *(TBD once variable availability/missingness is confirmed)*.

### Predictors in the imputation model
Include:
- Exposure composition variables (`n1_s2`, `n2_s2`, `n3_s2`, `rem_s2`) and `total_sleep_time_s2`
- Outcome indicators/timing as appropriate (e.g., `dem_or_mci_status`, `dem_or_mci_surv_date`) to preserve associations
- Core confounders (age, sex, BMI, education, etc.)
- Auxiliary variables that improve missingness prediction without introducing post-exposure bias *(TBD)

### Constraints / bounds
Impute stage minutes using a method that respects plausible bounds (e.g., truncated normal). Minimum constraints:
- Imputed stage minutes must be non-negative.
- If using raw stage minutes from incomplete recordings as lower bounds, enforce imputed values ≥ recorded minutes.

### Pooling
For each analysis component (dementia model, death model, MRI model), fit the model in each imputed dataset and pool coefficients and variance using Rubin's Rules (for coefficient tables and diagnostics).

For primary **g-computation contrasts** (risk differences/ratios for substitutions and ideal-composition predictions), we will:
- compute the contrast within each imputed dataset
- average the contrast across the `m` imputations to obtain the point estimate

Uncertainty for these contrasts will be obtained via the **participant bootstrap** that repeats the full procedure (resampling → imputation → model fitting → prediction), so we do not rely on closed-form Rubin pooling for non-linear estimands.
