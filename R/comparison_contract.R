comparison_substitution_durations <- function() {
  seq(-60, 60, by = 15)
}

comparison_substitution_grid <- function() {
  make_substitution_grid(
    durations = comparison_substitution_durations(),
    directed = FALSE
  )
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

build_comparison_contract <- function(dt) {
  sleep_history_covars <- required_sleep_history_covars(dt)
  sleep_history_spline_covars <- required_sleep_history_spline_covars(dt)
  confounder_main_effects <- provisional_confounder_main_effects(dt)

  list(
    substitutions = comparison_substitution_grid(),
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
