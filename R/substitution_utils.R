make_substitution_grid <- function(durations, directed = TRUE) {
  if (!is.numeric(durations) || length(durations) == 0L) {
    stop("durations must be a non-empty numeric vector.", call. = FALSE)
  }

  pairs <- t(combn(comp_vars, 2))
  pair_dt <- data.table::data.table(from = pairs[, 1], to = pairs[, 2])

  if (isTRUE(directed)) {
    pair_dt <- data.table::rbindlist(list(
      pair_dt,
      pair_dt[, .(from = to, to = from)]
    ))
  }

  pair_dt[, .(duration = durations), by = .(from, to)]
}

compute_substitution_mask <- function(dt, from, to, duration, comp_limits) {
  if (duration == 0) {
    return(rep(TRUE, nrow(dt)))
  }

  if (duration > 0) {
    max_from_change <- dt[[from]] - comp_limits[[from]]$lower
    max_to_change <- comp_limits[[to]]$upper - dt[[to]]
    return((max_from_change >= duration) & (max_to_change >= duration))
  }

  abs_dur <- abs(duration)
  max_from_change <- comp_limits[[from]]$upper - dt[[from]]
  max_to_change <- dt[[to]] - comp_limits[[to]]$lower
  (max_from_change >= abs_dur) & (max_to_change >= abs_dur)
}

compute_shifted_exposures <- function(dt, from, to, duration, comp_limits) {
  dt <- as.data.table(dt)
  can_substitute <- compute_substitution_mask(
    dt = dt,
    from = from,
    to = to,
    duration = duration,
    comp_limits = comp_limits
  )

  shifted_dt <- copy(dt)
  shifted_dt[[from]] <- shifted_dt[[from]] - (can_substitute * duration)
  shifted_dt[[to]] <- shifted_dt[[to]] + (can_substitute * duration)
  shifted_dt[["substituted"]] <- can_substitute

  ilr_vars <- make_ilrs(shifted_dt)
  shifted_dt[, (ilr_names) := ilr_vars]

  shifted_dt
}

extract_shifted_treatment <- function(shifted_dt, trt_cols) {
  as.data.frame(
    as.data.table(shifted_dt)[, trt_cols, with = FALSE],
    check.names = FALSE
  )
}

summarize_substitution_coverage <- function(shifted_dt) {
  substituted <- as.data.table(shifted_dt)[["substituted"]]
  if (is.null(substituted)) {
    stop("shifted_dt must contain a 'substituted' column.", call. = FALSE)
  }

  list(
    n_intervened = sum(substituted),
    n_total = length(substituted),
    ratio_substituted = mean(substituted)
  )
}

make_lmtp_shift <- function(from, to, duration, comp_limits) {
  function(data, trt) {
    shifted_dt <- compute_shifted_exposures(
      dt = data,
      from = from,
      to = to,
      duration = duration,
      comp_limits = comp_limits
    )

    extract_shifted_treatment(shifted_dt, trt)
  }
}

apply_substitution <- function(dt, from_var, to_var, duration, comp_limits) {
  compute_shifted_exposures(
    dt = dt,
    from = from_var,
    to = to_var,
    duration = duration,
    comp_limits = comp_limits
  )
}

compute_substituted_risk <- function(
  dt,
  from,
  to,
  duration,
  comp_limits,
  fitted_models,
  timegroup_cuts,
  baseline_risk
) {
  sub_dt <- apply_substitution(
    dt,
    from,
    to,
    duration,
    comp_limits
  )

  risk_dt <- predict_risks(sub_dt, fitted_models, timegroup_cuts)
  setnames(risk_dt, "risk", "mean_risk_substituted")

  baseline_dt <- copy(baseline_risk)
  setnames(baseline_dt, "risk", "mean_risk_baseline")

  coverage <- summarize_substitution_coverage(sub_dt)

  risk_dt[, `:=`(
    from = from,
    to = to,
    duration = duration,
    n_intervened = coverage$n_intervened,
    n_total = coverage$n_total
  )]

  merge(
    baseline_dt,
    risk_dt,
    by = "timegroup"
  )
}
