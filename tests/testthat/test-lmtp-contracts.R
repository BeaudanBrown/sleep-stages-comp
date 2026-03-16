test_that("build_lmtp_shifted_data only changes treatment and censoring columns", {
  inputs <- make_test_lmtp_inputs()
  wide <- data.table::as.data.table(inputs$wide)
  cols <- inputs$cols
  shifted_trt <- suppressWarnings(apply_substitution(
    wide,
    "n2_s2",
    "n3_s2",
    15,
    inputs$comp_limits
  ))

  shifted <- build_lmtp_shifted_data(
    dt = wide,
    trt_cols = ilr_names,
    cens_cols = cols$cens,
    shifted_trt_dt = shifted_trt
  )

  non_shifted_cols <- setdiff(names(wide), c(ilr_names, cols$cens))
  expect_equal(shifted[, ..non_shifted_cols], wide[, ..non_shifted_cols])
  expect_equal(shifted[, ..ilr_names], shifted_trt[, ..ilr_names])
  for (col in cols$cens) {
    expect_true(all(shifted[[col]] == 1))
  }
})

test_that("run_lmtp_tmle_reference returns an lmtp fit object", {
  inputs <- make_test_lmtp_inputs()

  ref <- run_lmtp_tmle_reference(
    dt = inputs$wide,
    outcome_cols = inputs$cols$outcome,
    cens_cols = inputs$cols$cens,
    compete_cols = inputs$cols$compete,
    trt_cols = ilr_names,
    baseline_covars = character(0),
    learners_outcome = "SL.mean",
    learners_trt = "SL.glm",
    folds = 2
  )

  expect_s3_class(ref, "lmtp")
})

test_that("run_lmtp_tmle_substitution returns a near-null risk ratio for a zero shift", {
  inputs <- make_test_lmtp_inputs()
  ref <- run_lmtp_tmle_reference(
    dt = inputs$wide,
    outcome_cols = inputs$cols$outcome,
    cens_cols = inputs$cols$cens,
    compete_cols = inputs$cols$compete,
    trt_cols = ilr_names,
    baseline_covars = character(0),
    learners_outcome = "SL.mean",
    learners_trt = "SL.glm",
    folds = 2
  )

  substitution <- data.table::data.table(
    from = "n2_s2",
    to = "n3_s2",
    duration = 0
  )

  out <- run_lmtp_tmle_substitution(
    dt = inputs$wide,
    outcome_cols = inputs$cols$outcome,
    cens_cols = inputs$cols$cens,
    compete_cols = inputs$cols$compete,
    trt_cols = ilr_names,
    baseline_covars = character(0),
    comp_limits = inputs$comp_limits,
    reference_fit = ref,
    substitution = substitution,
    learners_outcome = "SL.mean",
    learners_trt = "SL.glm",
    folds = 2
  )

  expect_equal(out$from, "n2_s2")
  expect_equal(out$to, "n3_s2")
  expect_equal(out$duration, 0)
  expect_true(is.finite(out$mean_risk_ratio))
  expect_equal(out$mean_risk_ratio, 1, tolerance = 0.05)
})

test_that("run_lmtp_tmle_substitution reports the event-risk contrast, not the survival-scale ratio", {
  inputs <- make_test_lmtp_inputs()
  ref <- run_lmtp_tmle_reference(
    dt = inputs$wide,
    outcome_cols = inputs$cols$outcome,
    cens_cols = inputs$cols$cens,
    compete_cols = inputs$cols$compete,
    trt_cols = ilr_names,
    baseline_covars = character(0),
    learners_outcome = "SL.mean",
    learners_trt = "SL.glm",
    folds = 2
  )

  substitution <- data.table::data.table(
    from = "n2_s2",
    to = "n3_s2",
    duration = 15
  )

  shifted_dt <- suppressWarnings(apply_substitution(
    inputs$wide,
    substitution$from,
    substitution$to,
    substitution$duration,
    inputs$comp_limits
  ))
  shifted_final <- build_lmtp_shifted_data(
    dt = inputs$wide,
    trt_cols = ilr_names,
    cens_cols = inputs$cols$cens,
    shifted_trt_dt = shifted_dt
  )

  fit <- lmtp::lmtp_tmle(
    data = as.data.frame(inputs$wide),
    trt = list(ilr_names),
    outcome = inputs$cols$outcome,
    baseline = NULL,
    time_vary = NULL,
    cens = inputs$cols$cens,
    compete = inputs$cols$compete,
    shifted = as.data.frame(shifted_final),
    mtp = TRUE,
    outcome_type = "survival",
    learners_outcome = "SL.mean",
    learners_trt = "SL.glm",
    folds = 2
  )

  shifted_event_risk <- 1 - fit$estimate
  reference_event_risk <- 1 - ref$estimate
  event_rr <- ife::tidy(shifted_event_risk / reference_event_risk)
  survival_rr <- data.table::as.data.table(
    lmtp::lmtp_contrast(fit, ref = ref, type = "rr")$estimates
  )
  expected <- summarize_lmtp_contrast(
    fit = fit,
    reference_fit = ref,
    substitution = substitution,
    ratio_substituted = mean(shifted_dt$substituted)
  )

  out <- run_lmtp_tmle_substitution(
    dt = inputs$wide,
    outcome_cols = inputs$cols$outcome,
    cens_cols = inputs$cols$cens,
    compete_cols = inputs$cols$compete,
    trt_cols = ilr_names,
    baseline_covars = character(0),
    comp_limits = inputs$comp_limits,
    reference_fit = ref,
    substitution = substitution,
    learners_outcome = "SL.mean",
    learners_trt = "SL.glm",
    folds = 2
  )

  expect_equal(
    expected$mean_risk_ratio,
    event_rr$estimate,
    tolerance = 1e-8
  )
  expect_equal(
    expected$mean_risk_substituted,
    ife::tidy(shifted_event_risk)$estimate,
    tolerance = 1e-8
  )
  expect_false(isTRUE(all.equal(
    expected$mean_risk_ratio,
    survival_rr$estimate,
    tolerance = 1e-8
  )))
  expect_equal(
    expected$mean_risk_reference,
    ife::tidy(reference_event_risk)$estimate,
    tolerance = 1e-8
  )
  expect_true(all(
    c("mean_risk_substituted", "mean_risk_reference", "mean_risk_ratio") %in%
      names(out)
  ))
})
