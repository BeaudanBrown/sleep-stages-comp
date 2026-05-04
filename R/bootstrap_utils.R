bootstrap_resample <- function(dt, seed) {
  set.seed(seed)

  pids <- unique(dt$PID)
  draw <- sample(pids, size = length(pids), replace = TRUE)

  boot_dt <- dt[
    data.table::data.table(PID = draw),
    on = "PID",
    allow.cartesian = TRUE
  ]
  boot_dt[, PID_original := PID]
  boot_dt[, PID := seq_len(.N)]

  boot_dt
}

compute_substitution_risk_table <- function(
  dt,
  substitutions,
  comp_limits,
  fitted_models,
  timegroup_cuts,
  baseline_risk,
  imputation_id = NULL
) {
  res_list <- lapply(seq_len(nrow(substitutions)), function(i) {
    row <- substitutions[i]
    compute_substituted_risk(
      dt,
      row$from,
      row$to,
      row$duration,
      comp_limits,
      fitted_models,
      timegroup_cuts,
      baseline_risk
    )
  })

  out <- data.table::rbindlist(res_list)
  if (!is.null(imputation_id)) {
    out[, imputation_id := as.character(imputation_id)]
  }
  out
}

summarize_substituted_risk_final_time <- function(dt, by_cols = NULL) {
  dt <- data.table::copy(dt)
  dt[, risk_ratio := mean_risk_substituted / mean_risk_baseline]
  dt[, ratio_substituted := n_intervened / n_total]

  group_cols <- unique(c(by_cols, "from", "to", "duration"))
  dt[, max_timegroup := max(timegroup), by = by_cols]
  dt <- dt[timegroup == max_timegroup]

  dt[, c("max_timegroup") := NULL]

  dt[,
    .(risk_ratio, ratio_substituted),
    by = group_cols
  ]
}

summarize_point_estimate_substitutions <- function(substituted_risk) {
  summarize_substituted_risk_final_time(substituted_risk)[,
    .(
      mean_risk_ratio = risk_ratio,
      ratio_substituted = ratio_substituted
    ),
    by = .(from, to, duration)
  ]
}

average_imputation_substitution_risk <- function(substituted_risk) {
  dt <- data.table::as.data.table(substituted_risk)

  if (!"imputation_id" %in% names(dt)) {
    return(dt)
  }

  dt[,
    .(
      mean_risk_baseline = mean(mean_risk_baseline),
      mean_risk_substituted = mean(mean_risk_substituted),
      n_intervened = mean(n_intervened),
      n_total = mean(n_total)
    ),
    by = .(from, to, duration, timegroup)
  ]
}

summarize_bootstrap_substitution_intervals <- function(boot_substituted_risk) {
  dt <- summarize_substituted_risk_final_time(
    boot_substituted_risk,
    by_cols = "bootstrap_seed"
  )

  dt[,
    .(
      bootstrap_mean_risk_ratio = mean(risk_ratio),
      lower_ci = quantile(risk_ratio, 0.025),
      upper_ci = quantile(risk_ratio, 0.975),
      bootstrap_ratio_substituted = mean(ratio_substituted)
    ),
    by = .(from, to, duration)
  ]
}

combine_point_estimates_with_bootstrap_cis <- function(
  point_estimates,
  bootstrap_summary
) {
  merged <- merge(
    data.table::as.data.table(point_estimates),
    data.table::as.data.table(bootstrap_summary),
    by = c("from", "to", "duration"),
    all.x = TRUE,
    sort = FALSE
  )

  merged[, .(
    from,
    to,
    duration,
    mean_risk_ratio,
    lower_ci,
    upper_ci,
    ratio_substituted,
    bootstrap_mean_risk_ratio,
    bootstrap_ratio_substituted
  )]
}

run_bootstrap_rep <- function(dt, substitutions, seed, m = 10, maxit = 5) {
  boot_dt <- bootstrap_resample(dt, seed)
  boot_imp <- impute_data(boot_dt, m = m, maxit = maxit)
  boot_imp_datasets <- complete_imputed_datasets(imp = boot_imp, dt = boot_dt)

  boot_substitutions <- lapply(boot_imp_datasets, function(boot_imp_dt) {
    timegroup_cuts <- make_cuts(boot_imp_dt)
    fitted_models <- fit_models(boot_imp_dt, timegroup_cuts)
    comp_limits <- make_comp_limits(boot_imp_dt)
    baseline_risk <- predict_risks(boot_imp_dt, fitted_models, timegroup_cuts)

    compute_substitution_risk_table(
      dt = boot_imp_dt,
      substitutions = substitutions,
      comp_limits = comp_limits,
      fitted_models = fitted_models,
      timegroup_cuts = timegroup_cuts,
      baseline_risk = baseline_risk
    )
  })

  out <- average_imputation_substitution_risk(
    data.table::rbindlist(boot_substitutions, idcol = "imputation_id")
  )
  out[, bootstrap_seed := seed]
  out
}

summarize_bootstrap_substitutions <- function(boot_substituted_risk) {
  summarize_bootstrap_substitution_intervals(boot_substituted_risk)[,
    .(
      risk_ratio_mean = bootstrap_mean_risk_ratio,
      risk_ratio_lo = lower_ci,
      risk_ratio_hi = upper_ci
    ),
    by = .(from, to, duration)
  ]
}
