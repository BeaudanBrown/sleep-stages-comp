test_that("continuous bootstrap summaries cover both estimands by substitution", {
  estimates <- data.table::CJ(
    duration = c(15L, 30L),
    B = 1:4,
    imputation_id = c("1", "2")
  )
  estimates[, `:=`(
    from = "n2_s2",
    to = "n3_s2",
    outcome = "outcome_value",
    pred = 10 + duration / 10 + B / 5 + as.integer(imputation_id) / 20,
    mean_difference = duration / 100 + B / 50 - as.integer(imputation_id) / 100
  )]
  estimates[
    B == 4L,
    `:=`(
      pred = NA_real_,
      mean_difference = NA_real_
    )
  ]

  summary_dt <- summary_bootstrap_intervals(estimates)

  expect_equal(nrow(summary_dt), 4L)
  expect_named(
    summary_dt,
    c(
      "from",
      "to",
      "duration",
      "outcome",
      "parameter",
      "estimate",
      "se",
      "lower",
      "upper",
      "df"
    )
  )
  expect_false("exposure" %in% names(summary_dt))
  expect_equal(
    sort(unique(summary_dt$parameter)),
    c("mean_difference", "pred")
  )
  expect_equal(
    summary_dt[, .N, by = .(from, to, duration, outcome)]$N,
    rep(2L, 2L)
  )
  expect_true(all(is.finite(summary_dt$estimate)))
  expect_true(all(summary_dt$lower < summary_dt$estimate))
  expect_true(all(summary_dt$upper > summary_dt$estimate))

  direct_data <- data.table::copy(estimates[duration == 15L])
  expected <- bootstrap_intervals(direct_data, "pred")
  observed <- summary_dt[duration == 15L & parameter == "pred"]

  expect_equal(observed$estimate, expected$estimate)
  expect_equal(observed$se, expected$se)
  expect_equal(observed$lower, expected$lower)
  expect_equal(observed$upper, expected$upper)
})

test_that("bootstrap intervals handle a zero-variance identity contrast", {
  estimates <- data.table::data.table(
    B = rep(1:4, each = 2),
    mean_difference = 0
  )

  interval <- bootstrap_intervals(estimates, "mean_difference")

  expect_equal(interval$estimate, 0)
  expect_equal(interval$se, 0)
  expect_equal(interval$lower, 0)
  expect_equal(interval$upper, 0)
  expect_equal(interval$df, Inf)
})
