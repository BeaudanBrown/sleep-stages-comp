time_to_event_targets <- list(
  # generate bootstrap samples
  tar_rep(
    dt_boot,
    command = {
      rows <- sample(seq_len(nrow(dt)), nrow(dt), replace = TRUE)
      data <- dt[rows, ]
      data[, PID_original := PID]
      data[, PID := seq_len(.N)]
      data[]
    },
    batches = 100
  ),

  # long format data
  tar_target(
    timegroup_cuts,
    make_cuts(dt, event_date, cut_width_years = 1)
  ),
  tar_target(
    dt_long,
    expand_surv_dt(dt_boot, timegroup_cuts, event_date, event_var),
    pattern = map(dt_boot)
  ),

  # fit outcome model
  tar_target(
    outcome_models,
    fit_models(dt_long, method = "mgcv"),
    pattern = map(dt_long)
  ),

  # predict under no intervention
  tar_target(
    risk_no_int,
    predict_risks(
      dt_boot,
      outcome_models,
      timegroup_cuts,
      event_var,
      event_date
    ),
    pattern = map(dt_boot, outcome_models)
  ),

  ## Apply interventions
  # estimate convex hull and create intervened dataset
  tar_target(
    comp_hull_input_file,
    write_comp_hull_input_file(
      dt = dt,
      comp_vars = paste0(comp_vars, "_s2")
    ),
    format = "file"
  ),
  tar_target(
    comp_hull_frontier_file,
    run_julia_comp_hull_frontiers(
      input_file = comp_hull_input_file,
      comparison_settings,
      comp_vars = paste0(comp_vars, "_s2")
    ),
    format = "file"
  ),
  tar_target(
    substitution_support_frontiers,
    read_comp_hull_frontiers(comp_hull_frontier_file)
  ),
  tar_target(
    substitutions,
    build_support_aware_substitution_grid(
      substitution_support_frontiers,
      comparison_settings,
      comp_vars = paste0(comp_vars, "_s2")
    )
  ),
  tar_target(
    comp_hull_substitutions_file,
    write_substitutions_file(substitutions),
    format = "file"
  ),
  tar_target(
    comp_hull_mask_file,
    run_julia_comp_hull_masks(
      input_file = comp_hull_input_file,
      substitutions_file = comp_hull_substitutions_file,
      comp_vars = paste0(comp_vars, "_s2")
    ),
    format = "file"
  ),
  tar_target(
    comp_hull_masks,
    read_comp_hull_masks(comp_hull_mask_file)
  ),
  tar_target(
    pooled_substituted_risk,
    compute_substitution_risk_table(
      dt = dt_boot,
      substitutions = substitutions,
      comp_hull = comp_hull_masks,
      fitted_models = outcome_models,
      timegroup_cuts = timegroup_cuts,
      baseline_risk = risk_no_int,
      comp_vars = paste0(comp_vars, "_s2"),
      ilr_base = ilr_base,
      event_var = event_var,
      event_date = event_date
    ),
    pattern = map(dt_boot, outcome_models, risk_no_int)
  ),
  tar_target(
    risk_summary,
    {
      pooled_substituted_risk[,
        .(
          Y0 = mean(mean_risk_baseline),
          Y0_lower = quantile(mean_risk_baseline, 0.025),
          Y0_upper = quantile(mean_risk_baseline, 0.975),
          Y1 = mean(mean_risk_substituted),
          Y1_lower = quantile(mean_risk_substituted, 0.025),
          Y1_upper = quantile(mean_risk_substituted, 0.975),
          RR = mean(mean_risk_substituted) / mean(mean_risk_baseline),
          RR_lower = quantile(
            mean_risk_substituted / mean_risk_baseline,
            0.025
          ),
          RR_upper = quantile(
            mean_risk_substituted / mean_risk_baseline,
            0.975
          ),
          n_intervened = mean(n_intervened),
          n_total = mean(n_total)
        ),
        by = .(timegroup, from, to, duration)
      ]
    }
  ),
  tar_target(
    risk_summary_by_pair,
    split(
      as.data.table(risk_summary[to %in% "n3_s2"]),
      by = c("from", "to"),
      keep.by = TRUE
    ),
    iteration = "list"
  ),
  tar_target(
    risk_summary_pair_plot,
    plot_risk_summary_pair(
      risk_summary_by_pair,
      labels = stage_labels
    ),
    pattern = map(risk_summary_by_pair),
    iteration = "list"
  )
)

