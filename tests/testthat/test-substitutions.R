test_that("compute_shifted_exposures preserves totals and changes targeted parts", {
  dt <- make_test_comp_dt()
  limits <- make_test_comp_limits()

  shifted <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    15,
    limits
  ))

  expect_equal(comp_total(shifted), comp_total(dt))
  expect_equal(shifted$n2_s2, dt$n2_s2 - 15)
  expect_equal(shifted$n3_s2, dt$n3_s2 + 15)
  untouched <- setdiff(comp_vars, c("n2_s2", "n3_s2"))
  for (col in untouched) {
    expect_equal(shifted[[col]], dt[[col]])
  }
  expect_true(all(shifted$substituted))
  expect_named(shifted[, ..ilr_names], ilr_names)
})

test_that("compute_shifted_exposures leaves infeasible rows unchanged", {
  dt <- make_test_comp_dt()
  limits <- make_test_comp_limits()
  dt[1, n2_s2 := 125]

  shifted <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    15,
    limits
  ))

  expect_false(shifted$substituted[1])
  expect_equal(shifted[1, ..comp_vars], dt[1, ..comp_vars])
  expect_true(all(shifted$substituted[-1]))
})

test_that("compute_shifted_exposures handles negative durations as reverse shifts", {
  dt <- make_test_comp_dt()
  limits <- make_test_comp_limits()

  shifted <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    -10,
    limits
  ))

  expect_equal(comp_total(shifted), comp_total(dt))
  expect_equal(shifted$n2_s2, dt$n2_s2 + 10)
  expect_equal(shifted$n3_s2, dt$n3_s2 - 10)
  expect_true(all(shifted$substituted))
})

test_that("zero-duration substitutions mark every row as substituted", {
  dt <- make_test_comp_dt()
  limits <- make_test_comp_limits()

  dt[1, n2_s2 := limits$n2_s2$upper + 5]
  dt[2, n2_s2 := limits$n2_s2$lower - 5]

  shifted <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    0,
    limits
  ))

  expect_equal(shifted[, ..comp_vars], dt[, ..comp_vars])
  expect_true(all(shifted$substituted))
})

test_that("make_lmtp_shift matches shifted exposure treatment columns", {
  dt <- make_test_comp_dt()
  dt[, extra_covariate := c(1, 2, 3, 4)]
  limits <- make_test_comp_limits()
  trt <- ilr_names

  shift_fn <- make_lmtp_shift("n2_s2", "n3_s2", 15, limits)
  shifted_trt <- suppressWarnings(shift_fn(dt, trt))
  expected <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    15,
    limits
  ))

  expect_s3_class(shifted_trt, "data.frame")
  expect_named(shifted_trt, trt)
  expect_equal(as.data.table(shifted_trt), expected[, ..trt])
})

test_that("apply_substitution remains a compatibility alias", {
  dt <- make_test_comp_dt()
  limits <- make_test_comp_limits()

  expected <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    15,
    limits
  ))
  shifted <- suppressWarnings(apply_substitution(
    dt,
    "n2_s2",
    "n3_s2",
    15,
    limits
  ))

  expect_equal(shifted, expected)
})

test_that("summarize_substitution_coverage returns consistent counts and ratios", {
  dt <- make_test_comp_dt()
  limits <- make_test_comp_limits()
  dt[1, n2_s2 := 125]

  shifted <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    15,
    limits
  ))
  coverage <- summarize_substitution_coverage(shifted)

  expect_equal(coverage$n_intervened, 3)
  expect_equal(coverage$n_total, 4)
  expect_equal(coverage$ratio_substituted, 0.75)
})

test_that("summarize_point_estimate_substitutions keeps final-time pooled estimates", {
  dt <- data.table::data.table(
    timegroup = c(1, 2),
    from = c("n2_s2", "n2_s2"),
    to = c("n3_s2", "n3_s2"),
    duration = c(15, 15),
    mean_risk_baseline = c(0.1, 0.2),
    mean_risk_substituted = c(0.11, 0.18),
    n_intervened = c(3, 3),
    n_total = c(4, 4)
  )

  summary_dt <- summarize_point_estimate_substitutions(dt)

  expect_equal(nrow(summary_dt), 1L)
  expect_equal(summary_dt$mean_risk_ratio, 0.18 / 0.2)
  expect_equal(summary_dt$ratio_substituted, 0.75)
})

test_that("average_imputation_substitution_risk averages substitution curves across imputations", {
  dt <- data.table::data.table(
    imputation_id = c("1", "1", "2", "2"),
    timegroup = c(1, 2, 1, 2),
    from = "n2_s2",
    to = "n3_s2",
    duration = 15,
    mean_risk_baseline = c(0.1, 0.2, 0.12, 0.24),
    mean_risk_substituted = c(0.11, 0.18, 0.132, 0.21),
    n_intervened = c(3, 3, 3, 3),
    n_total = c(4, 4, 4, 4)
  )

  averaged <- average_imputation_substitution_risk(dt)

  expect_equal(nrow(averaged), 2L)
  expect_equal(averaged$mean_risk_baseline, c(0.11, 0.22))
  expect_equal(averaged$mean_risk_substituted, c(0.121, 0.195))
  expect_equal(averaged$n_intervened, c(3, 3))
  expect_equal(averaged$n_total, c(4, 4))
})

test_that("combine_point_estimates_with_bootstrap_cis keeps pooled line and bootstrap interval", {
  point_dt <- data.table::data.table(
    from = "n2_s2",
    to = "n3_s2",
    duration = 15,
    mean_risk_ratio = 0.9,
    ratio_substituted = 0.8
  )
  boot_dt <- data.table::data.table(
    from = "n2_s2",
    to = "n3_s2",
    duration = 15,
    bootstrap_mean_risk_ratio = 0.92,
    lower_ci = 0.85,
    upper_ci = 1.01,
    bootstrap_ratio_substituted = 0.79
  )

  combined <- combine_point_estimates_with_bootstrap_cis(point_dt, boot_dt)

  expect_equal(combined$mean_risk_ratio, 0.9)
  expect_equal(combined$ratio_substituted, 0.8)
  expect_equal(combined$lower_ci, 0.85)
  expect_equal(combined$upper_ci, 1.01)
})

test_that("make_lmtp_shift handles negative durations consistently with apply_substitution", {
  dt <- make_test_comp_dt()
  limits <- make_test_comp_limits()
  trt <- ilr_names

  shift_fn <- make_lmtp_shift("n2_s2", "n3_s2", -10, limits)
  shifted_trt <- suppressWarnings(shift_fn(dt, trt))
  expected <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    -10,
    limits
  ))

  expect_equal(as.data.table(shifted_trt), expected[, ..trt])
})

test_that("make_lmtp_shift respects infeasibility for reverse shifts", {
  dt <- make_test_comp_dt()
  dt[1, `:=`(n2_s2 = 180, n3_s2 = 55)]
  limits <- make_test_comp_limits()
  trt <- ilr_names

  shift_fn <- make_lmtp_shift("n2_s2", "n3_s2", -10, limits)
  shifted_trt <- suppressWarnings(shift_fn(dt, trt))
  expected <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    -10,
    limits
  ))

  expect_equal(as.data.table(shifted_trt), expected[, ..trt])
})
