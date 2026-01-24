# Outcome Modeling Comparison: Specs vs Current Implementation

## 1. Current Outcome Handling vs Required

### Dementia/MCI Combined Endpoint
**Specification Requirements:**
- Combined endpoint: First occurrence of either dementia OR MCI
- Track event date (`dementia_mci_date`) and type (`dementia_mci_type`)
- Exclude participants with prevalent dementia or MCI at PSG2
- Handle death as competing risk

**Current Implementation Status:**
✅ **Partially Implemented** in `old/R/prepare_dataset.R`:
- Creates `dem_or_mci_status` combining dementia and MCI events
- Tracks `dem_or_mci_surv_date` for survival time
- Excludes prevalent cases (before PSG2)
- ❌ Missing: Does not track event type (dementia vs MCI first)

### MRI Volume Outcomes
**Specification Requirements:**
- Total Brain Volume (TBV): Gray + white matter
- Regional volumes: Hippocampal, frontal, temporal
- White Matter Hyperintensities (WMH) - log-transformed
- All volumes adjusted for total intracranial volume (TIV)

**Current Implementation Status:**
⚠️ **Minimal Implementation** in `R/make_dataset_from_raw_files.R`:
- Loads `Total_brain`, `FLAIR_wmh`, `DSE_wmh` from raw data
- ❌ Missing: No regional volumes (hippocampal, frontal, temporal)
- ❌ Missing: No TIV adjustment
- ❌ Missing: No log-transformation of WMH

## 2. Stratification Capabilities

**Specification Requirements:**
- By baseline cognitive status
- By age group (<65, 65-75, >75)
- By sex
- By APOE ε4 carrier status

**Current Implementation Status:**
❌ **Not Implemented**: No stratification functions found in the codebase

## 3. Survival Analysis Implementation

**Specification Requirements:**
- Discrete-time survival models
- Time scale: Years since PSG2
- Cause-specific hazards for competing risks
- Cumulative incidence functions

**Current Implementation Status:**
✅ **Well Implemented** in `old/R/utils.R`:
- Uses discrete-time survival via `survSplit()` and pooled logistic regression
- Handles competing risks (death vs dementia/MCI)
- Calculates cumulative incidence correctly
- ⚠️ Time scale appears to be in days, not years

Key functions:
- `fit_models()`: Fits separate GLMs for dementia/MCI and death
- `expand_surv_dt()`: Creates person-period dataset for discrete survival
- `predict_risks()`: Calculates cumulative incidence accounting for competing risks

## 4. Multiple Imputation Combination

**Specification Requirements:**
- Multiple imputation for intermittent missingness
- Sensitivity analysis for dropout
- Complete-case as primary for MRI, imputation as sensitivity

**Current Implementation Status:**
⚠️ **Partially Implemented** in `old/R/prepare_dataset.R`:
- Uses `mice` package for multiple imputation
- Custom truncated normal imputation for sleep variables
- ❌ Missing: No Rubin's rules combination across imputed datasets
- ❌ Missing: No handling of MRI missingness patterns
- ❌ Missing: No sensitivity analyses for dropout

## 5. Key Gaps and Recommendations

### Critical Missing Components:
1. **Event Type Tracking**: Add `dementia_mci_type` variable to distinguish first event
2. **Regional Brain Volumes**: Extract hippocampal, frontal, temporal volumes
3. **TIV Adjustment**: Implement brain volume normalization
4. **Stratified Analysis**: Add functions for subgroup analyses
5. **Multiple Imputation Pooling**: Implement proper MI combination using Rubin's rules
6. **Reporting Functions**: Add STROBE-compliant output generation

### Implementation Priority:
1. **High Priority**: Fix outcome definitions, add regional brain volumes
2. **Medium Priority**: Implement stratification, proper MI pooling
3. **Low Priority**: Reporting functions, sensitivity analyses

### Code Location Recommendations:
- Create `R/outcomes.R` for outcome-specific functions
- Create `R/stratification.R` for subgroup analysis functions
- Create `R/imputation.R` for proper MI handling
- Update `analysis_targets.R` to include new modeling steps