# Data Structure Specification

## Overview
This document defines the key variables and data structures used in the compositional sleep stage analysis. All time variables are in minutes unless otherwise specified.

## Sleep Stage Variables

### Primary Composition Components (4-part sleep composition)
- `n1`: Time in NREM Stage 1 (light sleep)
- `n2`: Time in NREM Stage 2 
- `n3`: Time in NREM Stage 3 (slow wave sleep/deep sleep)
- `rem`: Time in REM sleep

### Additional Variables
- `tst`: Total sleep time (n1 + n2 + n3 + rem) - used as covariate
- `wake`: Time awake - NOT part of composition, recorded separately

### PSG Measurement Timepoints
- **PSG1 variables**: Baseline measurements (suffix: none)
  - `n1`, `n2`, `n3`, `rem`, `wake`
- **PSG2 variables**: Follow-up measurements (suffix: `_s2`)
  - `n1_s2`, `n2_s2`, `n3_s2`, `rem_s2`, `wake_s2`

### Derived Sleep Variables
- `slp_time`: Total sleep time (n1 + n2 + n3 + rem)
- `waso`: Wake after sleep onset
- `slp_lat`: Sleep latency (time to fall asleep)
- `rem_lat1`: REM latency (time to first REM period)
- `ahi`: Apnea-hypopnea index

## Compositional Transformations

### ILR Coordinates
The 4-part sleep composition is transformed to 3 ILR (isometric log-ratio) coordinates:
- `R1`, `R2`, `R3`: ILR-transformed sleep composition

### Sequential Binary Partition (SBP)
The ILR transformation uses a specific contrast matrix that preserves:
1. Orthogonality
2. Unit length
3. Compositional geometry

## Outcome Variables

### Cognitive Outcomes
- `dementia_date`: Date of dementia diagnosis
- `mci_date`: Date of mild cognitive impairment diagnosis
- `dementia_mci_date`: Date of first dementia or MCI (whichever comes first)
- `dementia_mci_type`: Type of first event (dementia/MCI)

### Brain MRI Volumes (adjusted for intracranial volume)
- `brain_vol`: Total brain volume
- `gm_vol`: Gray matter volume  
- `wm_vol`: White matter volume
- `hippo_vol`: Hippocampal volume
- `wmh_vol`: White matter hyperintensity volume

### Survival Variables
- `death_date`: Date of death
- `death_cause`: Cause of death
- `followup_days`: Days from PSG2 to event/censoring

## Covariate Structure

### Demographics
- `age`: Age at PSG2
- `sex`: Biological sex (0=Female, 1=Male)
- `race`: Self-reported race/ethnicity
- `education`: Years of education

### Health Variables
- `bmi`: Body mass index
- `hypertension`: Hypertension status
- `diabetes`: Diabetes status  
- `cvd`: Cardiovascular disease history
- `apoe4`: APOE ε4 carrier status (0/1/2 alleles)

### Medications
- `sleep_med`: Sleep medication use
- `sedative`: Sedative use
- `antidepressant`: Antidepressant use

## Data Quality Indicators
- `*_mis`: Missing indicator for any variable (1=missing, 0=observed)
- `truncated`: Sleep recording truncated (1=yes, 0=no)
- `valid_comp`: Composition passes density check (1=valid, 0=invalid)

## Expected Data Dimensions
- Participants: ~500-1000 (after exclusions)
- Imputed datasets: 10-20
- Substitution scenarios: ~100-500 (depending on granularity)
- Follow-up period: Up to 20 years