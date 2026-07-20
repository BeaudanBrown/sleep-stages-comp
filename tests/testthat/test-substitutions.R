test_that("compute_shifted_exposures preserves totals and changes targeted parts", {
  dt <- make_test_comp_dt()
  hull <- make_test_comp_hull()

  shifted <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    15,
    hull
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

test_that("compute_shifted_exposures updates modeled SHHS-2 ILR columns", {
  comp_names <- c("n1_s2", "n2_s2", "n3_s2", "waso_s2", "rem_s2")
  model_ilr_names <- paste0("R", seq_len(length(comp_names) - 1L), "_s2")
  basis <- get_sbp()
  dt <- make_test_comp_dt()
  dt[, (model_ilr_names) := make_ilrs(dt, comp_names, basis)]
  original_ilrs <- data.table::copy(dt[, ..model_ilr_names])
  hull <- make_test_comp_hull()

  shifted <- suppressWarnings(compute_shifted_exposures(
    dt = dt,
    from = "n2_s2",
    to = "n3_s2",
    duration = 15,
    comp_hull = hull,
    comp_vars = comp_names,
    ilr_base = basis
  ))

  expected <- make_ilrs(shifted, comp_names, basis)
  data.table::setnames(expected, model_ilr_names)
  expect_equal(shifted[, ..model_ilr_names], expected)
  expect_false(isTRUE(all.equal(shifted[, ..model_ilr_names], original_ilrs)))
})

test_that("compute_shifted_exposures can use precomputed substitution masks", {
  dt <- make_test_comp_dt()
  masks <- data.table::data.table(
    from = "n2_s2",
    to = "n3_s2",
    duration = 15L,
    row_id = seq_len(nrow(dt)),
    PID = as.character(dt$PID),
    substituted = c(TRUE, FALSE, TRUE, FALSE),
    applied_duration = c(15, 0, 15, 0)
  )

  shifted <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    15,
    masks
  ))

  expect_equal(shifted$substituted, masks$substituted)
  expect_equal(shifted$n2_s2, dt$n2_s2 - c(15, 0, 15, 0))
  expect_equal(shifted$n3_s2, dt$n3_s2 + c(15, 0, 15, 0))
})

test_that("read_comp_hull_masks preserves fractional applied durations", {
  path <- tempfile(fileext = ".csv")
  data.table::fwrite(
    data.table::data.table(
      from = "n2_s2",
      to = "n3_s2",
      duration = 15L,
      row_id = 1L,
      PID = "1",
      substituted = FALSE,
      applied_duration = 7.5
    ),
    path
  )

  masks <- read_comp_hull_masks(path)

  expect_type(masks$applied_duration, "double")
  expect_equal(masks$applied_duration, 7.5)
  expect_false(masks$substituted)
})

test_that("compute_shifted_exposures accepts integer PID mask keys", {
  dt <- make_test_comp_dt()
  masks <- data.table::data.table(
    from = "n2_s2",
    to = "n3_s2",
    duration = 15L,
    row_id = seq_len(nrow(dt)),
    PID = dt$PID,
    substituted = c(TRUE, FALSE, TRUE, FALSE),
    applied_duration = c(15, 0, 15, 0)
  )

  shifted <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    15,
    masks
  ))

  expect_equal(shifted$substituted, masks$substituted)
})

test_that("compute_shifted_exposures uses original PID keys for bootstrap rows", {
  dt <- make_test_comp_dt()
  boot_dt <- dt[c(1L, 1L, 3L)]
  boot_dt[, `:=`(
    PID_original = PID,
    PID = seq_len(.N)
  )]
  masks <- data.table::data.table(
    from = "n2_s2",
    to = "n3_s2",
    duration = 15L,
    PID = as.character(dt$PID),
    substituted = c(TRUE, FALSE, FALSE, TRUE),
    applied_duration = c(15, 0, 0, 15)
  )

  shifted <- suppressWarnings(compute_shifted_exposures(
    boot_dt,
    "n2_s2",
    "n3_s2",
    15,
    masks
  ))

  expect_equal(shifted$substituted, c(TRUE, TRUE, FALSE))
})

test_that("compute_shifted_exposures errors when mask table lacks a policy", {
  dt <- make_test_comp_dt()
  masks <- data.table::data.table(
    from = "n1_s2",
    to = "n3_s2",
    duration = 15L,
    row_id = seq_len(nrow(dt)),
    PID = as.character(dt$PID),
    substituted = TRUE,
    applied_duration = 15
  )

  expect_error(
    compute_shifted_exposures(dt, "n2_s2", "n3_s2", 15, masks),
    "No substitution mask"
  )
})

