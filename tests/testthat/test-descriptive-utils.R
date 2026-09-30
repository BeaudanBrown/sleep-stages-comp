test_that("composition summaries exclude WASO and preserve counts and REM ties", {
  dt <- data.table(
    n1_s2 = 40,
    n2_s2 = 160,
    n3_s2 = 80,
    rem_s2 = rep(seq(20, 100, by = 20), each = 4),
    waso_s2 = 30
  )
  summary <- summarize_composition_distribution(dt)
  expect_equal(sum(summary$counts$n), nrow(dt))
  expect_equal(summary$counts[, sum(n), by = quintile]$V1, rep(4L, 5))
  expect_equal(summary$rem_breaks[c(1, 6)], c(20 / 300, 100 / 380))
  scaled <- copy(dt)
  scaled[,
    c("n1_s2", "n2_s2", "n3_s2", "rem_s2") := lapply(
      .SD,
      \(x) x * 2
    ),
    .SDcols = c("n1_s2", "n2_s2", "n3_s2", "rem_s2")
  ]
  scaled[, waso_s2 := 500]
  expect_equal(summarize_composition_distribution(scaled), summary)

  tied <- copy(dt)[, rem_s2 := 80]
  expect_equal(sum(summarize_composition_distribution(tied)$counts$n), nrow(dt))
})

test_that("composition plot contains five scenes with aggregate markers only", {
  dt <- data.table(
    n1_s2 = 40,
    n2_s2 = 160,
    n3_s2 = 80,
    rem_s2 = rep(seq(20, 100, by = 20), each = 4),
    PID = seq_len(20)
  )
  plot <- plotly::plotly_build(plot_composition_distribution(dt))
  scenes <- c("scene", paste0("scene", 2:5))
  expect_true(all(scenes %in% names(plot$x$layout)))
  markers <- Filter(\(trace) identical(trace$mode, "markers"), plot$x$data)
  expect_length(markers, 5L)
  expect_equal(sum(vapply(markers, \(trace) length(trace$x), integer(1))), 5L)
  expect_false(grepl('"PID"', plotly::plotly_json(plot, jsonedit = FALSE)))
})
