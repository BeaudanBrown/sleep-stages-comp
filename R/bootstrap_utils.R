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

run_bootstrap_rep <- function(dt, substitutions, seed) {
  boot_dt <- bootstrap_resample(dt, seed)

  timegroup_cuts <- make_cuts(boot_dt)
  fitted_models <- fit_models(boot_dt, timegroup_cuts)
  comp_limits <- make_comp_limits(boot_dt)
  baseline_risk <- predict_risks(boot_dt, fitted_models, timegroup_cuts)

  res_list <- lapply(seq_len(nrow(substitutions)), function(i) {
    row <- substitutions[i]
    compute_substituted_risk(
      boot_dt,
      row$from,
      row$to,
      row$duration,
      comp_limits,
      fitted_models,
      timegroup_cuts,
      baseline_risk
    )
  })

  data.table::rbindlist(res_list)
}

summarize_bootstrap_substitutions <- function(boot_substituted_risk) {
  dt <- copy(boot_substituted_risk)
  dt[, risk_ratio := mean_risk_substituted / mean_risk_baseline]

  dt[, max_timegroup := max(timegroup), by = bootstrap_seed]
  dt <- dt[timegroup == max_timegroup]

  dt[,
    .(
      risk_ratio_mean = mean(risk_ratio),
      risk_ratio_lo = quantile(risk_ratio, 0.025),
      risk_ratio_hi = quantile(risk_ratio, 0.975)
    ),
    by = .(from, to, duration)
  ]
}
