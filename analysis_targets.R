analysis_targets <- list(
  # 0. Bootstrap configuration
  tar_target(
    bootstrap_config,
    list(
      B = 100,
      m = 10
    )
  ),
  # 1. Define Substitutions Grid
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

  # 2. Bootstrap seeds
  tar_target(
    bootstrap_seeds,
    {
      set.seed(tar_seed())
      sample.int(.Machine$integer.max, bootstrap_config$B)
    }
  ),

  # 3. Bootstrap datasets
  tar_target(
    boot_dt,
    bootstrap_resample(dt, seed = bootstrap_seeds),
    pattern = map(bootstrap_seeds)
  ),

  # 4. Bootstrap time cuts
  tar_target(
    boot_timegroup_cuts,
    make_cuts(boot_dt),
    pattern = map(boot_dt)
  ),

  # 5. Bootstrap models
  tar_target(
    boot_fitted_models,
    fit_models(boot_dt, boot_timegroup_cuts),
    pattern = map(boot_dt, boot_timegroup_cuts)
  ),

  # 6. Bootstrap composition limits
  tar_target(
    boot_comp_limits,
    make_comp_limits(boot_dt),
    pattern = map(boot_dt)
  ),

  # 7. Bootstrap baseline risk
  tar_target(
    boot_baseline_risk,
    predict_risks(boot_dt, boot_fitted_models, boot_timegroup_cuts),
    pattern = map(boot_dt, boot_fitted_models, boot_timegroup_cuts)
  ),

  # 8. Bootstrap substituted risk (all substitutions per bootstrap)
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
    {
      make_bootstrap_substitution_plots(boot_risk_overall)
    }
  ),

  # 12. Save summary plots to PNG
  tar_target(
    boot_substituted_plot_png,
    write_bootstrap_substitution_plots(
      plot_boot_substitutions,
      file.path("results", "bootstrap_substitution_risk_ratio")
    ),
    format = "file"
  )
)
