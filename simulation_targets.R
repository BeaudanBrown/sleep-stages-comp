# Simulation targets for targets pipeline
# See specs/simulation.md for full specification

# Predefined simulation scenarios
simulation_targets <- list(
  # 1. Define simulation specifications ----
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

  # 2. Generate simulated datasets (mapped over specs) ----
  tar_target(
    sim_dt_raw,
    simulate_dataset(sim_specs),
    pattern = map(sim_specs)
  ),

  # 3. Prepare simulated data (same transformations as real data) ----
  tar_target(
    sim_dt,
    prepare_simulated_dataset(sim_dt_raw),
    pattern = map(sim_dt_raw)
  ),

  # 4. Create timegroup cuts for simulated data ----
  tar_target(
    sim_timegroup_cuts,
    make_cuts(sim_dt),
    pattern = map(sim_dt)
  ),

  # 5. Fit density model for simulated data ----
  tar_target(
    sim_density_model,
    fit_density_model(sim_dt),
    pattern = map(sim_dt)
  ),

  # 6. Fit models on simulated data ----
  tar_target(
    sim_fitted_models,
    fit_models(sim_dt, sim_timegroup_cuts),
    pattern = map(sim_dt, sim_timegroup_cuts)
  ),

  # 7. Compute composition limits for simulated data ----
  tar_target(
    sim_comp_limits,
    make_comp_limits(sim_dt),
    pattern = map(sim_dt)
  ),

  # 8. Predict baseline risks for simulated data ----
  tar_target(
    sim_baseline_risk,
    predict_risks(sim_dt, sim_fitted_models, sim_timegroup_cuts),
    pattern = map(sim_dt, sim_fitted_models, sim_timegroup_cuts)
  ),

  # 9. Define substitution grid ----
  tar_target(
    sim_substitution_grid,
    {
      pairs <- t(combn(comp_vars, 2))
      pair_dt <- data.table::data.table(from = pairs[, 1], to = pairs[, 2])
      pair_dt <- data.table::rbindlist(list(
        pair_dt,
        pair_dt[, .(from = to, to = from)]
      ))

      pair_dt[, .(duration = c(15, 30, 60)), by = .(from, to)]
    }
  )

  # 10. Isotemporal substitutions on simulated data ----
  # Note: This will need the actual substitution functions from analysis_targets.R
  # For now, this is a placeholder that will be activated when substitution functions exist

  # 11. Validation: compare estimated to true effects ----
  # This will run after isotemporal results are available
  # tar_target(
  #   validation_results,
  #   validate_simulation(sim_isotemporal_results, sim_specs),
  #   pattern = map(sim_isotemporal_results, sim_specs)
  # ),

  # 12. Validation summary ----
  # tar_target(
  #   validation_summary,
  #   summarize_validation(validation_results)
  # )
)
