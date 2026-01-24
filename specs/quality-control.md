# Quality Control Specification

## Overview
This specification defines quality control procedures to ensure valid compositional analyses and reliable results throughout the sleep stage analysis pipeline.

## Data Quality Checks

### Sleep Composition Validation
1. **Sum Constraint**
   - Verify: wake + n1 + n2 + n3 + rem = 1440 ± 1 minute
   - Action: Flag violations for investigation
   - Tolerance: 1 minute for rounding errors

2. **Non-Negativity**
   - Verify: All components ≥ 0
   - Common issues: Negative values from data entry errors
   - Action: Set to 0 if small negative (<-5), otherwise investigate

3. **Biological Plausibility**
   - Minimum sleep time: ≥ 180 minutes (3 hours)
   - Maximum wake time: ≤ 1200 minutes (20 hours)
   - REM typically 10-25% of total sleep time
   - N3 typically decreases with age

### Missing Data Patterns
1. **Systematic Missingness**
   - Check for patterns by site, technician, date
   - Verify missing completely at random (MCAR) assumption
   - Document reasons for missing data

2. **Partial Recordings**
   - Identify truncated sleep studies
   - Minimum recording duration: 4 hours
   - Flag early terminations

## Statistical Quality Control

### Imputation Diagnostics
1. **Convergence Monitoring**
   ```r
   # Check trace plots
   plot(imp, y = c("n1_s2", "n2_s2", "n3_s2", "rem_s2"))
   
   # Verify convergence statistics
   mids_convergence <- imp$chainMean
   max_change <- max(abs(diff(mids_convergence)))
   converged <- max_change < 0.05
   ```

2. **Imputed Value Ranges**
   - Verify imputed values within observed ranges
   - Check compositional constraints maintained
   - Compare imputed vs. observed distributions

3. **Sensitivity to Imputation Model**
   - Vary number of imputations (m = 10, 20, 50)
   - Different imputation methods
   - Include/exclude auxiliary variables

### Compositional Transformation Checks
1. **ILR Transformation Validity**
   - Verify orthogonality of contrast matrix
   - Check reversibility (ILR → composition → ILR)
   - Numerical precision (expect <1e-10 error)

2. **Density Threshold Calibration**
   - Plot Mahalanobis distances
   - Verify approximately chi-squared distribution
   - Document percentage excluded at each threshold

### Model Diagnostics
1. **Regression Diagnostics**
   - Residual plots for continuous outcomes
   - Calibration plots for survival models
   - Influential observations via Cook's distance

2. **Multicollinearity**
   - VIF for ILR coordinates and covariates
   - Condition number of design matrix
   - Consider regularization if needed

## Reproducibility Checks

### Computational Reproducibility
1. **Seed Management**
   ```r
   # Set seed for each target
   withr::with_seed(12345, {
     # Reproducible computation
   })
   ```

2. **Software Versions**
   - Document R version and all package versions
   - Use renv for package management
   - Test on multiple platforms

3. **Numerical Stability**
   - Check for platform-specific differences
   - Use stable algorithms (QR vs. normal equations)
   - Set tolerance for floating-point comparisons

### Results Validation
1. **Bootstrap Stability**
   - Coefficient of variation across bootstrap samples
   - Flag unstable estimates (CV > 0.5)
   - Minimum 1000 bootstrap iterations

2. **Cross-Validation**
   - Compare in-sample vs. out-of-sample performance
   - Check for overfitting indicators
   - Stability across folds

## Output Quality Control

### Table Validation
1. **Numerical Checks**
   - Verify all percentages sum to 100
   - Check confidence intervals contain point estimates
   - Ensure proper rounding and significant figures

2. **Logical Checks**
   - Substitution effects have correct direction
   - Stratified results consistent with overall
- No duplicate or missing scenarios

### Figure Standards
1. **Visual Inspection**
   - Color-blind friendly palettes
   - Adequate resolution (300+ DPI)
   - Clear axis labels and legends

2. **Data-Ink Ratio**
   - Remove unnecessary gridlines
   - Optimize plot dimensions
   - Consistent style across figures

## Automated Quality Reports

### Pipeline Status Report
```r
# Generate after each run
tar_visnetwork()  # Visual pipeline status
tar_progress()    # Completion statistics
tar_validate()    # Check target definitions
```

### Data Quality Dashboard
- Number of participants at each stage
- Percentage missing by variable
- Distribution plots of key variables
- Outlier identification

### Results Summary
- Table of all substitution effects
- Flag non-converged models
- List sensitivity analysis variations
- Highlight unexpected findings

## Quality Control Thresholds

### Minimum Sample Sizes
- Per substitution scenario: n ≥ 30
- Per outcome event: ≥ 10 events per ILR coordinate
- Per stratum: n ≥ 50

### Convergence Criteria
- Imputation: R-hat < 1.05
- Optimization: Gradient norm < 1e-6
- Bootstrap: SE stabilized (change < 5%)

### Exclusion Documentation
Track reasons for exclusion at each stage:
1. Initial sample
2. Post-QC sleep data
3. Complete case for covariates
4. Plausible compositions only
5. Final analytic sample

## Error Handling

### Graceful Failures
- Implement tryCatch for non-critical errors
- Log warnings and errors to file
- Continue pipeline when possible

### Critical Errors
- Stop on data corruption
- Alert on constraint violations
- Require manual review for outliers
