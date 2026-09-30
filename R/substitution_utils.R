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
