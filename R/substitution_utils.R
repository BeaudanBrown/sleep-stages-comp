make_substitution_grid <- function(durations, comp_vars, directed = TRUE) {
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

compute_substitution_mask <- function(dt, from, to, duration, comp_hull) {
  if (duration == 0) {
    return(rep(TRUE, nrow(dt)))
  }

  masks <- data.table::copy(data.table::as.data.table(comp_hull))
  if ("PID" %in% names(masks)) {
    masks[, PID := as.character(PID)]
  }

  from_value <- from
  to_value <- to
  duration_value <- as.integer(duration)

  mask_dt <- masks[
    masks[["from"]] == from_value &
      masks[["to"]] == to_value &
      masks[["duration"]] == duration_value
  ]

  as.logical(mask_dt[
    data.table::data.table(PID = as.character(dt$PID_original)),
    on = "PID",
    substituted,
    allow.cartesian = TRUE
  ])
}

compute_shifted_exposures <- function(
  dt,
  from,
  to,
  duration,
  comp_hull,
  comp_vars,
  ilr_base
) {
  dt <- as.data.table(dt)
  if (duration == 0) {
    shifted_dt <- copy(dt)
    shifted_dt[["substituted"]] <- TRUE
    return(shifted_dt)
  }

  can_substitute <- compute_substitution_mask(
    dt = dt,
    from = from,
    to = to,
    duration = duration,
    comp_hull = comp_hull
  )

  shifted_dt <- copy(dt)
  shifted_dt[[from]] <- shifted_dt[[from]] - (can_substitute * duration)
  shifted_dt[[to]] <- shifted_dt[[to]] + (can_substitute * duration)
  shifted_dt[["substituted"]] <- can_substitute

  ilr_vars <- make_ilrs(shifted_dt, comp_vars, ilr_base)
  ilr_names <- paste0("R", seq_len(length(comp_vars) - 1), "_s2")
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

  list(
    n_intervened = sum(substituted),
    n_total = length(substituted),
    ratio_substituted = mean(substituted)
  )
}

make_lmtp_shift <- function(
  from,
  to,
  duration,
  comp_hull,
  comp_vars,
  ilr_base
) {
  function(data, trt) {
    shifted_dt <- compute_shifted_exposures(
      dt = data,
      from = from,
      to = to,
      duration = duration,
      comp_hull = comp_hull,
      comp_vars = comp_vars,
      ilr_base = ilr_base
    )

    extract_shifted_treatment(shifted_dt, trt)
  }
}

apply_substitution <- function(dt, from_var, to_var, duration, comp_hull) {
  compute_shifted_exposures(
    dt = dt,
    from = from_var,
    to = to_var,
    duration = duration,
    comp_hull = comp_hull
  )
}

compute_substituted_risk <- function(
  dt,
  from,
  to,
  duration,
  comp_hull,
  fitted_models,
  timegroup_cuts,
  baseline_risk,
  comp_vars,
  ilr_base,
  event_var,
  event_date
) {
  sub_dt <- compute_shifted_exposures(
    dt,
    from,
    to,
    duration,
    comp_hull,
    comp_vars,
    ilr_base
  )

  risk_dt <- predict_risks(
    sub_dt,
    fitted_models,
    timegroup_cuts,
    event_var,
    event_date
  )
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
