# Outcomes Specification

## Overview

| Outcome | Type | Priority | Model Type |
|---------|------|----------|------------|
| Incident dementia | Time-to-event | Primary | Pooled logistic regression |
| MRI volumetrics | Continuous | Secondary | Linear regression |

---

## Dementia Outcome (Primary)

### Definition
Primary endpoint is **incident dementia OR mild cognitive impairment (MCI)** occurring **after SHHS-2**.

### Variables Used
- `DEM_STATUS`: Dementia indicator (1 = dementia)
- `DEM_SURVDATE`: Date of dementia diagnosis or censoring
- `impairment_date_1`, `impairment_date_2`, `impairment_date_3`: MCI diagnosis dates

### Derived Outcome
```r
# Combined dementia/MCI status
dem_or_mci_status <- fifelse(
  DEM_STATUS == 1 | !is.na(impairment_date_1) | !is.na(impairment_date_2) | !is.na(impairment_date_3),
  1, 0
)

# Time to event (days from SHHS-2)
dem_or_mci_surv_date <- pmin(impairment_date_1, impairment_date_2, impairment_date_3, DEM_SURVDATE, na.rm = TRUE)
```

### Censoring
Participants are censored at:
- Death (competing risk - see below)
- Administrative end of follow-up
- Loss to follow-up

### Death as Competing Risk
Death precludes dementia diagnosis. We model both:
- `dem_or_mci`: Event indicator for dementia/MCI
- `death`: Event indicator for death

The **cause-specific hazard** approach is used (model dementia among those who haven't died), combined with an explicit death model for g-computation.

### Time Scale
- **Unit:** Days from SHHS-2
- **Discretization:** Annual intervals for pooled logistic regression
- **`timegroup`:** Integer indicating the year of follow-up (0, 1, 2, ...)

---

## MRI Outcomes (Secondary)

### Variables

| Outcome | Variable Pattern | Description |
|---------|------------------|-------------|
| Total brain volume | `Total_brain_*` | Overall brain size |
| Grey matter volume | `Cerebrum_gray_*` | Cortical/subcortical grey matter |
| White matter volume | `Cerebrum_white_*` | White matter |
| Hippocampal volume | `Hippo_*` | Bilateral hippocampus |
| White matter hyperintensities | `FLAIR_wmh_*` or `DSE_wmh_*` | Marker of small vessel disease |

**Note:** `*` indicates assessment number. Multiple MRI assessments may exist per participant.

### Which Assessment to Use

Use the **first MRI assessment occurring after SHHS-2**:

```r
# Identify first post-SHHS-2 MRI
# mri_date_* variables are days relative to SHHS-2
# Select the earliest positive mri_date

mri_cols <- grep("^mri_date_", names(dt), value = TRUE)
# For each participant, find min(mri_date_*) where mri_date_* > 0
```

### Time Adjustment

Since MRI timing varies across participants, include **time from SHHS-2 to MRI** as a covariate:

```r
time_to_mri <- mri_date_selected  # Days from SHHS-2 to MRI
```

This accounts for:
- Different follow-up durations
- Potential changes in brain structure over time

### Intracranial Volume (ICV) Adjustment

For volumetric outcomes (all except WMH), adjust for intracranial volume (ICV) to account for head size differences.

ICV variable name/source is **TBD** (must be confirmed from the MRI dataset/dictionary).

Implementation:
- Primary: include ICV as a covariate in the linear model.
- Sensitivity (optional): use ICV-normalized volumes.

### Model Type

Linear regression (not survival analysis):
- Outcome is continuous MRI measurement
- Single timepoint per participant (cross-sectional)
- No competing risk of death (MRI measured while alive)

### WMH transformation
WMH measures are typically right-skewed. Primary analysis will use:

```r
wmh_transformed <- log1p(wmh)
```

Sensitivity (optional): untransformed WMH.

### MRI timing relative to dementia/MCI
Primary analysis will:
- include **all** first-post-SHHS-2 MRIs
- adjust for `time_to_mri`
- create and report an indicator `mri_after_dem_mci` (MRI occurred after dementia/MCI diagnosis date), and include it as a covariate in MRI models.

Definition:
```r
mri_after_dem_mci <- as.integer(
  dem_or_mci_status == 1 &
    !is.na(dem_or_mci_surv_date) &
    time_to_mri >= dem_or_mci_surv_date
)
```

Sensitivity (optional): restrict to MRIs occurring before dementia/MCI diagnosis.

---

## Sensitivity Analyses (To Be Specified)

Sensitivity analyses will be finalized and pre-specified later. Candidate sensitivities include:
1. Dementia only (excluding MCI)
2. Different follow-up windows (e.g., first 5 or 10 years)
3. MRI restricted to pre-dementia/MCI scans

---

## Code References

- **Outcome derivation:** `R/prepare_dataset.R`
- **Survival data expansion:** `R/utils.R` → `expand_surv_dt()`
- **Model fitting:** `R/utils.R` → `fit_models()`
