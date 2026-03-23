analysis_config_targets <- list(
  tar_target(
    bootstrap_config,
    list(
      B = 100,
      m = 10
    )
  )
)

analysis_shared_mi_targets <- list(
  tar_target(
    imp_dataset_ids,
    seq_len(length(imp_datasets))
  ),
  tar_target(
    mi_timegroup_cuts,
    make_cuts(imp_datasets),
    pattern = map(imp_datasets)
  ),
  tar_target(
    timegroup_cuts,
    combine_timegroup_cuts(mi_timegroup_cuts)
  ),
  tar_target(
    mi_dt_surv_long,
    expand_surv_dt(imp_datasets, mi_timegroup_cuts),
    pattern = map(imp_datasets, mi_timegroup_cuts)
  ),
  tar_target(
    mi_dt_surv_wide,
    make_surv_wide(mi_dt_surv_long),
    pattern = map(mi_dt_surv_long)
  ),
  tar_target(
    mi_lmtp_surv_cols,
    get_lmtp_surv_cols(mi_dt_surv_wide),
    pattern = map(mi_dt_surv_wide)
  ),
  tar_target(
    lmtp_surv_cols,
    combine_lmtp_surv_cols(mi_lmtp_surv_cols)
  ),
  tar_target(
    mi_lmtp_baseline_covars,
    default_baseline_covars(imp_datasets),
    pattern = map(imp_datasets)
  ),
  tar_target(
    lmtp_baseline_covars,
    combine_imputation_character_vectors(mi_lmtp_baseline_covars)
  ),
  tar_target(
    mi_comp_limits,
    make_comp_limits(imp_datasets),
    pattern = map(imp_datasets)
  ),
  tar_target(
    comp_limits,
    combine_imputation_comp_limits(mi_comp_limits)
  ),
  tar_target(
    mi_substitution_support_frontiers,
    compute_directional_support_frontiers(
      dt = imp_datasets,
      comp_limits = mi_comp_limits
    ),
    pattern = map(imp_datasets, mi_comp_limits),
    iteration = "list"
  ),
  tar_target(
    substitution_support_frontiers,
    combine_imputation_support_frontiers(mi_substitution_support_frontiers)
  ),
  tar_target(
    substitutions,
    build_support_aware_substitution_grid(substitution_support_frontiers)
  ),
  tar_target(
    substitutions_list,
    split(substitutions, seq_len(nrow(substitutions)))
  ),
  tar_target(
    comparison_contract,
    build_shared_comparison_contract(
      imp_datasets,
      substitutions = substitutions
    )
  )
)

analysis_lmtp_targets <- list(
  tar_target(
    lmtp_learners_outcome,
    c("SL.mean", "SL.glm", "SL.glm.interaction")
  ),
  tar_target(
    lmtp_learners_trt,
    c("SL.glm", "SL.glm.interaction")
  ),
  tar_target(
    lmtp_folds,
    5
  ),
  tar_target(
    mi_lmtp_tmle_substitutions,
    {
      out <- tryCatch(
        run_lmtp_tmle_substitutions_for_dataset(
          dt = mi_dt_surv_wide,
          outcome_cols = mi_lmtp_surv_cols$outcome,
          cens_cols = mi_lmtp_surv_cols$cens,
          compete_cols = mi_lmtp_surv_cols$compete,
          trt_cols = comparison_contract$trt_cols,
          baseline_covars = mi_lmtp_baseline_covars,
          comp_limits = mi_comp_limits,
          substitutions = substitutions,
          learners_outcome = lmtp_learners_outcome,
          learners_trt = lmtp_learners_trt,
          folds = lmtp_folds
        ),
        error = function(e) {
          stop(
            paste0(
              "MI LMTP branch failed: ",
              conditionMessage(e)
            ),
            call. = FALSE
          )
        }
      )
      out[, imputation_id := as.character(imp_dataset_ids)]
      out
    },
    pattern = map(
      mi_dt_surv_wide,
      mi_lmtp_surv_cols,
      mi_lmtp_baseline_covars,
      mi_comp_limits,
      imp_dataset_ids
    )
  ),
  tar_target(
    lmtp_tmle_substitutions_by_imputation,
    data.table::as.data.table(mi_lmtp_tmle_substitutions)
  ),
  tar_target(
    lmtp_tmle_substitutions,
    average_lmtp_imputation_summaries(lmtp_tmle_substitutions_by_imputation)
  ),
  tar_target(
    plot_lmtp_tmle_substitutions,
    make_lmtp_substitution_plots(
      lmtp_tmle_substitutions,
      ratio_threshold = comparison_contract$ratio_threshold
    )
  ),
  tar_target(
    lmtp_tmle_substituted_plot_png,
    write_lmtp_substitution_plots(
      plot_lmtp_tmle_substitutions,
      file.path("results", "lmtp_substitution_risk_ratio")
    ),
    format = "file"
  )
)

analysis_bootstrap_targets <- list(
  tar_target(
    mi_pooled_fitted_models,
    fit_models(imp_datasets, mi_timegroup_cuts),
    pattern = map(imp_datasets, mi_timegroup_cuts)
  ),
  tar_target(
    mi_pooled_baseline_risk,
    predict_risks(imp_datasets, mi_pooled_fitted_models, mi_timegroup_cuts),
    pattern = map(imp_datasets, mi_pooled_fitted_models, mi_timegroup_cuts)
  ),
  tar_target(
    mi_pooled_substituted_risk,
    {
      out <- compute_substitution_risk_table(
        dt = imp_datasets,
        substitutions = substitutions,
        comp_limits = mi_comp_limits,
        fitted_models = mi_pooled_fitted_models,
        timegroup_cuts = mi_timegroup_cuts,
        baseline_risk = mi_pooled_baseline_risk
      )
      out[, imputation_id := as.character(imp_dataset_ids)]
      out
    },
    pattern = map(
      imp_datasets,
      mi_comp_limits,
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
    boot_substituted_risk,
    {
      out <- run_bootstrap_rep(
        dt = dt,
        substitutions = substitutions,
        seed = bootstrap_seeds,
        m = bootstrap_config$m
      )
      out[, bootstrap_seed := bootstrap_seeds]
      out
    },
    pattern = map(bootstrap_seeds)
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

analysis_comparison_targets <- list(
  tar_target(
    pooled_vs_lmtp_comparison,
    join_method_substitution_summaries(
      pooled_summary = pooled_risk_overall,
      lmtp_summary = lmtp_tmle_substitutions,
      ratio_threshold = comparison_contract$ratio_threshold
    )
  ),
  tar_target(
    pooled_vs_lmtp_comparison_summary,
    summarize_method_comparison(pooled_vs_lmtp_comparison)
  ),
  tar_target(
    pooled_vs_lmtp_debug_rows,
    extract_comparison_debug_rows(pooled_vs_lmtp_comparison)
  ),
  tar_target(
    pooled_vs_lmtp_scale_probe,
    build_pooled_scale_probe(
      pooled_substituted_risk = pooled_substituted_risk,
      lmtp_summary = lmtp_tmle_substitutions
    )
  ),
  tar_target(
    pooled_vs_lmtp_scale_probe_summary,
    summarize_scale_probe(pooled_vs_lmtp_scale_probe)
  )
)

analysis_targets <- c(
  analysis_config_targets,
  analysis_shared_mi_targets,
  analysis_lmtp_targets,
  analysis_bootstrap_targets,
  analysis_comparison_targets
)
