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
  tar_target(ideal_composition_grid_step, 10L),
  tar_target(
    ideal_composition_tst_values,
    {
      tst_minutes <- dt$n1_s2 + dt$n2_s2 + dt$n3_s2 + dt$rem_s2
      mean_tst <- c(
        mean(tst_minutes[tst_minutes < 6 * 60], na.rm = TRUE),
        mean(
          tst_minutes[tst_minutes >= 6 * 60 & tst_minutes <= 8 * 60],
          na.rm = TRUE
        )
      )
      # Exact subset matching requires TST values on the synthetic grid.
      round(mean_tst / ideal_composition_grid_step) * ideal_composition_grid_step
    }
  ),
  tar_target(ideal_composition_batch_size, 1000L),
  tar_target(ideal_composition_stability_splits, 10L),
  tar_target(
    ideal_composition_support_settings,
    list(
      k = 20L,
      quantile = 0.95
    )
  ),
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
