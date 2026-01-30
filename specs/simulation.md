# Simulation Specification

## Overview

This module provides **simulated data** for two purposes:

1. **Privacy-safe development:** AI agents and collaborators can query, manipulate, and explore data without confidentiality concerns
2. **Pipeline validation:** Bake in known causal effects and verify that the analysis pipeline recovers them

Simulated data integrates with the `{targets}` pipeline via **parameterized mapping** over simulation specifications, allowing multiple scenarios to run in parallel.

---

## Design Principles

### Why Custom Simulation (Not Full Synthetic)?

Full synthetic data methods (e.g., `{synthpop}`) replicate the *observed* data structure but cannot embed **known causal effects**. For validation, we need to:

1. Specify the **true data-generating process (DGP)** including exact effect sizes
2. Run the analysis pipeline on simulated data
3. Compare estimated effects to the known truth

This is only possible with custom simulation where we control the causal model.

### Correlation-Preserving with Configurable Causal Effects

The simulation:
- Generates **realistic marginal distributions** for all variables
- Preserves **plausible correlations** between confounders and sleep stages
- Generates outcomes from a **known causal model** with user-specified true effects

---

## Simulation Specification (`sim_spec`)

A simulation specification is an **R list** that defines all parameters of the data-generating process.

### Creating a Specification

```r
# Use the helper function with sensible defaults
spec <- make_sim_spec(

  n = 1500,

  seed = 42,
  effect_R2_dem = -0.3  # Override: N3/REM ratio protective for dementia
)

# Or define manually
spec <- list(
  # Sample size and reproducibility
  n = 1500,
  seed = 42,
  

  # True causal effects for dementia (log-odds scale)
  effect_R1_dem = 0,       # Restorative/light ratio effect
  effect_R2_dem = -0.3,    # N3/REM ratio effect (negative = N3 protective)
  effect_R3_dem = 0,       # N1/N2 ratio effect
  effect_age_dem = 0.08,   # Age effect per year
  effect_tst_dem = 0,      # Total sleep time effect
  
  # Effect modification

  effect_interaction_age_R2 = 0,  # Age modifies R2 effect
  
  # Baseline hazards (annual probability scale)
  baseline_hazard_dem = 0.005,   # ~0.5% annual dementia risk
  baseline_hazard_death = 0.02,  # ~2% annual mortality
  
  # Death model effects
  effect_age_death = 0.1,
  effect_bmi_death = 0.02,
  
  # MRI outcome effects (if applicable)
  effect_R2_brain_volume = 0.5,  # SD units per ILR unit
  
  # Distribution parameters (see sections below)
  ...
)
```

### Key Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `n` | integer | 1500 | Sample size |
| `seed` | integer | 42 | Random seed for reproducibility |
| `effect_R1_dem` | numeric | 0 | True effect of R1 (restorative/light) on dementia log-odds |
| `effect_R2_dem` | numeric | 0 | True effect of R2 (N3/REM) on dementia log-odds |
| `effect_R3_dem` | numeric | 0 | True effect of R3 (N1/N2) on dementia log-odds |
| `effect_age_dem` | numeric | 0.08 | True effect of age (per year) on dementia log-odds |
| `effect_interaction_age_R2` | numeric | 0 | Age × R2 interaction coefficient |
| `baseline_hazard_dem` | numeric | 0.005 | Annual baseline dementia hazard |
| `baseline_hazard_death` | numeric | 0.02 | Annual baseline death hazard |
| `max_followup_years` | integer | 20 | Maximum follow-up duration |

---

## Data-Generating Process (DGP)

### Step 1: Baseline Demographics

Generate correlated demographic variables:

| Variable | Distribution | Parameters | Correlations |
|----------|-------------|------------|--------------|
| `age_s1` | Truncated Normal | μ=65, σ=10, range [40, 90] | — |
| `gender` | Bernoulli | p=0.5 | — |
| `bmi_s1` | Normal | μ=28, σ=5 | r=0.1 with age |
| `IDTYPE` | Bernoulli | p=0.9 (Offspring) | — |
| `educat` | Ordinal (1-5) | Age-cohort dependent | r=-0.2 with age |

