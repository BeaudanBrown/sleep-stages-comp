# Statistical Methods Specification

This document provides detailed specifications for the statistical methods used in the compositional sleep analysis, with a focus on causal inference and uncertainty quantification.

## G-computation for Causal Effects

### Overview
G-computation estimates the causal effect of interventions (isotemporal substitutions) by:
1. Fitting a model for the outcome given exposures and confounders
2. Computing predicted outcomes under different exposure scenarios
3. Contrasting predictions to estimate causal effects

### Implementation Details

#### Step 1: Fit Outcome Model
```r
# Fit multivariate normal model for ILR coordinates
ilr_model <- mvn_fit(
  ilr_coords ~ age + sex + bmi + education + apoe4 + tst,
  data = data_imputed
)

# Fit outcome model (example for binary outcome)
outcome_model <- glm(
  dementia_mci ~ ilr_R1 + ilr_R2 + ilr_R3 + age + sex + bmi + education + apoe4 + tst,
  data = data_imputed,
  family = binomial
)
```

#### Step 2: Create Counterfactual Datasets
For each substitution scenario (e.g., 30 minutes N1→N3):
1. Apply substitution to create new composition
2. Transform to ILR coordinates
3. Check density for plausibility
4. Create dataset with intervened compositions

#### Step 3: Predict Under Interventions
```r
# Predict under no intervention
Y0 <- predict(outcome_model, type = "response")

# Predict under intervention
Y1 <- predict(outcome_model, newdata = data_intervened, type = "response")

# Causal risk difference
RD <- mean(Y1) - mean(Y0)

# Causal risk ratio
RR <- mean(Y1) / mean(Y0)
```

## Bootstrap Uncertainty Quantification

### Nested Bootstrap for Imputed Data
Account for both sampling uncertainty and imputation uncertainty:

```r
# Outer loop: Bootstrap samples
bootstrap_results <- map(1:1000, function(b) {
  # Sample with replacement
  boot_indices <- sample(nrow(data), replace = TRUE)
  
  # Inner loop: Imputed datasets
  imp_results <- map(1:m, function(i) {
    data_boot <- complete(imp, i)[boot_indices, ]
    
    # Perform analysis
    perform_substitution_analysis(data_boot)
  })
  
  # Pool across imputations using Rubin's rules
  pool_results(imp_results)
})

# Calculate percentile bootstrap CI
ci_lower <- quantile(bootstrap_results, 0.025)
ci_upper <- quantile(bootstrap_results, 0.975)
```

### Variance Components
Total variance = Within-imputation variance + Between-imputation variance + Bootstrap variance

## Rubin's Rules for Multiple Imputation

### Point Estimate
Average across m imputations:
```r
Q_bar <- mean(Q_1, Q_2, ..., Q_m)
```

### Variance
```r
# Within-imputation variance
U_bar <- mean(U_1, U_2, ..., U_m)

# Between-imputation variance  
B <- var(Q_1, Q_2, ..., Q_m)

# Total variance
T <- U_bar + (1 + 1/m) * B

# Relative increase in variance due to missing data
r <- (1 + 1/m) * B / U_bar

# Fraction of missing information
lambda <- (r + 2/(df + 3)) / (r + 1)
```

### Degrees of Freedom
```r
df_old <- (m - 1) * (1 + 1/r)^2
df_obs <- (n - k) * (1 - lambda)
df <- 1 / (1/df_old + 1/df_obs)
```

## Multivariate Normal Density for Compositions

### Fit Model
```r
# Transform to ILR
ilr_data <- ilr(acomp(comp_data))

# Fit multivariate normal
mu <- colMeans(ilr_data)
Sigma <- cov(ilr_data)
```

### Density Checking
```r
check_density <- function(new_comp, mu, Sigma, threshold = 0.05) {
  # Transform to ILR
  new_ilr <- ilr(acomp(new_comp))
  
  # Mahalanobis distance
  d2 <- mahalanobis(new_ilr, mu, Sigma)
  
  # Chi-squared test
  p_value <- pchisq(d2, df = length(mu), lower.tail = FALSE)
  
  # Plausible if p > threshold
  return(p_value > threshold)
}
```

## Optimal Composition Search

### Grid Search Algorithm
```r
# Create grid over 3-simplex (4-part composition)
grid <- create_simplex_grid(
  step_size = 0.01,  # 1% increments
  constraints = list(
    n1 = c(0.05, 0.30),  # 5-30% of TST
    n2 = c(0.20, 0.60),  # 20-60% of TST
    n3 = c(0.05, 0.30),  # 5-30% of TST
    rem = c(0.10, 0.30)  # 10-30% of TST
  )
)

# Evaluate each composition
results <- map_dfr(grid, function(comp) {
  if (check_density(comp, mu, Sigma)) {
    pred <- predict_outcome(comp, model)
    data.frame(
      n1 = comp[1], n2 = comp[2], 
      n3 = comp[3], rem = comp[4],
      predicted_risk = pred
    )
  }
})

# Find optimal
optimal <- results[which.min(results$predicted_risk), ]
```

## Sensitivity Analyses

### Density Threshold Variation
Test robustness to plausibility threshold:
- Primary: p > 0.05
- Sensitivity: p > 0.01, 0.10, 0.20

### Alternative ILR Bases
Test different sequential binary partitions:
- Primary: (n1|n2,n3,rem), (n2|n3,rem), (n3|rem)
- Alternative 1: (rem|n1,n2,n3), (n3|n1,n2), (n2|n1)
- Alternative 2: Balance-focused partition

### Covariate Adjustment Sets
- Minimal: age, sex
- Main: age, sex, education, BMI, APOE4
- Maximal: Main + comorbidities + medications

## Multiple Comparisons Adjustment

### False Discovery Rate Control
For 48 substitution scenarios across multiple outcomes:
```r
# Benjamini-Hochberg procedure
p_adjusted <- p.adjust(p_values, method = "BH")
q_value <- 0.05  # Control FDR at 5%
significant <- p_adjusted < q_value
```

### Pattern Interpretation
Focus on:
1. Consistent direction of effects across substitutions
2. Dose-response relationships (15, 30, 45, 60 minutes)
3. Biological plausibility of findings