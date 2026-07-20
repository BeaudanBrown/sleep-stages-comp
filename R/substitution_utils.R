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

compute_substitution_policy <- function(dt, from, to, duration, comp_hull) {
  if (duration == 0) {
    return(data.table::data.table(
      substituted = rep(TRUE, nrow(dt)),
      applied_duration = rep(0, nrow(dt))
    ))
  }

  if (!is_substitution_mask_table(comp_hull)) {
    stop(
      "Substitution support must be supplied as a Julia-generated mask table.",
      call. = FALSE
    )
  }

  lookup_substitution_policy(
    dt = dt,
    substitution_masks = comp_hull,
    from = from,
    to = to,
    duration = duration
  )
}

compute_substitution_mask <- function(dt, from, to, duration, comp_hull) {
  compute_substitution_policy(
    dt,
    from,
    to,
    duration,
    comp_hull
  )[["substituted"]]
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
  policy <- compute_substitution_policy(
    dt = dt,
    from = from,
    to = to,
    duration = duration,
    comp_hull = comp_hull
  )

  shifted_dt <- copy(dt)
  shifted_dt[[from]] <- shifted_dt[[from]] - policy$applied_duration
  shifted_dt[[to]] <- shifted_dt[[to]] + policy$applied_duration
  shifted_dt[["substituted"]] <- policy$substituted
  shifted_dt[["applied_duration"]] <- policy$applied_duration

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
  shifted_dt <- as.data.table(shifted_dt)
  substituted <- shifted_dt[["substituted"]]

  list(
    n_intervened = sum(substituted),
    n_total = length(substituted),
    ratio_substituted = mean(substituted),
    mean_applied_duration = mean(shifted_dt[["applied_duration"]])
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
