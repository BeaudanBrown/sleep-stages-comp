time_to_event_targets <- list(
  # generate bootstrap samples
  tar_rep(
    dt_boot,
    command = {
      rows <- sample(1:nrow(dt), nrow(dt), replace = TRUE)
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
    fit_models_surv(dt_long),
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
      as.data.table(risk_summary[from %in% "n3_s2" | to %in% "n3_s2"]),
      by = c("from", "to"),
      keep.by = TRUE
    ),
    iteration = "list"
  ),
  tar_target(
    risk_summary_pair_plot,
    plot_risk_summary_pair(
      risk_summary_by_pair,
      labels = stage_labels,
      right_stage = "n3_s2"
    ),
    pattern = map(risk_summary_by_pair),
    iteration = "list"
  )
)

continuous_outcome_targets <- list(
  tar_target(outcome_vars, c("pc1_s2", "Hippo_s2", "Cerebrum_tcb_s2")),
  tar_target(
    dt_imp,
    impute_data(dt_boot, method = "cart"),
    pattern = map(dt_boot)
  ),
  # calculate cognitive summary score (see INSERT REF)
  tar_target(
    dt_imp_cog_score,
    lapply(dt_imp, \(imp) get_cog_score(as.data.table(imp))),
    pattern = map(dt_imp)
  ),
  # fit outcome model
  tar_target(
    outcome_models_cont,
    lapply(dt_imp_cog_score, fit_models_cont, outcome = outcome_vars),
    pattern = cross(dt_imp_cog_score, outcome_vars)
  ),
  # expected outcome under no intervention
  tar_target(
    mean_no_int,
    rbindlist(
      Map(gcomp, outcome_models_cont, dt_imp_cog_score),
      idcol = "imputation_id"
    ),
    pattern = map(
      outcome_models_cont,
      cross(dt_imp_cog_score, outcome_vars)
    )
  ),
  tar_target(
    estimates,
    rbindlist(
      lapply(seq_along(dt_imp_cog_score), \(i) {
        compute_substitution_table(
          dt = dt_imp_cog_score[[i]],
          substitutions = substitutions,
          comp_hull = comp_hull_masks,
          fitted_models = outcome_models_cont[[i]],
          ref_dt = mean_no_int[imputation_id == i],
          comp_vars = paste0(comp_vars, "_s2"),
          ilr_base = ilr_base
        )
      }),
      idcol = "imputation_id"
    ),
    pattern = map(
      outcome_models_cont,
      mean_no_int,
      cross(dt_imp_cog_score, outcome_vars)
    )
  )
)
