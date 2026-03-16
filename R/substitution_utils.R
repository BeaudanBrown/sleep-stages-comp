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

make_lmtp_shift <- function(from, to, duration, comp_limits) {
  function(data, trt) {
    dt <- as.data.table(data)
    can_substitute <- compute_substitution_mask(
      dt = dt,
      from = from,
      to = to,
      duration = duration,
      comp_limits = comp_limits
    )

    dt[[from]] <- dt[[from]] - (can_substitute * duration)
    dt[[to]] <- dt[[to]] + (can_substitute * duration)

    ilr_vars <- make_ilrs(dt)
    dt[, (ilr_names) := ilr_vars]

    as.data.frame(dt[, trt, with = FALSE], check.names = FALSE)
  }
}

apply_substitution <- function(dt, from_var, to_var, duration, comp_limits) {
  dt <- as.data.table(dt)
  can_substitute <- compute_substitution_mask(
    dt = dt,
    from = from_var,
    to = to_var,
    duration = duration,
    comp_limits = comp_limits
  )

  sub <- copy(dt)
  sub[[from_var]] <- sub[[from_var]] - (can_substitute * duration)
  sub[[to_var]] <- sub[[to_var]] + (can_substitute * duration)
  sub[["substituted"]] <- can_substitute

  ilr_vars <- make_ilrs(sub)
  sub[, (ilr_names) := ilr_vars]

  sub
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

  risk_dt[, `:=`(
    from = from,
    to = to,
    duration = duration,
    n_intervened = sum(sub_dt$substituted),
    n_total = nrow(sub_dt)
  )]

  merge(
    baseline_dt,
    risk_dt,
    by = "timegroup"
  )
}
