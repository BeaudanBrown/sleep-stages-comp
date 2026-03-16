test_that("apply_substitution preserves composition totals and changes only the targeted parts", {
  dt <- make_test_comp_dt()
  limits <- make_test_comp_limits()

  shifted <- suppressWarnings(apply_substitution(
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

test_that("apply_substitution leaves infeasible rows unchanged and flags them", {
  dt <- make_test_comp_dt()
  limits <- make_test_comp_limits()
  dt[1, n2_s2 := 125]

  shifted <- suppressWarnings(apply_substitution(
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

test_that("apply_substitution handles negative durations as reverse shifts", {
  dt <- make_test_comp_dt()
  limits <- make_test_comp_limits()

  shifted <- suppressWarnings(apply_substitution(
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

  shifted <- suppressWarnings(apply_substitution(
    dt,
    "n2_s2",
    "n3_s2",
    0,
    limits
  ))

  expect_equal(shifted[, ..comp_vars], dt[, ..comp_vars])
  expect_true(all(shifted$substituted))
})

test_that("make_lmtp_shift matches apply_substitution on treatment columns", {
  dt <- make_test_comp_dt()
  dt[, extra_covariate := c(1, 2, 3, 4)]
  limits <- make_test_comp_limits()
  trt <- ilr_names

  shift_fn <- make_lmtp_shift("n2_s2", "n3_s2", 15, limits)
  shifted_trt <- suppressWarnings(shift_fn(dt, trt))
  expected <- suppressWarnings(apply_substitution(
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

test_that("compute_shifted_exposures is the canonical source for apply_substitution", {
  dt <- make_test_comp_dt()
  limits <- make_test_comp_limits()

  shifted <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    15,
    limits
  ))
  expected <- suppressWarnings(apply_substitution(
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

  shifted <- suppressWarnings(apply_substitution(
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

test_that("make_lmtp_shift handles negative durations consistently with apply_substitution", {
  dt <- make_test_comp_dt()
  limits <- make_test_comp_limits()
  trt <- ilr_names

  shift_fn <- make_lmtp_shift("n2_s2", "n3_s2", -10, limits)
  shifted_trt <- suppressWarnings(shift_fn(dt, trt))
  expected <- suppressWarnings(apply_substitution(
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
  expected <- suppressWarnings(apply_substitution(
    dt,
    "n2_s2",
    "n3_s2",
    -10,
    limits
  ))

  expect_equal(as.data.table(shifted_trt), expected[, ..trt])
})
