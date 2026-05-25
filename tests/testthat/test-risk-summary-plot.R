test_that("orient_risk_summary_additions expresses signed pairs by added stage", {
  dt <- data.table::data.table(
    timegroup = 2,
    from = c(rep("n1_s2", 3), rep("rem_s2", 3)),
    to = c(rep("rem_s2", 3), rep("waso_s2", 3)),
    duration = c(-15, 0, 15, -30, 0, 30),
    RR = 1,
    RR_lower = 0.9,
    RR_upper = 1.1
  )

  oriented <- orient_risk_summary_additions(dt)
  rem_plot_dt <- oriented[to == "rem_s2"]

  expect_setequal(unique(rem_plot_dt$from), c("n1_s2", "waso_s2"))
  expect_true(all(rem_plot_dt$duration >= 0))
  expect_equal(rem_plot_dt[from == "n1_s2"]$duration, c(0, 15))
  expect_equal(rem_plot_dt[from == "waso_s2"]$duration, c(0, 30))
})

test_that("plot_risk_summary_to facets source stages at the final timegroup", {
  dt <- data.table::data.table(
    timegroup = c(rep(1, 5), rep(2, 5)),
    from = rep(c("n1_s2", "n1_s2", "n2_s2", "n2_s2", "n2_s2"), 2),
    to = "rem_s2",
    duration = rep(c(0, 15, 0, 30, 60), 2),
    RR = c(rep(1.20, 5), 1.00, 0.95, 1.00, 0.98, 0.93),
    RR_lower = c(rep(1.10, 5), 0.97, 0.91, 0.97, 0.94, 0.89),
    RR_upper = c(rep(1.30, 5), 1.03, 1.00, 1.03, 1.02, 0.97)
  )

  plot <- plot_risk_summary_to(
    dt,
    labels = c(n1_s2 = "N1", n2_s2 = "N2", rem_s2 = "REM"),
    output_file = tempfile(fileext = ".png")
  )
  built <- ggplot2::ggplot_build(plot)
  line_data <- built$data[[3]]
  x_ranges <- lapply(built$layout$panel_params, function(panel) panel$x.range)

  expect_equal(line_data$y, c(1.00, 0.95, 1.00, 0.98, 0.93))
  expect_equal(x_ranges, list(c(0, 15), c(0, 60)))
  expect_equal(nrow(built$layout$layout), 2)
  expect_true(plot$facet$params$free$x)
  expect_equal(plot$labels$title, "Adding time to REM")
  expect_equal(plot$labels$x, "Minutes added to REM")
  expect_equal(plot$labels$y, "Risk ratio")
})

test_that("plot_risk_summary_to uses readable panel-specific minute breaks", {
  dt <- data.table::data.table(
    timegroup = 2,
    from = c(rep("n2_s2", 3), rep("n3_s2", 3)),
    to = "rem_s2",
    duration = c(0, 15, 35, 0, 30, 60),
    RR = c(1.00, 0.99, 0.97, 1.00, 0.98, 0.96),
    RR_lower = c(0.98, 0.95, 0.93, 0.98, 0.94, 0.92),
    RR_upper = c(1.02, 1.03, 1.01, 1.02, 1.02, 1.00)
  )

  plot <- plot_risk_summary_to(dt, output_file = tempfile(fileext = ".png"))
  built <- ggplot2::ggplot_build(plot)

  expect_equal(built$layout$panel_params[[1]]$x.range, c(0, 35))
  expect_equal(
    built$layout$panel_params[[1]]$x$get_breaks(),
    c(0, 10, 20, 30, 35)
  )
  expect_equal(built$layout$panel_params[[2]]$x.range, c(0, 60))
  expect_equal(
    built$layout$panel_params[[2]]$x$get_breaks(),
    c(0, 20, 40, 60)
  )
  expect_equal(built$layout$panel_params[[1]]$y.range, c(0.7, 1.4))
  expect_equal(
    built$layout$panel_params[[1]]$y$get_breaks(),
    seq(0.7, 1.4, by = 0.1)
  )
  expect_equal(plot$scales$get_scales("y")$trans$name, "identity")
})

test_that("make_risk_summary_x_breaks includes zero and supported maximum", {
  expect_equal(
    make_risk_summary_x_breaks(c(0, 35)),
    c(0, 10, 20, 30, 35)
  )
  expect_equal(
    make_risk_summary_x_breaks(c(0, 60)),
    c(0, 20, 40, 60)
  )
})
