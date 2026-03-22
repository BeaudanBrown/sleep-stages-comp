comparison_substitution_durations <- function() {
  seq(-60, 60, by = 15)
}

comparison_duration_limit <- function() {
  60L
}

comparison_points_per_direction <- function() {
  4L
}

comparison_substitution_grid <- function() {
  make_substitution_grid(
    durations = comparison_substitution_durations(),
    directed = FALSE
  )
}

compute_directional_support_frontiers <- function(
  dt,
  comp_limits,
  ratio_threshold = comparison_ratio_threshold(),
  max_minutes = comparison_duration_limit()
) {
  pairs <- make_substitution_grid(durations = 0, directed = TRUE)[, !"duration"]
  unique(pairs)[,
    .(
      max_supported_minutes = compute_directional_support_frontier(
        dt = dt,
        from = from,
        to = to,
        comp_limits = comp_limits,
        ratio_threshold = ratio_threshold,
        max_minutes = max_minutes
      )
    ),
    by = .(from, to)
  ]
}

combine_imputation_support_frontiers <- function(frontier_dt_list) {
  frontier_dt <- data.table::rbindlist(
    frontier_dt_list,
    use.names = TRUE,
    fill = TRUE
  )
  frontier_dt[,
    .(
      max_supported_minutes = min(max_supported_minutes)
    ),
    by = .(from, to)
  ]
}

select_supported_duration_points <- function(
  max_supported_minutes,
  points_per_direction = comparison_points_per_direction()
) {
  if (
    !is.numeric(max_supported_minutes) || length(max_supported_minutes) != 1L
  ) {
    stop("max_supported_minutes must be a single numeric value.", call. = FALSE)
  }

  max_supported_minutes <- as.integer(floor(max_supported_minutes))
  if (max_supported_minutes <= 0L) {
    return(integer())
  }

  raw_points <- round(seq(
    from = max_supported_minutes / points_per_direction,
    to = max_supported_minutes,
    length.out = points_per_direction
  ))

  unique(as.integer(raw_points[raw_points > 0]))
}

build_support_aware_substitution_grid <- function(
  support_frontiers,
  points_per_direction = comparison_points_per_direction()
) {
  pair_dt <- make_substitution_grid(durations = 0, directed = FALSE)[,
    !"duration"
  ]
  support_dt <- data.table::as.data.table(support_frontiers)

  pair_dt[,
    .(
      duration = list({
        pos_max <- support_dt[
          from == .BY$from & to == .BY$to,
          max_supported_minutes
        ]
        neg_max <- support_dt[
          from == .BY$to & to == .BY$from,
          max_supported_minutes
        ]

        if (length(pos_max) == 0L) {
          pos_max <- 0L
        }
        if (length(neg_max) == 0L) {
          neg_max <- 0L
        }

        pos_points <- select_supported_duration_points(
          pos_max,
          points_per_direction
        )
        neg_points <- -rev(select_supported_duration_points(
          neg_max,
          points_per_direction
        ))

        unique(c(neg_points, 0L, pos_points))
      })
    ),
    by = .(from, to)
  ][,
    .(duration = unlist(duration)),
    by = .(from, to)
  ]
}

comparison_treatment_cols <- function() {
  ilr_names
}

comparison_ratio_threshold <- function() {
  0.75
}

comparison_summary_output_cols <- function() {
  c(
    "from",
    "to",
    "duration",
    "ratio_substituted",
    "mean_risk_ratio",
    "lower_ci",
    "upper_ci"
  )
}

build_comparison_contract <- function(
  dt,
  substitutions = comparison_substitution_grid()
) {
  sleep_history_covars <- required_sleep_history_covars(dt)
  sleep_history_spline_covars <- required_sleep_history_spline_covars(dt)
  confounder_main_effects <- provisional_confounder_main_effects(dt)

  list(
    substitutions = substitutions,
    trt_cols = comparison_treatment_cols(),
    stage_labels = stage_labels,
    ratio_threshold = comparison_ratio_threshold(),
    sleep_history_covars = sleep_history_covars,
    sleep_history_spline_covars = sleep_history_spline_covars,
    confounder_main_effects = confounder_main_effects,
    baseline_covars = unique(c(
      sleep_history_covars,
      confounder_main_effects
    )),
    summary_output_cols = comparison_summary_output_cols()
  )
}
