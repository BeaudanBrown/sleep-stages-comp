analysis_targets <- list(
  # 1. Define time cuts for survival analysis
  tar_target(timegroup_cuts, make_cuts(dt)),

  # 2. Fit the density model (Multivariate Normal on ILRs)
  tar_target(density_model, fit_density_model(dt)),

  # 3. Fit the pooled logistic regression models
  tar_target(fitted_models, fit_models(dt, timegroup_cuts)),

  # 4. Define composition limits (for validity checking)
  tar_target(comp_limits, make_comp_limits(dt)),

  # 5. Calculate Baseline Risk (No intervention)
  tar_target(baseline_risk, predict_risks(dt, fitted_models, timegroup_cuts)),

  # 6. Define Substitutions Grid
  tar_target(
    substitution_grid,
    expand.grid(
      from = c("wake", "n1", "n2", "n3", "rem"),
      to = c("wake", "n1", "n2", "n3", "rem"),
      duration = c(10, 30, 60), # Minutes
      stringsAsFactors = FALSE
    ) |>
      subset(from != to) |>
      as.data.table()
  ),

  # 7. Perform Isotemporal Substitutions (Mapped)
  tar_target(
    isotemporal_results,
    perform_isotemporal_substitution(
      imp,
      fitted_models,
      density_model,
      timegroup_cuts,
      comp_limits,
      substitution_grid$from,
      substitution_grid$to,
      substitution_grid$duration
    ),
    pattern = map(substitution_grid)
  )
)
