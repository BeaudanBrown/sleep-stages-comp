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
      boot_substituted_risk[,
        .(
          mean_risk_ratio = mean(mean_risk_substituted / mean_risk_baseline),
          lower_ci = quantile(
            mean_risk_substituted / mean_risk_baseline,
            0.025
          ),
          upper_ci = quantile(
            mean_risk_substituted / mean_risk_baseline,
            0.975
          ),
          n_intervened = first(n_intervened),
          n_total = first(n_total)
        ),
        by = .(bootstrap_seed, from, to, duration, timegroup)
      ]
    }
  ),

  tar_target(
    boot_risk_overall,
    boot_risk_summary[,
      .(
        mean_risk_ratio = mean(mean_risk_ratio),
        lower_ci = mean(lower_ci),
        upper_ci = mean(upper_ci)
      ),
      by = .(from, to, duration)
    ]
  ),

  tar_target(
    plot_boot_substitutions,
    {
      splits <- split(boot_risk_overall, by = c("from", "to"))
      lapply(splits, plot_bootstrap_substitutions)
    }
  ),

  # 12. Save summary plot to PDF
  tar_target(
    boot_substituted_plot_pdf,
    write_bootstrap_substitution_plot(
      boot_substituted_plot,
      file.path("results", "bootstrap_substitution_risk_ratio.pdf")
    ),
    format = "file"
  )
)
