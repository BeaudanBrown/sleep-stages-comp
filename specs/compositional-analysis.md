# Compositional Analysis Specification

## Overview
This specification defines the compositional data analysis approach for sleep stages, focusing on isotemporal substitution to understand the effects of reallocating time between sleep stages on health outcomes.

## Compositional Framework

### Fundamental Constraint
Sleep stages form a 4-part composition (wake time excluded):
```
n1 + n2 + n3 + rem = Total Sleep Time
```
Total sleep time (TST) is included as a covariate in models.

### Why Compositional Analysis?
- Traditional regression treats sleep stages as independent
- In reality, increasing one stage requires decreasing another
- Effects depend on BOTH what increases AND what decreases
- Standard methods produce biased estimates

## Isotemporal Substitution Method

### Definition
Isotemporal substitution models the effect of replacing time in one activity with time in another while holding total time constant.

### Implementation Steps

1. **Transform to ILR Space**
   - Apply isometric log-ratio transformation to map from simplex to R^3
   - Preserves compositional geometry and distances
   - Enables standard statistical methods

2. **Fit Conditional Distribution**
   - Model joint distribution of ILR coordinates given covariates
   - Multivariate normal with covariate-dependent mean and covariance
   - Used for density checking of substitutions

3. **Define Substitutions**
   - Specify source activity (e.g., n1, n2, rem)
   - Specify target activity (e.g., n3 for slow wave sleep)
   - Specify time amounts (15, 30, 45, 60 minutes)

4. **Apply Substitutions**
   - Only to participants where resulting composition is plausible
   - Check using multivariate normal density threshold
   - Apply substitution if density is above threshold

5. **Estimate Effects**
   - G-computation for causal effect estimation
   - Compare expected outcomes under substitution vs. no intervention
   - Report as risk differences/ratios or mean differences

### Example Substitutions
- **Primary interest**: Increasing N3 (slow wave sleep)
  - N3 ← N1 (deep sleep replaces light sleep)
  - N3 ← N2 (deep sleep replaces stage 2)
  - N3 ← REM (deep sleep replaces REM)

- **All pairwise substitutions**: 
  - Every stage to every other stage
  - Time increments: 15, 30, 45, 60 minutes
  - Total of 12 direction pairs × 4 time amounts = 48 scenarios

## Density Checking Algorithm

### Purpose
Ensure substitutions create realistic sleep patterns, not impossible compositions.

### Method
1. Calculate multivariate normal density of proposed composition in ILR space
2. Set minimum density threshold for plausibility
3. Only apply substitution if density > threshold
4. Track number of participants included for each substitution

### Interpretation
- Prevents modeling impossible scenarios (e.g., 0 minutes N1)
- Maintains clinical plausibility
- Reduces extrapolation bias

## Optimal Composition Search

### Objective
Find the sleep stage distribution associated with best health outcomes.

### Constraints
- Each component ≥ 0
- Within plausible density region
- Fixed total sleep time

### Method
**Exhaustive Grid Search**
- Generate fine grid over composition space
- Evaluate all plausible compositions
- No optimization needed - compute all
- Compare best, worst, and average compositions

### Outputs
- Optimal time in each stage
- Confidence/credible regions
- Comparison to population average

## Statistical Considerations

### Multiple Comparisons
- Many substitution scenarios tested
- Consider false discovery rate control
- Focus on patterns, not individual tests

### Uncertainty Quantification  
- Bootstrap for confidence intervals
- Propagate imputation uncertainty
- Report prediction intervals

### Sensitivity Analyses
- Vary density threshold
- Different ILR pivot coordinates
- Alternative covariate adjustment sets

## Expected Outputs

### Effect Estimates
For each substitution:
- Point estimate of effect
- 95% confidence interval
- Number of participants included
- Interpretation in natural units

### Visualization
- Heatmaps of substitution effects
- Ternary diagrams for 3-component subcompositions
- Time series showing cumulative risk
- Optimal composition radar plots

### Tables
- Main effects for primary substitutions
- Stratified analyses (age, sex, baseline health)
- Sensitivity analysis results
- Optimal compositions by outcome