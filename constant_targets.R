constant_targets <- list(
  tar_target(comp_vars, c("n1", "n2", "n3", "waso", "rem")),
  tar_target(
    stage_labels,
    c(
      n1_s2 = "N1",
      n2_s2 = "N2",
      n3_s2 = "N3",
      waso_s2 = "WASO",
      rem_s2 = "REM"
    )
  ),
  tar_target(event_var, "dem_or_mci_status"),
  tar_target(event_date, "dem_or_mci_date"),
  tar_target(ilr_base, get_sbp()),
  tar_target(
    comparison_settings,
    list(
      substitution_durations = seq(-60, 60, by = 15),
      duration_limit = 60L,
      points_per_direction = 4L,
      ratio_threshold = 0.75,
      summary_output_cols = c(
        "from",
        "to",
        "duration",
        "ratio_substituted",
        "mean_risk_ratio",
        "lower_ci",
        "upper_ci"
      )
    )
  )
)
