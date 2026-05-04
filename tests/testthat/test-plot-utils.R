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

test_that("normalize_substitution_plot_summary enforces the shared comparison schema", {
  dt <- data.table::data.table(
    from = "n1_s2",
    to = "n2_s2",
    duration = 15,
    ratio_substituted = 0.8,
    mean_risk_ratio = 0.98,
    lower_ci = 0.95,
    upper_ci = 1.01,
    extra_col = "ignored"
  )

  normalized <- normalize_substitution_plot_summary(dt, method = "bootstrap")

  expect_equal(
    names(normalized),
    c(comparison_summary_output_cols(), "method")
  )
  expect_equal(normalized$method, "bootstrap")

  expect_error(normalize_substitution_plot_summary(dt[, !"upper_ci"]))
})

test_that("method wrappers render identical shared comparison plots", {
  dt <- data.table::data.table(
    from = c("n1_s2", "n1_s2", "n2_s2", "n2_s2"),
    to = c("n2_s2", "n2_s2", "n3_s2", "n3_s2"),
    duration = c(15, 30, 15, 30),
    ratio_substituted = c(0.8, 0.7, 0.9, 1.0),
    mean_risk_ratio = c(0.98, 0.5, 1.12, 1.08),
    lower_ci = c(0.95, 0.4, 1.05, 1.02),
    upper_ci = c(1.01, 0.6, 1.2, 1.15)
  )

  plot_boot <- make_bootstrap_substitution_plots(dt, ratio_threshold = 0.75)
  plot_lmtp <- make_lmtp_substitution_plots(dt, ratio_threshold = 0.75)

  expect_equal(nrow(plot_boot), 2L)
  expect_equal(nrow(plot_lmtp), 2L)

  boot_build <- ggplot2::ggplot_build(plot_boot$plot[[1]])
  lmtp_build <- ggplot2::ggplot_build(plot_lmtp$plot[[1]])

  boot_scales <- boot_build$layout$panel_params[[1]]
  lmtp_scales <- lmtp_build$layout$panel_params[[1]]

  expect_equal(boot_scales$y.range, lmtp_scales$y.range)
  expect_equal(boot_scales$x.range, lmtp_scales$x.range)
  expect_equal(
    plot_boot$plot[[1]]$labels$title,
    plot_lmtp$plot[[1]]$labels$title
  )
  expect_equal(
    plot_boot$plot[[1]]$labels$subtitle,
    plot_lmtp$plot[[1]]$labels$subtitle
  )
  expect_equal(plot_boot$plot[[1]]$labels$y, "Risk ratio")
  expect_equal(plot_lmtp$plot[[1]]$labels$y, "Risk ratio")
  expect_equal(
    length(plot_boot$plot[[1]]$layers),
    length(plot_lmtp$plot[[1]]$layers)
  )
})

test_that("make_substitution_plots uses bidirectional titles and direction guides", {
  dt <- data.table::data.table(
    from = c("n1_s2", "n1_s2"),
    to = c("n2_s2", "n2_s2"),
    duration = c(-15, 15),
    ratio_substituted = c(0.8, 0.9),
    mean_risk_ratio = c(1.02, 0.98),
    lower_ci = c(0.97, 0.94),
    upper_ci = c(1.07, 1.02)
  )

  plot_dt <- make_substitution_plots(dt, ratio_threshold = 0.75)
  plot_obj <- plot_dt$plot[[1]]
  plot_build <- ggplot2::ggplot_build(plot_obj)
  labels <- unique(unlist(lapply(plot_build$data, function(layer) {
    if ("label" %in% names(layer)) {
      layer$label
    } else {
      NULL
    }
  })))

  expect_equal(
    plot_obj$labels$title,
    "Reallocate minutes between N1 and N2"
  )
  expect_true(all(c("N1 <- N2", "N1 -> N2") %in% labels))
})

test_that("make_substitution_plots applies shared scales across all pairs", {
  dt <- data.table::data.table(
    from = c("n1_s2", "n1_s2", "n2_s2", "n2_s2"),
    to = c("n2_s2", "n2_s2", "n3_s2", "n3_s2"),
    duration = c(15, 30, 15, 30),
    ratio_substituted = c(0.8, 0.7, 0.9, 1.0),
    mean_risk_ratio = c(0.98, 0.5, 1.12, 1.08),
    lower_ci = c(0.95, 0.4, 1.05, 1.02),
    upper_ci = c(1.01, 0.6, 1.2, 1.15)
  )

  plot_dt <- make_substitution_plots(dt, ratio_threshold = 0.75)
  scales_a <- ggplot2::ggplot_build(plot_dt$plot[[1]])$layout$panel_params[[1]]
  scales_b <- ggplot2::ggplot_build(plot_dt$plot[[2]])$layout$panel_params[[1]]

  expect_equal(scales_a$y.range, scales_b$y.range)
  expect_equal(scales_a$x.range, scales_b$x.range)
})
