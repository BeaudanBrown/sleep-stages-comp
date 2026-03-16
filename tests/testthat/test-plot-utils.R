test_that("compute_substitution_plot_scales uses thresholded global ranges", {
  dt <- data.table::data.table(
    from = c("n1_s2", "n1_s2", "n2_s2", "n2_s2"),
    to = c("n2_s2", "n2_s2", "n3_s2", "n3_s2"),
    duration = c(15, 30, 15, 30),
    ratio_substituted = c(0.8, 0.7, 0.9, 1.0),
    mean_risk_ratio = c(0.98, 0.5, 1.12, 1.08),
    lower_ci = c(0.95, 0.4, 1.05, 1.02),
    upper_ci = c(1.01, 0.6, 1.2, 1.15)
  )

  scales <- compute_substitution_plot_scales(dt, ratio_threshold = 0.75)

  expect_equal(scales$rs_limits, c(0.75, 1))
  expect_equal(scales$rr_limits, c(0.95, 1.2))
})

test_that("make_lmtp_substitution_plots applies shared scales and threshold filtering", {
  dt <- data.table::data.table(
    from = c("n1_s2", "n1_s2", "n2_s2", "n2_s2"),
    to = c("n2_s2", "n2_s2", "n3_s2", "n3_s2"),
    duration = c(15, 30, 15, 30),
    ratio_substituted = c(0.8, 0.7, 0.9, 1.0),
    mean_risk_ratio = c(0.98, 0.5, 1.12, 1.08),
    lower_ci = c(0.95, 0.4, 1.05, 1.02),
    upper_ci = c(1.01, 0.6, 1.2, 1.15)
  )

  plot_dt <- make_lmtp_substitution_plots(dt, ratio_threshold = 0.75)

  expect_equal(nrow(plot_dt), 2L)

  scales_a <- ggplot2::ggplot_build(plot_dt$plot[[1]])$layout$panel_params[[1]]
  scales_b <- ggplot2::ggplot_build(plot_dt$plot[[2]])$layout$panel_params[[1]]

  expect_equal(scales_a$y.range, scales_b$y.range)
  expect_equal(scales_a$x.range, scales_b$x.range)
})