test_that("compute_shifted_exposures clips unsupported rows to the boundary", {
  dt <- make_test_comp_dt()
  hull <- make_test_substitution_masks(
    dt,
    data.table::data.table(from = "n2_s2", to = "n3_s2", duration = 15L),
    substituted = c(FALSE, TRUE, TRUE, TRUE),
    applied_duration = c(7.5, 15, 15, 15)
  )
  dt[1, n2_s2 := 125]

  shifted <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    15,
    hull
  ))

  expect_false(shifted$substituted[1])
  expect_equal(shifted$n2_s2, dt$n2_s2 - c(7.5, 15, 15, 15))
  expect_equal(shifted$n3_s2, dt$n3_s2 + c(7.5, 15, 15, 15))
  expect_equal(shifted$applied_duration, c(7.5, 15, 15, 15))
  expect_equal(comp_total(shifted), comp_total(dt))
  expect_true(all(shifted$substituted[-1]))
})

test_that("compute_shifted_exposures handles negative durations as reverse shifts", {
  dt <- make_test_comp_dt()
  hull <- make_test_comp_hull()

  shifted <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    -10,
    hull
  ))

  expect_equal(comp_total(shifted), comp_total(dt))
  expect_equal(shifted$n2_s2, dt$n2_s2 + 10)
  expect_equal(shifted$n3_s2, dt$n3_s2 - 10)
  expect_true(all(shifted$substituted))
})

test_that("compute_shifted_exposures clips negative durations in the same direction", {
  dt <- make_test_comp_dt()
  hull <- make_test_substitution_masks(
    dt,
    data.table::data.table(from = "n2_s2", to = "n3_s2", duration = -10L),
    substituted = c(TRUE, FALSE, TRUE, TRUE),
    applied_duration = c(-10, -4.25, -10, -10)
  )

  shifted <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    -10,
    hull
  ))

  expect_equal(shifted$n2_s2, dt$n2_s2 - c(-10, -4.25, -10, -10))
  expect_equal(shifted$n3_s2, dt$n3_s2 + c(-10, -4.25, -10, -10))
  expect_equal(shifted$applied_duration, c(-10, -4.25, -10, -10))
  expect_equal(comp_total(shifted), comp_total(dt))
})

test_that("zero-duration substitutions mark every row as substituted", {
  dt <- make_test_comp_dt()
  hull <- make_test_comp_hull()

  dt[1, n2_s2 := 185]
  dt[2, n2_s2 := 115]

  shifted <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    0,
    hull
  ))

  expect_equal(shifted[, ..comp_vars], dt[, ..comp_vars])
  expect_true(all(shifted$substituted))
  expect_equal(shifted$applied_duration, rep(0, nrow(dt)))
})

test_that("make_lmtp_shift matches shifted exposure treatment columns", {
  dt <- make_test_comp_dt()
  dt[, extra_covariate := c(1, 2, 3, 4)]
  hull <- make_test_comp_hull()
  trt <- ilr_names

  shift_fn <- make_lmtp_shift("n2_s2", "n3_s2", 15, hull)
  shifted_trt <- suppressWarnings(shift_fn(dt, trt))
  expected <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    15,
    hull
  ))

  expect_s3_class(shifted_trt, "data.frame")
  expect_named(shifted_trt, trt)
  expect_equal(as.data.table(shifted_trt), expected[, ..trt])
})

test_that("apply_substitution remains a compatibility alias", {
  dt <- make_test_comp_dt()
  hull <- make_test_comp_hull()

  expected <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    15,
    hull
  ))
  shifted <- suppressWarnings(apply_substitution(
    dt,
    "n2_s2",
    "n3_s2",
    15,
    hull
  ))

  expect_equal(shifted, expected)
})

test_that("summarize_substitution_coverage returns consistent counts and ratios", {
  dt <- make_test_comp_dt()
  hull <- make_test_substitution_masks(
    dt,
    data.table::data.table(from = "n2_s2", to = "n3_s2", duration = 15L),
    substituted = c(FALSE, TRUE, TRUE, TRUE),
    applied_duration = c(7.5, 15, 15, 15)
  )
  dt[1, n2_s2 := 125]

  shifted <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    15,
    hull
  ))
  coverage <- summarize_substitution_coverage(shifted)

  expect_equal(coverage$n_intervened, 3)
  expect_equal(coverage$n_total, 4)
  expect_equal(coverage$ratio_substituted, 0.75)
  expect_equal(coverage$mean_applied_duration, 13.125)
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
  hull <- make_test_comp_hull()
  trt <- ilr_names

  shift_fn <- make_lmtp_shift("n2_s2", "n3_s2", -10, hull)
  shifted_trt <- suppressWarnings(shift_fn(dt, trt))
  expected <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    -10,
    hull
  ))

  expect_equal(as.data.table(shifted_trt), expected[, ..trt])
})

test_that("make_lmtp_shift respects infeasibility for reverse shifts", {
  dt <- make_test_comp_dt()
  dt[1, `:=`(n2_s2 = 180, n3_s2 = 55)]
  hull <- make_test_comp_hull()
  trt <- ilr_names

  shift_fn <- make_lmtp_shift("n2_s2", "n3_s2", -10, hull)
  shifted_trt <- suppressWarnings(shift_fn(dt, trt))
  expected <- suppressWarnings(compute_shifted_exposures(
    dt,
    "n2_s2",
    "n3_s2",
    -10,
    hull
  ))

  expect_equal(as.data.table(shifted_trt), expected[, ..trt])
})
