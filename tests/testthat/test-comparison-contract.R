test_that("comparison contract centralizes shared comparison settings", {
  dt <- make_test_model_dt()
  cuts <- make_cuts(dt)
  surv_dt <- expand_surv_dt(dt, cuts)
  wide <- make_surv_wide(surv_dt)
  substitutions <- data.table::data.table(
    from = c("n1_s2", "n1_s2", "n1_s2"),
    to = c("n2_s2", "n2_s2", "n2_s2"),
    duration = c(-15L, 0L, 15L)
  )

  contract <- build_comparison_contract(wide, substitutions = substitutions)

  expect_named(
    contract,
    c(
      "substitutions",
      "trt_cols",
      "stage_labels",
      "ratio_threshold",
      "sleep_history_covars",
      "sleep_history_spline_covars",
      "confounder_main_effects",
      "baseline_covars",
      "summary_output_cols"
    )
  )
  expect_equal(contract$trt_cols, ilr_names)
  expect_equal(contract$stage_labels, stage_labels)
  expect_equal(contract$ratio_threshold, 0.75)
  expect_equal(contract$substitutions, substitutions)
  expect_equal(
    contract$summary_output_cols,
    c(
      "from",
      "to",
      "duration",
      "ratio_substituted",
      "mean_risk_ratio",
      "lower_ci",
      "upper_ci"
    )
  )
  expect_equal(
    contract$sleep_history_spline_covars,
    c("n1", "n2", "n3", "rem", "slp_time_s2")
  )
  expect_true(all(
    c("n1", "n2", "n3", "rem", "slp_time_s2", "s1_incomplete") %in%
      contract$baseline_covars
  ))
})
