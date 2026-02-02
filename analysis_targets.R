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
    substitutions,
    {
      pairs <- t(combn(comp_vars, 2))
      pair_dt <- data.table(from = pairs[, 1], to = pairs[, 2])
      pair_dt[,
        .(duration = seq(-60, 60, by = 15)),
        by = .(from, to)
      ]
    }
  ),

  # 7. Substituted Risk (Per substitution)
  tar_target(
    substituted_risk,
    compute_substituted_risk(
      dt,
      substitutions$from,
      substitutions$to,
      substitutions$duration,
      comp_limits,
      fitted_models,
      timegroup_cuts,
      baseline_risk
    ),
    pattern = map(substitutions)
  )
)
