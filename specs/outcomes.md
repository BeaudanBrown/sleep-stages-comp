# Outcomes Specification

## Overview
This specification defines the health outcomes analyzed in the compositional sleep study and their operational definitions.

## Primary Outcomes

### Incident Dementia or MCI (Combined Endpoint)
- **Definition**: First occurrence of either dementia OR mild cognitive impairment
- **Sources**: 
  - Clinical consensus panel review
  - Medical records
  - Neuropsychological testing
- **Variable**: `dementia_mci_date` - date of first event
- **Type**: `dementia_mci_type` - indicates whether dementia or MCI occurred first
- **Exclusions**: Participants with prevalent dementia or MCI at PSG2
- **Competing risk**: Death before dementia/MCI

## Secondary Outcomes

### Brain MRI Volumes
All volumes adjusted for total intracranial volume (TIV):

- **Total Brain Volume (TBV)**
  - Gray matter + white matter
  - Excludes CSF and lesions
  
- **Regional Volumes**:
  - Hippocampal volume (dementia-relevant)
  - Frontal lobe volume
  - Temporal lobe volume
  
- **White Matter Hyperintensities (WMH)**
  - Total volume of T2/FLAIR hyperintense lesions
  - Log-transformed due to skewed distribution



### All-Cause Mortality
- **Sources**: National Death Index, state records
- **Verification**: Death certificates
- **Cause-specific**: Cardiovascular, cancer, dementia-related

## Outcome Modeling Approaches

### Time-to-Event Outcomes
- **Model**: Discrete-time survival models
- **Time scale**: Years since PSG2
- **Handling competing risks**: 
  - Cause-specific hazards
  - Cumulative incidence functions

### Continuous Outcomes
- **Model**: Linear mixed models for repeated measures
- **Random effects**: Subject-specific intercepts and slopes
- **Time-varying**: Account for cognitive trajectories

### Considerations for Compositional Analysis
- **Non-linearity**: Use restricted cubic splines for ILR coordinates
- **Interactions**: Test ILR × time interactions
- **Multiple outcomes**: Consider composite outcomes

## Missing Data Patterns

### Cognitive Assessments
- **Monotone missingness**: Due to death, dropout
- **Intermittent missingness**: Missed visits
- **Handling**: 
  - Multiple imputation for intermittent
  - Sensitivity analysis for dropout

### MRI Outcomes
- **Availability**: Subset of participants
- **Quality issues**: Motion artifacts, incomplete scans
- **Handling**: Complete-case as primary, imputation as sensitivity

## Effect Measures

### Binary Outcomes
- **Risk Difference**: Absolute effect per substitution
- **Risk Ratio**: Relative effect
- **Number Needed to Treat**: For clinically meaningful changes

### Continuous Outcomes  
- **Mean Difference**: Change in outcome units
- **Standardized Effect Size**: Cohen's d
- **Clinically Important Difference**: Predefined thresholds

## Reporting Standards

### STROBE Guidelines
- Report participant flow
- Describe missing data
- Present unadjusted and adjusted results

### Compositional-Specific Reporting
- Describe reference composition
- State substitution magnitude
- Report density threshold used
- Number excluded due to implausible compositions

## Sensitivity Analyses

### Outcome Definition
- Vary dementia criteria stringency
- Alternative cognitive decline thresholds
- Include/exclude questionable cases

### Follow-up Period  
- 5-year, 10-year, maximum follow-up
- Early vs. late effects
- Time-varying effects

### Subgroup Analyses
- By baseline cognitive status
- By age group (<65, 65-75, >75)
- By sex
- By APOE ε4 carrier status