Additional confounders (once TBD variables are finalized in `specs/data.md`):
- Smoking status
- Hypertension
- Diabetes
- APOE ε4 status

### Step 2: SHHS-1 Sleep Stages

Sleep stage proportions are generated from a **Dirichlet distribution** (natural for compositional data):

```r
# Concentration parameters determine expected proportions and variability
alpha_s1 <- c(n1 = 5, n2 = 30, n3 = 10, rem = 12)

# Expected proportions: α / sum(α) ≈ (0.09, 0.53, 0.18, 0.21)
# Higher α values → less variability

# Generate proportions
props_s1 <- rdirichlet(n, alpha_s1)

# Total sleep time
total_sleep_s1 <- rnorm(n, mean = 400, sd = 60)  # ~6.7 hours

# Stage minutes
n1_s1 <- props_s1[, 1] * total_sleep_s1
n2_s1 <- props_s1[, 2] * total_sleep_s1
n3_s1 <- props_s1[, 3] * total_sleep_s1
rem_s1 <- props_s1[, 4] * total_sleep_s1
```

**Age effect on composition:** Older participants have:
- Less N3 (slow wave sleep declines with age)
- More N1 (lighter sleep)
- Slightly less REM

This is implemented by adjusting the Dirichlet concentration parameters as a function of age.

### Step 3: SHHS-2 Sleep Stages

SHHS-2 composition is generated with:

1. **Autocorrelation with SHHS-1:** Individual sleep patterns persist
2. **Aging effect:** Additional years between S1 and S2 (typically ~5 years)
3. **Independent variation:** Within-person variability

```r
# Years between assessments
years_s1_to_s2 <- rnorm(n, mean = 5, sd = 1)

# Autocorrelation: S2 proportions regress toward S1 proportions
# Plus age-related shift
props_s2 <- autocorrelate_composition(props_s1, rho = 0.6) + 
            age_effect(age_s1 + years_s1_to_s2)
```

### Step 4: ILR Transformation

After generating stage minutes, transform to ILR coordinates using the same SBP as the real analysis:

```r
# Component order: (N1, N2, N3, REM)
# SBP: {N3,REM} vs {N1,N2}, then N3 vs REM, then N1 vs N2
comp <- acomp(cbind(n1_s2, n2_s2, n3_s2, rem_s2))
ilr_coords <- ilr(comp, V = v)  # R1, R2, R3
```

### Step 5: Dementia Outcome

Generate dementia events from a **discrete-time hazard model** with known true effects:

```r
# For each time period t (annual):
logit(h_dem[i, t]) = 
  log(baseline_hazard_dem) +           # Baseline
  effect_R1_dem * R1[i] +              # ILR effects (TRUE CAUSAL EFFECTS)
  effect_R2_dem * R2[i] + 
  effect_R3_dem * R3[i] +
  effect_age_dem * age_s2[i] +         # Age effect
  effect_interaction_age_R2 * age_s2[i] * R2[i] +  # Interaction
  effect_tst_dem * total_sleep_s2[i] + # TST effect
  confounder_effects                   # Other confounders
  
# Generate event
dem_event[i, t] ~ Bernoulli(h_dem[i, t])
```

Events are generated sequentially, stopping when:
- Dementia occurs
- Death occurs (competing risk)
- End of follow-up

### Step 6: Death Outcome (Competing Risk)

```r
logit(h_death[i, t]) = 
  log(baseline_hazard_death) +
  effect_age_death * age[i, t] +
  effect_bmi_death * bmi[i] +
  ...
  
death_event[i, t] ~ Bernoulli(h_death[i, t])
```

### Step 7: MRI Outcomes (Optional)

For participants who survive to MRI assessment:

```r
# Time to MRI (years after SHHS-2)
time_to_mri <- runif(n_survivors, min = 2, max = 10)

# Brain volume outcome
brain_volume[i] = 
  intercept +
  effect_R2_brain_volume * R2[i] +
  effect_age_mri * (age_s2[i] + time_to_mri[i]) +
  effect_icv * icv[i] +
  rnorm(1, 0, residual_sd)
```

---

## Simulating Missingness (Optional)

