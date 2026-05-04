run_lmtp_tmle_reference <- function(
  dt,
  outcome_cols,
  cens_cols,
  compete_cols,
  trt_cols,
  baseline_covars,
  learners_outcome,
  learners_trt,
  folds
) {
  lmtp::lmtp_tmle(
    data = as.data.frame(dt),
    trt = list(trt_cols),
    outcome = outcome_cols,
    baseline = if (length(baseline_covars)) baseline_covars else NULL,
    time_vary = NULL,
    cens = cens_cols,
    compete = compete_cols,
    shift = NULL,
    mtp = TRUE,
    outcome_type = "survival",
    learners_outcome = learners_outcome,
    learners_trt = learners_trt,
    folds = folds
  )
}

build_lmtp_shifted_data <- function(dt, trt_cols, cens_cols, shifted_trt_dt) {
  shifted_final <- copy(as.data.table(dt))
  shifted_final[, (trt_cols) := shifted_trt_dt[, trt_cols, with = FALSE]]

  if (!is.null(cens_cols)) {
    for (col in cens_cols) {
      if (col %in% names(shifted_final)) {
        shifted_final[[col]] <- 1
      }
    }
  }

  shifted_final
}

tidy_ife_estimate <- function(estimate) {
  out <- data.table::as.data.table(ife::tidy(estimate))
  out[, p.value := pnorm(abs(estimate) / std.error, lower.tail = FALSE) * 2]
  out
}

summarize_lmtp_event_risk_contrast <- function(
  fit,
  reference_fit,
  substitution,
  ratio_substituted
) {
  shifted_event_risk <- 1 - fit$estimate
  reference_event_risk <- 1 - reference_fit$estimate
  event_risk_ratio <- shifted_event_risk / reference_event_risk

  shifted_dt <- tidy_ife_estimate(shifted_event_risk)
  reference_dt <- tidy_ife_estimate(reference_event_risk)
  ratio_dt <- tidy_ife_estimate(event_risk_ratio)

  data.table::data.table(
    from = substitution$from,
    to = substitution$to,
    duration = substitution$duration,
    ratio_substituted = ratio_substituted,
    mean_risk_substituted = shifted_dt$estimate,
    mean_risk_reference = reference_dt$estimate,
    mean_risk_ratio = ratio_dt$estimate,
    std.error = ratio_dt$std.error,
    lower_ci = ratio_dt$conf.low,
    upper_ci = ratio_dt$conf.high,
    p.value = ratio_dt$p.value
  )
}

summarize_lmtp_contrast <- function(
  fit,
  reference_fit,
  substitution,
  ratio_substituted
) {
  summarize_lmtp_event_risk_contrast(
    fit = fit,
    reference_fit = reference_fit,
    substitution = substitution,
    ratio_substituted = ratio_substituted
  )
}

average_lmtp_imputation_summaries <- function(summary_dt) {
  dt <- data.table::as.data.table(summary_dt)

  if (!"imputation_id" %in% names(dt)) {
    return(dt)
  }

  pooled_rr <- dt[,
    pool_log_risk_ratio_rubin(
      risk_ratio = mean_risk_ratio,
      std.error = std.error
    ),
    by = .(from, to, duration)
  ]

  averaged_levels <- dt[,
    .(
      ratio_substituted = mean(ratio_substituted),
      mean_risk_substituted = mean(mean_risk_substituted),
      mean_risk_reference = mean(mean_risk_reference)
    ),
    by = .(from, to, duration)
  ]

  merge(
    averaged_levels,
    pooled_rr,
    by = c("from", "to", "duration"),
    all = FALSE,
    sort = FALSE
  )
}

run_lmtp_tmle_substitution <- function(
  dt,
  outcome_cols,
  cens_cols,
  compete_cols,
  trt_cols,
  baseline_covars,
  comp_limits,
  reference_fit,
  substitution,
  learners_outcome,
  learners_trt,
  folds
) {
  shifted_dt <- compute_shifted_exposures(
    dt,
    substitution$from,
    substitution$to,
    substitution$duration,
    comp_limits
  )

  shifted_final <- build_lmtp_shifted_data(
    dt = dt,
    trt_cols = trt_cols,
    cens_cols = cens_cols,
    shifted_trt_dt = shifted_dt
  )

  fit <- lmtp::lmtp_tmle(
    data = as.data.frame(dt),
    trt = list(trt_cols),
    outcome = outcome_cols,
    baseline = if (length(baseline_covars)) baseline_covars else NULL,
    time_vary = NULL,
    cens = cens_cols,
    compete = compete_cols,
    shifted = as.data.frame(shifted_final),
    mtp = TRUE,
    outcome_type = "survival",
    learners_outcome = learners_outcome,
    learners_trt = learners_trt,
    folds = folds
  )

  summarize_lmtp_contrast(
    fit = fit,
    reference_fit = reference_fit,
    substitution = substitution,
    ratio_substituted = summarize_substitution_coverage(
      shifted_dt
    )$ratio_substituted
  )
}

run_lmtp_tmle_substitutions_for_dataset <- function(
  dt,
  outcome_cols,
  cens_cols,
  compete_cols,
  trt_cols,
  baseline_covars,
  comp_limits,
  substitutions,
  learners_outcome,
  learners_trt,
  folds,
  imputation_id = NULL
) {
  reference_fit <- run_lmtp_tmle_reference(
    dt = dt,
    outcome_cols = outcome_cols,
    cens_cols = cens_cols,
    compete_cols = compete_cols,
    trt_cols = trt_cols,
    baseline_covars = baseline_covars,
    learners_outcome = learners_outcome,
    learners_trt = learners_trt,
    folds = folds
  )

  out <- lapply(seq_len(nrow(substitutions)), function(i) {
    run_lmtp_tmle_substitution(
      dt = dt,
      outcome_cols = outcome_cols,
      cens_cols = cens_cols,
      compete_cols = compete_cols,
      trt_cols = trt_cols,
      baseline_covars = baseline_covars,
      comp_limits = comp_limits,
      reference_fit = reference_fit,
      substitution = substitutions[i],
      learners_outcome = learners_outcome,
      learners_trt = learners_trt,
      folds = folds
    )
  })

  out <- data.table::rbindlist(out)
  if (!is.null(imputation_id)) {
    out[, imputation_id := as.character(imputation_id)]
  }

  out
}
