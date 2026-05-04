test_that("build_lmtp_shifted_data only changes treatment and censoring columns", {
  inputs <- make_test_lmtp_inputs()
  wide <- data.table::as.data.table(inputs$wide)
  cols <- inputs$cols
  shifted_trt <- suppressWarnings(compute_shifted_exposures(
    wide,
    "n2_s2",
    "n3_s2",
    15,
    inputs$comp_hull
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
    comp_hull = inputs$comp_hull,
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

  shifted_dt <- suppressWarnings(compute_shifted_exposures(
    inputs$wide,
    substitution$from,
    substitution$to,
    substitution$duration,
    inputs$comp_hull
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
    comp_hull = inputs$comp_hull,
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

test_that("average_lmtp_imputation_summaries averages scalar LMTP summaries by substitution", {
  dt <- data.table::data.table(
    imputation_id = c("1", "2"),
    from = c("n2_s2", "n2_s2"),
    to = c("n3_s2", "n3_s2"),
    duration = c(15, 15),
    ratio_substituted = c(0.8, 0.9),
    mean_risk_substituted = c(0.12, 0.14),
    mean_risk_reference = c(0.1, 0.11),
    mean_risk_ratio = c(1.2, 1.27),
    std.error = c(0.05, 0.07),
    lower_ci = c(1.05, 1.11),
    upper_ci = c(1.35, 1.43),
    p.value = c(0.02, 0.03)
  )

  out <- average_lmtp_imputation_summaries(dt)
  pooled_log_rr <- pool_scalar_rubin(
    estimates = log(dt$mean_risk_ratio),
    variances = (dt$std.error / dt$mean_risk_ratio)^2
  )

  expect_equal(nrow(out), 1L)
  expect_equal(out$ratio_substituted, 0.85)
  expect_equal(out$mean_risk_substituted, 0.13)
  expect_equal(out$mean_risk_reference, 0.105)
  expect_equal(out$mean_risk_ratio, exp(pooled_log_rr$estimate))
  expect_equal(
    out$std.error,
    exp(pooled_log_rr$estimate) * pooled_log_rr$std.error
  )
  expect_equal(out$lower_ci, exp(pooled_log_rr$conf.low))
  expect_equal(out$upper_ci, exp(pooled_log_rr$conf.high))
})

test_that("pool_scalar_rubin returns the expected pooled variance components", {
  out <- pool_scalar_rubin(
    estimates = c(0.1, 0.2, 0.15),
    variances = c(0.01, 0.02, 0.015)
  )

  expect_equal(out$m, 3)
  expect_equal(out$estimate, mean(c(0.1, 0.2, 0.15)))
  expect_true(out$within_variance > 0)
  expect_true(out$total_variance >= out$within_variance)
  expect_true(is.finite(out$std.error))
})

test_that("pool_coefficient_table_rubin pools MI coefficient tables", {
  coef_tables <- list(
    data.table::data.table(
      term = c("(Intercept)", "R1"),
      estimate = c(0.10, 0.20),
      std.error = c(0.05, 0.07)
    ),
    data.table::data.table(
      term = c("(Intercept)", "R1"),
      estimate = c(0.12, 0.22),
      std.error = c(0.06, 0.09)
    )
  )

  out <- pool_coefficient_table_rubin(coef_tables)

  expect_equal(nrow(out), 2L)
  expect_true(all(
    c("term", "estimate", "std.error", "conf.low", "conf.high") %in%
      names(out)
  ))
  intercept <- out[term == "(Intercept)"]
  r1 <- out[term == "R1"]

  pooled_intercept <- pool_scalar_rubin(
    c(0.10, 0.12),
    c(0.05, 0.06)^2
  )
  pooled_r1 <- pool_scalar_rubin(
    c(0.20, 0.22),
    c(0.07, 0.09)^2
  )

  expect_equal(intercept$estimate, pooled_intercept$estimate, tolerance = 1e-8)
  expect_equal(
    intercept$std.error,
    pooled_intercept$std.error,
    tolerance = 1e-8
  )
  expect_equal(intercept$conf.low, pooled_intercept$conf.low, tolerance = 1e-8)
  expect_equal(
    intercept$conf.high,
    pooled_intercept$conf.high,
    tolerance = 1e-8
  )
  expect_equal(r1$estimate, pooled_r1$estimate, tolerance = 1e-8)
})

test_that("run_lmtp_tmle_substitutions_for_dataset tags outputs with imputation_id", {
  original <- list(
    reference = run_lmtp_tmle_reference,
    substitution = run_lmtp_tmle_substitution
  )

  assign(
    "run_lmtp_tmle_reference",
    function(...) {
      list(ref = TRUE)
    },
    envir = globalenv()
  )
  assign(
    "run_lmtp_tmle_substitution",
    function(
      dt,
      outcome_cols,
      cens_cols,
      compete_cols,
      trt_cols,
      baseline_covars,
      comp_hull,
      reference_fit,
      substitution,
      learners_outcome,
      learners_trt,
      folds
    ) {
      data.table::data.table(
        from = substitution$from,
        to = substitution$to,
        duration = substitution$duration,
        ratio_substituted = 1,
        mean_risk_substituted = 0.10,
        mean_risk_reference = 0.10,
        mean_risk_ratio = 1,
        std.error = 0.01,
        lower_ci = 0.8,
        upper_ci = 1.2,
        p.value = 0.5
      )
    },
    envir = globalenv()
  )
  on.exit(
    {
      assign("run_lmtp_tmle_reference", original$reference, envir = globalenv())
      assign(
        "run_lmtp_tmle_substitution",
        original$substitution,
        envir = globalenv()
      )
    },
    add = TRUE
  )

  out <- run_lmtp_tmle_substitutions_for_dataset(
    dt = data.table::data.table(),
    outcome_cols = character(),
    cens_cols = character(),
    compete_cols = character(),
    trt_cols = character(),
    baseline_covars = character(),
    comp_hull = list(),
    substitutions = data.table::data.table(
      from = "n1_s2",
      to = "n2_s2",
      duration = 15L
    ),
    learners_outcome = "SL.mean",
    learners_trt = "SL.glm",
    folds = 2,
    imputation_id = "7"
  )

  expect_equal(out$imputation_id, "7")
  expect_equal(nrow(out), 1L)
})