To test the imputation pipeline, simulate the SHHS-1 battery failure pattern:

```r
# ~10% of S1 recordings affected by battery failure
battery_failure <- rbinom(n, 1, prob = 0.10)

# Set S1 stage minutes to NA for affected recordings
# But keep partial recordings (lower bound for imputation)
n1_s1_partial <- ifelse(battery_failure, n1_s1 * runif(n, 0.5, 0.9), n1_s1)
n1_s1 <- ifelse(battery_failure, NA, n1_s1)
slp_time_s1 <- ifelse(battery_failure, NA, slp_time_s1)
s1_incomplete <- battery_failure
```

This allows testing that:
1. Imputation runs correctly
2. Analysis results are robust to imputed values

---

## Predefined Scenarios

### Scenario 1: Null Effects (`null_effect`)
All sleep composition effects are zero. The pipeline should find no significant associations.

```r
make_sim_spec(
  name = "null_effect",
  effect_R1_dem = 0,
  effect_R2_dem = 0,
  effect_R3_dem = 0
)
```

**Validation:** Isotemporal substitution risk differences should be ~0 (within CI).

### Scenario 2: Protective N3 (`protective_n3`)
Slow wave sleep (N3) is protective against dementia.

```r
make_sim_spec(
  name = "protective_n3",
  effect_R2_dem = -0.3  # Higher N3/REM ratio → lower dementia risk
)
```

**Validation:** +15 min N3 (from REM) should show negative risk difference.

### Scenario 3: Age-Modified Effect (`age_interaction`)
N3 protective effect is stronger in younger participants.

```r
make_sim_spec(
  name = "age_interaction",
  effect_R2_dem = -0.4,
  effect_interaction_age_R2 = 0.005  # Effect attenuates with age
)
```

**Validation:** Subgroup analysis by age should show differential effects.

### Scenario 4: U-Shaped REM (`nonlinear_rem`)
Both too little and too much REM are harmful.

```r
make_sim_spec(
  name = "nonlinear_rem",
  effect_R2_dem = 0,
  effect_R2_squared_dem = 0.1  # Quadratic term
)
```

**Validation:** Requires checking predicted risk curve shape.

---

## Pipeline Integration

### Targets Structure

```r
# simulation_targets.R

simulation_targets <- list(
  # 1. Define simulation specifications
  tar_target(
    sim_specs,
    list(
      null_effect = make_sim_spec(name = "null_effect"),
      protective_n3 = make_sim_spec(name = "protective_n3", effect_R2_dem = -0.3),
      age_interaction = make_sim_spec(
        name = "age_interaction",
        effect_R2_dem = -0.4,
        effect_interaction_age_R2 = 0.005
      )
    )
  ),
  
  # 2. Generate simulated datasets (mapped over specs)
  tar_target(
    sim_dt_raw,
    simulate_dataset(sim_specs),
    pattern = map(sim_specs)
  ),
  
  # 3. Prepare simulated data (same as real data)
  tar_target(
    sim_dt,
    prepare_simulated_dataset(sim_dt_raw),
    pattern = map(sim_dt_raw)
  ),
  
  # 4. Run analysis on simulated data
  tar_target(sim_timegroup_cuts, make_cuts(sim_dt), pattern = map(sim_dt)),
  tar_target(sim_density_model, fit_density_model(sim_dt), pattern = map(sim_dt)),
  tar_target(sim_fitted_models, fit_models(sim_dt, sim_timegroup_cuts), pattern = map(sim_dt, sim_timegroup_cuts)),
  tar_target(sim_comp_limits, make_comp_limits(sim_dt), pattern = map(sim_dt)),
  tar_target(sim_baseline_risk, predict_risks(sim_dt, sim_fitted_models, sim_timegroup_cuts), pattern = map(sim_dt, sim_fitted_models, sim_timegroup_cuts)),
  
  # 5. Isotemporal substitutions on simulated data
  tar_target(
    sim_isotemporal_results,
    perform_isotemporal_substitution(
      sim_dt, sim_fitted_models, sim_density_model,
      sim_timegroup_cuts, sim_comp_limits,
      substitution_grid$from, substitution_grid$to, substitution_grid$duration
    ),
    pattern = cross(map(sim_dt, sim_fitted_models, sim_density_model, sim_timegroup_cuts, sim_comp_limits), map(substitution_grid))
  ),
  
  # 6. Validation: compare estimated to true effects
  tar_target(
    validation_results,
    validate_simulation(sim_isotemporal_results, sim_specs),
    pattern = map(sim_isotemporal_results, sim_specs)
  ),
  
  # 7. Validation summary
  tar_target(
    validation_summary,
    summarize_validation(validation_results)
  )
)
```

