test_that("comparison_direction classifies risk-ratio direction around one", {
  expect_equal(
    comparison_direction(c(0.9, 1, 1.1, NA_real_)),
    c(-1L, 0L, 1L, NA_integer_)
  )
})

test_that("normalize_method_comparison_summary accepts point summaries without CIs", {
  dt <- data.table::data.table(
    from = "n1_s2",
    to = "n2_s2",
    duration = 15,
    ratio_substituted = 0.9,
    mean_risk_ratio = 0.95
  )

  normalized <- normalize_method_comparison_summary(dt)

  expect_equal(
    names(normalized),
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
  expect_true(is.na(normalized$lower_ci))
  expect_true(is.na(normalized$upper_ci))
})

test_that("join_method_substitution_summaries flags reversed directions", {
  pooled <- data.table::data.table(
    from = c("n1_s2", "n2_s2"),
    to = c("n2_s2", "n3_s2"),
    duration = c(15, 30),
    ratio_substituted = c(0.9, 0.8),
    mean_risk_ratio = c(0.9, 1.1),
    lower_ci = c(0.85, 1.02),
    upper_ci = c(0.96, 1.18)
  )
  lmtp <- data.table::data.table(
    from = c("n1_s2", "n2_s2"),
    to = c("n2_s2", "n3_s2"),
    duration = c(15, 30),
    ratio_substituted = c(0.92, 0.7),
    mean_risk_ratio = c(1.08, 1.05),
    lower_ci = c(1.01, 0.98),
    upper_ci = c(1.16, 1.12)
  )

  joined <- join_method_substitution_summaries(
    pooled_summary = pooled,
    lmtp_summary = lmtp,
    ratio_threshold = 0.75
  )

  expect_equal(nrow(joined), 2L)
  expect_true(joined[1, direction_reversed])
  expect_false(joined[1, same_direction])
  expect_true(joined[1, shared_plot_eligible])
  expect_true(joined[2, pooled_only_plot_eligible])
  expect_false(joined[2, lmtp_only_plot_eligible])
})

test_that("comparison summary and debug extraction prioritize reversals", {
  comparison_dt <- data.table::data.table(
    from = c("n1_s2", "n2_s2", "n3_s2"),
    to = c("n2_s2", "n3_s2", "rem_s2"),
    duration = c(15, 30, -15),
    pooled_mean_risk_ratio = c(0.9, 1.1, 0.97),
    pooled_ratio_substituted = c(0.9, 0.8, 0.6),
    pooled_lower_ci = c(0.85, 1.02, 0.9),
    pooled_upper_ci = c(0.96, 1.18, 1.04),
    lmtp_mean_risk_ratio = c(1.08, 1.05, 0.94),
    lmtp_ratio_substituted = c(0.92, 0.7, 0.9),
    lmtp_lower_ci = c(1.01, 0.98, 0.88),
    lmtp_upper_ci = c(1.16, 1.12, 1.02),
    pooled_direction = c(-1L, 1L, -1L),
    lmtp_direction = c(1L, 1L, -1L),
    same_direction = c(FALSE, TRUE, TRUE),
    direction_reversed = c(TRUE, FALSE, FALSE),
    abs_risk_ratio_gap = c(0.18, 0.05, 0.03),
    abs_log_risk_ratio_gap = c(
      abs(log(0.9) - log(1.08)),
      abs(log(1.1) - log(1.05)),
      abs(log(0.97) - log(0.94))
    ),
    shared_plot_eligible = c(TRUE, FALSE, FALSE),
    pooled_only_plot_eligible = c(FALSE, TRUE, FALSE),
    lmtp_only_plot_eligible = c(FALSE, FALSE, TRUE)
  )

  summary_dt <- summarize_method_comparison(comparison_dt)
  debug_dt <- extract_comparison_debug_rows(comparison_dt, n = 2L)

  expect_equal(summary_dt$n_rows, 3L)
  expect_equal(summary_dt$n_direction_reversed, 1L)
  expect_equal(summary_dt$n_shared_plot_eligible, 1L)
  expect_equal(summary_dt$pooled_only_plot_eligible, 1L)
  expect_equal(summary_dt$lmtp_only_plot_eligible, 1L)
  expect_equal(nrow(debug_dt), 2L)
  expect_true(debug_dt[1, direction_reversed])
})
