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
    make_substitution_grid(
      durations = seq(-60, 60, by = 15),
      directed = FALSE
    )
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
      ilr_names,
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
        ilr_names,
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
    make_lmtp_substitution_plots(lmtp_tmle_substitutions)
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
      res_list <- lapply(seq_len(nrow(substitutions)), function(i) {
        row <- substitutions[i]
        compute_substituted_risk(
          boot_dt,
          row$from,
          row$to,
          row$duration,
          boot_comp_limits,
          boot_fitted_models,
          boot_timegroup_cuts,
          boot_baseline_risk
        )
      })
      out <- data.table::rbindlist(res_list)
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
    {
      dt <- data.table::copy(boot_substituted_risk)
      dt[, risk_ratio := mean_risk_substituted / mean_risk_baseline]
      dt[, ratio_substituted := n_intervened / n_total]

      dt[, max_timegroup := max(timegroup), by = bootstrap_seed]
      dt <- dt[timegroup == max_timegroup]

      dt[,
        .(risk_ratio, ratio_substituted),
        by = .(bootstrap_seed, from, to, duration)
      ]
    }
  ),
  tar_target(
    boot_risk_overall,
    boot_risk_summary[,
      .(
        mean_risk_ratio = mean(risk_ratio),
        lower_ci = quantile(risk_ratio, 0.025),
        upper_ci = quantile(risk_ratio, 0.975),
        ratio_substituted = mean(ratio_substituted)
      ),
      by = .(from, to, duration)
    ]
  ),
  tar_target(
    plot_boot_substitutions,
    make_bootstrap_substitution_plots(boot_risk_overall)
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

analysis_targets <- c(
  analysis_config_targets,
  analysis_survival_targets,
  analysis_lmtp_targets,
  analysis_bootstrap_targets
)