### Running Simulations

```r
# Run all simulation targets
tar_make(names = starts_with("sim_"))

# Or run everything including validation
tar_make()
```

---

## Validation Framework

### Validation Function

```r
validate_simulation <- function(estimated_results, true_spec) {
  # Extract true effects from spec
  true_effects <- extract_true_effects(true_spec)
  
  # Compare estimated isotemporal effects to expected direction/magnitude
  # based on the known DGP
  
  # Return comparison table with:
  # - Estimated effect
  # - Expected effect (from true_spec)
  # - Relative error
  # - Pass/fail status
}
```

### Validation Criteria

| Check | Pass Condition |
|-------|----------------|
| Effect direction | Sign of estimate matches sign of true effect |
| Effect magnitude | \|estimated - true\| / \|true\| < tolerance (default 50%) |
| Confidence interval | True effect is within 95% CI |
| Null detection | If true effect = 0, CI includes 0 |

### Validation Output

```r
# validation_results structure
data.table(
  scenario = "protective_n3",
  substitution = "n3_from_rem_15min",
  true_effect = -0.015,      # Expected risk difference
  estimated_effect = -0.012, # From pipeline
  relative_error = 0.20,
  ci_lower = -0.025,
  ci_upper = 0.001,
  direction_correct = TRUE,
  magnitude_ok = TRUE,
  truth_in_ci = TRUE,
  validation_passed = TRUE
)
```

---

## Implementation Tiers

### Tier 1: Core (Implement First)
- [ ] `make_sim_spec()` with default parameters
- [ ] `simulate_dataset()` with Dirichlet compositions
- [ ] Linear effects only (no interactions)
- [ ] Single dementia outcome
- [ ] Basic `validate_simulation()` function
- [ ] Integration with targets pipeline

### Tier 2: Essential Extensions
- [ ] Effect modification by age (interaction terms)
- [ ] Multiple predefined scenarios
- [ ] Death as competing risk
- [ ] Non-linear (quadratic) effects in DGP
- [ ] Comprehensive validation report

### Tier 3: Advanced (If Needed)
- [ ] SHHS-1 battery failure missingness pattern
- [ ] MRI outcomes
- [ ] Time-varying effects
- [ ] U-shaped relationships (spline-based DGP)
- [ ] Covariate-dependent censoring

---

## Code References

| Component | File | Function |
|-----------|------|----------|
| Simulation spec | `R/simulate_data.R` | `make_sim_spec()` |
| Dataset generation | `R/simulate_data.R` | `simulate_dataset()` |
| Baseline generation | `R/simulate_data.R` | `simulate_baseline()` |
| Sleep stage generation | `R/simulate_data.R` | `simulate_sleep_stages()` |
| Outcome generation | `R/simulate_data.R` | `simulate_outcomes()` |
| Validation | `R/validate_simulation.R` | `validate_simulation()` |
| Targets | `simulation_targets.R` | `simulation_targets` |

---

## Caveats and Limitations

1. **Simplified DGP:** The simulation uses a simplified causal model that may not capture all complexities of the real data (e.g., complex confounding structures, measurement error).

2. **Known model → known results:** When the analysis model matches the DGP, validation is easier. Real-world model misspecification is harder to assess.

3. **Effect scale:** True effects are specified on the log-odds scale for dementia. Converting to risk differences for validation requires careful calibration.

4. **Computational cost:** Running full analysis on multiple simulation scenarios can be time-consuming. Consider using smaller `n` for development iterations.

5. **Not a substitute for real data:** Simulated data validates *pipeline correctness*, not *scientific conclusions*. Real data analysis remains essential.
