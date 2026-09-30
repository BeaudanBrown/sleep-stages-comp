test_that("pair direction guide keeps the destination stage above the arrow", {
  guide <- make_risk_plot_direction("N1", "N3")

  expect_equal(guide$children$left_less_label$label, "Less N3")
  expect_equal(guide$children$right_more_label$label, "More N3")
  expect_equal(as.numeric(guide$children$left_less_label$y), -0.17)
  expect_equal(as.numeric(guide$children$right_more_label$y), -0.17)
  expect_equal(as.numeric(guide$children$left_more_label$y), -0.26)
  expect_equal(as.numeric(guide$children$right_less_label$y), -0.26)
})

test_that("pair orientation puts additions to N3 on positive minutes", {
  dt <- data.table::data.table(
    timegroup = 2,
    from = "n3_s2",
    to = "rem_s2",
    duration = c(-30, 0, 30),
    RR = c(0.95, 1, 1.05),
    RR_lower = c(0.90, 0.95, 1.00),
    RR_upper = c(1.00, 1.05, 1.10)
  )

  oriented <- orient_risk_summary_pair(dt, right_stage = "n3_s2")

  expect_equal(unique(oriented$from), "rem_s2")
  expect_equal(unique(oriented$to), "n3_s2")
  expect_equal(oriented$duration, c(30, 0, -30))
  expect_equal(oriented[duration == 30]$RR, 0.95)
})

test_that("continuous pair plot uses a zero null and mean-difference intervals", {
  dt <- data.table::data.table(
    from = "n3_s2",
    to = "rem_s2",
    duration = c(-30, 0, 30),
    outcome = "Hippo_s2",
    parameter = "mean_difference",
    estimate = c(-0.2, 0, 0.3),
    lower = c(-0.3, 0, 0.2),
    upper = c(-0.1, 0, 0.4)
  )
  output_file <- tempfile(fileext = ".png")

  plot <- plot_continuous_summary_pair(
    dt,
    labels = c(n3_s2 = "N3", rem_s2 = "REM"),
    right_stage = "n3_s2",
    output_file = output_file
  )
  built <- ggplot2::ggplot_build(plot)

  expect_true(file.exists(output_file))
  expect_equal(built$data[[1]]$yintercept, 0)
  expect_equal(built$data[[3]]$x, c(-30, 0, 30))
  expect_equal(built$data[[3]]$y, c(0.3, 0, -0.2))
  expect_equal(plot$labels$title, "Hippo_s2")
  expect_equal(plot$labels$y, "Mean difference")
})
