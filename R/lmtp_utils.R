baseline_covars_or_null <- function(baseline_covars) {
  if (length(baseline_covars) == 0) {
    NULL
  } else {
    baseline_covars
  }
}

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
    baseline = baseline_covars_or_null(baseline_covars),
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

format_lmtp_substitution <- function(substitution) {
  sprintf(
    "from=%s to=%s duration=%s",
    substitution$from[[1]],
    substitution$to[[1]],
    as.character(substitution$duration[[1]])
  )
}

validate_lmtp_substitution <- function(substitution) {
  required_cols <- c("from", "to", "duration")
  missing_cols <- setdiff(required_cols, names(substitution))
  if (length(missing_cols) > 0) {
    stop(
      sprintf(
        "substitution is missing required columns: %s",
        paste(missing_cols, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  if (nrow(substitution) != 1L) {
    stop(
      sprintf(
        "substitution must have exactly 1 row, got %s",
        nrow(substitution)
      ),
      call. = FALSE
    )
  }

  if (
    length(substitution$from) != 1L ||
      length(substitution$to) != 1L ||
      length(substitution$duration) != 1L
  ) {
    stop("substitution columns must each have length 1", call. = FALSE)
  }

  invisible(substitution)
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
  validate_lmtp_substitution(substitution)
  substitution_label <- format_lmtp_substitution(substitution)

  tryCatch(
    {
      shifted_dt <- apply_substitution(
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
        baseline = baseline_covars_or_null(baseline_covars),
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
    },
    error = function(e) {
      stop(
        paste0(
          "LMTP substitution failed [",
          substitution_label,
          "] with folds=",
          folds,
          ", outcome_learners=",
          paste(learners_outcome, collapse = ","),
          ", trt_learners=",
          paste(learners_trt, collapse = ","),
          ": ",
          conditionMessage(e)
        ),
        call. = FALSE
      )
    }
  )
}