analysis_bootstrap_targets <- list(
  tar_target(
    mi_pooled_baseline_risk,
    predict_risks(imp_datasets, mi_pooled_fitted_models, mi_timegroup_cuts),
    pattern = map(imp_datasets, mi_pooled_fitted_models, mi_timegroup_cuts)
  ),
  tar_target(
    mi_pooled_substituted_risk,
    compute_substitution_risk_table(
      dt = imp_datasets,
      substitutions = substitutions,
      comp_hull = comp_hull_masks,
      fitted_models = mi_pooled_fitted_models,
      timegroup_cuts = mi_timegroup_cuts,
      baseline_risk = mi_pooled_baseline_risk,
      imputation_id = imp_dataset_ids
    ),
    pattern = map(
      imp_datasets,
      mi_pooled_fitted_models,
      mi_timegroup_cuts,
      mi_pooled_baseline_risk,
      imp_dataset_ids
    )
  ),
  tar_target(
    pooled_substituted_risk_by_imputation,
    data.table::as.data.table(mi_pooled_substituted_risk)
  ),
  tar_target(
    pooled_substituted_risk,
    average_imputation_substitution_risk(pooled_substituted_risk_by_imputation)
  ),
  tar_target(
    pooled_risk_overall,
    summarize_point_estimate_substitutions(pooled_substituted_risk)
  ),
  tar_target(
    bootstrap_seeds,
    {
      sample.int(.Machine$integer.max, bootstrap_config$B)
    }
  ),
  tar_target(
    boot_resampled_dt,
    bootstrap_resample(dt, bootstrap_seeds),
    pattern = map(bootstrap_seeds)
  ),
  tar_target(
    boot_imp_mids,
    impute_data(boot_resampled_dt, m = bootstrap_config$m),
    pattern = map(boot_resampled_dt)
  ),
  tar_target(
    boot_imp_datasets,
    complete_imputed_datasets(imp = boot_imp_mids, dt = boot_resampled_dt),
    pattern = map(boot_imp_mids, boot_resampled_dt)
  ),
  tar_target(
    boot_substituted_risk_by_imputation,
    compute_bootstrap_substitution_risk_by_imputation(
      boot_imp_datasets = boot_imp_datasets,
      substitutions = substitutions,
      comp_hull = comp_hull_masks
    ),
    pattern = map(boot_imp_datasets)
  ),
  tar_target(
    boot_substituted_risk,
    average_bootstrap_substitution_replicate(
      boot_substituted_risk_by_imputation = boot_substituted_risk_by_imputation,
      seed = bootstrap_seeds
    ),
    pattern = map(boot_substituted_risk_by_imputation, bootstrap_seeds)
  ),
  tar_target(
    boot_risk_summary,
    summarize_substituted_risk_final_time(
      boot_substituted_risk,
      by_cols = "bootstrap_seed"
    )
  ),
  tar_target(
    boot_risk_intervals,
    summarize_bootstrap_substitution_intervals(boot_substituted_risk)
  ),
  tar_target(
    boot_risk_overall,
    combine_point_estimates_with_bootstrap_cis(
      point_estimates = pooled_risk_overall,
      bootstrap_summary = boot_risk_intervals
    )
  ),
  tar_target(
    plot_boot_substitutions,
    make_bootstrap_substitution_plots(
      boot_risk_overall,
      ratio_threshold = comparison_contract$ratio_threshold
    )
  ),
  tar_target(
    boot_substituted_plot_png,
    write_bootstrap_substitution_plots(
      plot_boot_substitutions,
      file.path("results", "bootstrap_substitution_risk_ratio")
    ),
    format = "file"
  )
)
