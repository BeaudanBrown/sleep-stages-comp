simulation_spec_targets <- list(
  tar_target(
    sim_specs,
    list(
      null_effect = make_sim_spec(name = "null_effect"),
      protective_n3 = make_sim_spec(
        name = "protective_n3",
        effect_R2_dem = -0.3
      )
    )
  ),
  tar_target(
    sim_substitution_grid,
    make_substitution_grid(
      durations = c(15, 30, 60),
      directed = TRUE
    )
  )
)

simulation_analysis_targets <- list(
  tar_target(
    sim_dt_raw,
    simulate_dataset(sim_specs),
    pattern = map(sim_specs)
  ),
  tar_target(
    sim_dt,
    prepare_simulated_dataset(sim_dt_raw),
    pattern = map(sim_dt_raw)
  ),
  tar_target(
    sim_timegroup_cuts,
    make_cuts(sim_dt),
    pattern = map(sim_dt)
  ),
  tar_target(
    sim_density_model,
    fit_density_model(sim_dt),
    pattern = map(sim_dt)
  ),
  tar_target(
    sim_fitted_models,
    fit_models(sim_dt, sim_timegroup_cuts),
    pattern = map(sim_dt, sim_timegroup_cuts)
  ),
  tar_target(
    sim_comp_limits,
    make_comp_limits(sim_dt),
    pattern = map(sim_dt)
  ),
  tar_target(
    sim_baseline_risk,
    predict_risks(sim_dt, sim_fitted_models, sim_timegroup_cuts),
    pattern = map(sim_dt, sim_fitted_models, sim_timegroup_cuts)
  )

  # Isotemporal substitution and validation targets remain intentionally
  # disabled until the corresponding simulation analysis path is restored.
)

simulation_targets <- c(
  simulation_spec_targets,
  simulation_analysis_targets
)
