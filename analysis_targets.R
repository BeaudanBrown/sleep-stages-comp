analysis_config_targets <- list(
  tar_target(
    bootstrap_config,
    list(
      B = 100,
      m = 10
    )
  ),
  tar_target(
    substitutions,
    comparison_substitution_grid()
  ),
  tar_target(
    substitutions_list,
    split(substitutions, seq_len(nrow(substitutions)))
  )
)

analysis_survival_targets <- list(
  tar_target(
    timegroup_cuts,
    make_cuts(imp)
  ),
  tar_target(
    dt_surv_long,
    expand_surv_dt(imp, timegroup_cuts)
  ),
  tar_target(
    dt_surv_wide,
    make_surv_wide(dt_surv_long)
  ),
  tar_target(
    comp_limits,
    make_comp_limits(imp)
  ),
  tar_target(
    lmtp_surv_cols,
    get_lmtp_surv_cols(dt_surv_wide)
  ),
  tar_target(
    lmtp_baseline_covars,
    default_baseline_covars(dt_surv_wide)
  ),
  tar_target(
    comparison_contract,
    build_comparison_contract(dt_surv_wide)
  )
)

analysis_lmtp_targets <- list(
  tar_target(
    lmtp_learners_outcome,
    c("SL.mean", "SL.glm")
  ),
  tar_target(
    lmtp_learners_trt,
    "SL.glm"
  ),
  tar_target(
    lmtp_folds,
    5
  ),
  tar_target(
    lmtp_tmle_reference,
    run_lmtp_tmle_reference(
      dt_surv_wide,
      lmtp_surv_cols$outcome,
      lmtp_surv_cols$cens,
      lmtp_surv_cols$compete,
      comparison_contract$trt_cols,
      lmtp_baseline_covars,
      lmtp_learners_outcome,
      lmtp_learners_trt,
      lmtp_folds
    )
  ),
  tar_target(
    lmtp_tmle_substitutions,
    tryCatch(
      run_lmtp_tmle_substitution(
        dt_surv_wide,
        lmtp_surv_cols$outcome,
        lmtp_surv_cols$cens,
        lmtp_surv_cols$compete,
        comparison_contract$trt_cols,
        lmtp_baseline_covars,
        comp_limits,
        lmtp_tmle_reference,
        substitutions,
        lmtp_learners_outcome,
        lmtp_learners_trt,
        lmtp_folds
      ),
      error = function(e) {
        stop(
          paste0(
            "targets branch lmtp_tmle_substitutions failed [",
            format_lmtp_substitution(substitutions),
            "]: ",
            conditionMessage(e)
          ),
          call. = FALSE
        )
      }
    ),
    pattern = map(substitutions)
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
    mi_timegroup_cuts,
    make_cuts(imp_datasets),
    pattern = map(imp_datasets)
  ),
  tar_target(
    mi_pooled_fitted_models,
    fit_models(imp_datasets, mi_timegroup_cuts),
    pattern = map(imp_datasets, mi_timegroup_cuts)
  ),
  tar_target(
    mi_comp_limits,
    make_comp_limits(imp_datasets),
    pattern = map(imp_datasets)
  ),
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
      comp_limits = mi_comp_limits,
      fitted_models = mi_pooled_fitted_models,
      timegroup_cuts = mi_timegroup_cuts,
      baseline_risk = mi_pooled_baseline_risk
    ),
    pattern = map(
      imp_datasets,
      mi_comp_limits,
      mi_pooled_fitted_models,
      mi_timegroup_cuts,
      mi_pooled_baseline_risk
    )
  ),
  tar_target(
    pooled_substituted_risk_by_imputation,
    data.table::rbindlist(mi_pooled_substituted_risk, idcol = "imputation_id")
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
      set.seed(tar_seed())
      sample.int(.Machine$integer.max, bootstrap_config$B)
    }
  ),
  tar_target(
    boot_dt,
    bootstrap_resample(imp, seed = bootstrap_seeds),
    pattern = map(bootstrap_seeds)
  ),
  tar_target(
    boot_timegroup_cuts,
    make_cuts(boot_dt),
    pattern = map(boot_dt)
  ),
  tar_target(
    boot_fitted_models,
    fit_models(boot_dt, boot_timegroup_cuts),
    pattern = map(boot_dt, boot_timegroup_cuts)
  ),
  tar_target(
    boot_comp_limits,
    make_comp_limits(boot_dt),
    pattern = map(boot_dt)
  ),
  tar_target(
    boot_baseline_risk,
    predict_risks(boot_dt, boot_fitted_models, boot_timegroup_cuts),
    pattern = map(boot_dt, boot_fitted_models, boot_timegroup_cuts)
  ),
  tar_target(
    boot_substituted_risk,
    {
      out <- compute_substitution_risk_table(
        dt = boot_dt,
        substitutions = substitutions,
        comp_limits = boot_comp_limits,
        fitted_models = boot_fitted_models,
        timegroup_cuts = boot_timegroup_cuts,
        baseline_risk = boot_baseline_risk
      )
      out[, bootstrap_seed := bootstrap_seeds]
      out
    },
    pattern = map(
      boot_dt,
      boot_comp_limits,
      boot_fitted_models,
      boot_timegroup_cuts,
      boot_baseline_risk,
      bootstrap_seeds
    )
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
  analysis_survival_targets,
  analysis_lmtp_targets,
  analysis_bootstrap_targets,
  analysis_comparison_targets
)
