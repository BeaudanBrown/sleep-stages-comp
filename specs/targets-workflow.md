# Targets Workflow Specification

## Overview
This specification defines how the targets package should be used to create a reproducible, parallel, and efficient compositional analysis pipeline. The workflow emphasizes functional programming patterns and leverages crew for distributed computing.

## Core Principles

### Functional Programming
- Each target is a pure function with no side effects
- Inputs explicitly declared as dependencies
- Outputs are immutable data objects
- No global state modification

### Branching for Combinations
- Use `tar_map()` and `cross_df()` for substitution combinations
- Dynamic branching for stratified analyses
- Static branching for known parameter grids

## Pipeline Structure

### 1. Data Loading Layer
```r
# File targets for raw data
tar_target(shhs_psg2_file, "path/to/psg2.csv", format = "file")

# Loaded and cleaned data
tar_target(
  data_clean,
  prepare_dataset(data_raw),
  packages = c("data.table", "compositions")
)
```

### Important: Nix Integration
- All R packages must be declared in flake.nix
- Use nixos_nix MCP tool to search for package availability
- Run pipeline within nix shell: `nix develop -c Rscript -e "targets::tar_make()"`

### 2. Imputation Layer
```r
# Multiple imputation with 250 iterations
tar_target(
  data_imputed,
  impute_compositional_data(
    data_clean,
    m = 250,
    method = "truncated_norm"
  ),
  deployment = "worker"
)
```

### 3. Compositional Transformation Layer
```r
# ILR transformation for each imputed dataset
tar_target(
  data_ilr,
  pattern = map(data_imputed),
  transform_to_ilr(data_imputed)
)
```

### 4. Dynamic Substitution Analysis
```r
# Use dynamic branching exclusively
tar_target(
  substitution_scenarios,
  expand.grid(
    from = c("n1", "n2", "n3", "rem"),
    to = c("n1", "n2", "n3", "rem"),
    minutes = c(15, 30, 45, 60),
    stringsAsFactors = FALSE
  ) %>%
  filter(from != to) %>%
  as.data.table()
)

# Single target with dynamic branching
tar_target(
  substitution_results,
  perform_all_substitutions(
    data_imputed = data_imputed,
    scenarios = substitution_scenarios,
    outcome = "dementia_mci"
  ),
  pattern = map(data_imputed),
  iteration = "list"
)
```

Note: The function should return a data.table with columns for:
- All input parameters (from, to, minutes, outcome)
- Effect estimates and confidence intervals
- Number of participants included
- Imputation number
```

### 5. Results Combination Layer
```r
# Combine results across imputations using Rubin's rules
tar_target(
  combined_results,
  combine_imputation_results(substitution_results),
  deployment = "main"
)

# Aggregate for different outcomes
tar_target(
  all_outcomes_results,
  pattern = map(c("dementia_mci", "brain_vol", "hippo_vol", "wmh_vol")),
  run_outcome_analysis(
    data_imputed = data_imputed,
    scenarios = substitution_scenarios,
    outcome = outcome
  )
)
```

### 6. Optimal Composition Layer
```r
# Search for optimal sleep composition
tar_target(
  optimal_composition,
  find_optimal_composition(
    model = fitted_model,
    constraints = composition_constraints(),
    method = "grid_search"
  ),
  pattern = map(outcome_types)
)
```

### 7. Output Layer
```r
# Tables
tar_target(
  results_table,
  format_results_table(all_substitutions),
  format = "file"
)

# Figures
tar_target(
  substitution_heatmap,
  create_substitution_heatmap(all_substitutions),
  format = "file"
)

# Reports
tar_quarto(
  report,
  "analysis_report.qmd",
  deps = c(results_table, substitution_heatmap)
)
```

## Crew Configuration

### Controller Setup
```r
library(crew)
controller <- crew_controller_local(
  workers = parallel::detectCores() - 1,
  seconds_idle = 60
)

tar_option_set(
  controller = controller,
  garbage_collection = TRUE
)
```

### Seed Management
```r
# Set global seed for pipeline reproducibility
tar_option_set(seed = 12345)

# Each target automatically gets its own derived seed
# Access current target's seed if needed:
current_seed <- tar_seed()

# For custom seed control within a target:
tar_seed_set(custom_value)

# Disable automatic seeding (not recommended):
tar_option_set(seed = NA)
```

## Best Practices

### 1. Target Naming Conventions
- Data targets: `data_*`
- Model targets: `model_*`
- Result targets: `results_*`
- File targets: `*_file`
- Combined targets: `all_*`

### 2. Pattern Usage
- `map()`: When iterating over imputed datasets
- `cross()`: When all combinations needed
- `group_by()`: For stratified analyses
- `combine()`: To aggregate results

### 3. Function Organization
```
R/
├── data_functions.R      # Data loading and cleaning
├── imputation_functions.R # Compositional imputation
├── ilr_functions.R       # ILR transformations
├── substitution_functions.R # Isotemporal substitutions
├── model_functions.R     # Statistical models
├── optimization_functions.R # Finding optimal compositions
└── output_functions.R    # Tables and visualizations
```

### 4. Error Handling
- Use `error = "continue"` for non-critical targets
- Implement validation functions that return clear messages
- Log convergence issues and warnings

### 5. Reproducibility
- Set seeds in target functions, not globally
- Use `tar_seed()` for consistent random numbers
- Version control the `_targets.R` file

## Common Patterns

### Dynamic Substitution Grid
```r
# Generate based on data characteristics
tar_target(
  dynamic_grid,
  generate_substitution_grid(
    data = data_clean,
    min_prevalence = 0.05,
    time_increments = c(10, 20, 30, 60)
  )
)
```

### Parallel Bootstrap
```r
tar_target(
  bootstrap_samples,
  pattern = map(seq_len(1000)),
  create_bootstrap_sample(data_clean, seed = .x)
)
```

### Cross-validation
```r
tar_target(
  cv_folds,
  create_cv_folds(data_clean, k = 10)
)

tar_target(
  cv_results,
  pattern = cross(cv_folds, model_specs),
  fit_cv_model(train = cv_folds$train, 
               test = cv_folds$test,
               spec = model_specs)
)
```