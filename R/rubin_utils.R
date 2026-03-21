pool_scalar_rubin <- function(
  estimates,
  variances,
  conf.level = 0.95
) {
  stopifnot(length(estimates) == length(variances))

  keep <- is.finite(estimates) & is.finite(variances) & variances >= 0
  estimates <- estimates[keep]
  variances <- variances[keep]

  if (length(estimates) == 0L) {
    stop(
      "Rubin pooling requires at least one finite estimate/variance pair.",
      call. = FALSE
    )
  }

  m <- length(estimates)
  q_bar <- mean(estimates)
  u_bar <- mean(variances)
  b <- if (m > 1L) stats::var(estimates) else 0
  total_variance <- u_bar + (1 + 1 / m) * b
  total_se <- sqrt(total_variance)

  if (m > 1L && b > 0 && u_bar > 0) {
    df <- (m - 1) * (1 + u_bar / ((1 + 1 / m) * b))^2
  } else {
    df <- Inf
  }

  alpha <- 1 - conf.level
  crit <- if (is.finite(df)) {
    stats::qt(1 - alpha / 2, df = df)
  } else {
    stats::qnorm(1 - alpha / 2)
  }

  statistic <- q_bar / total_se
  p.value <- if (is.finite(df)) {
    2 * stats::pt(abs(statistic), df = df, lower.tail = FALSE)
  } else {
    2 * stats::pnorm(abs(statistic), lower.tail = FALSE)
  }

  data.table::data.table(
    estimate = q_bar,
    std.error = total_se,
    conf.low = q_bar - crit * total_se,
    conf.high = q_bar + crit * total_se,
    p.value = p.value,
    m = m,
    within_variance = u_bar,
    between_variance = b,
    total_variance = total_variance,
    df = df
  )
}

pool_log_risk_ratio_rubin <- function(
  risk_ratio,
  std.error,
  conf.level = 0.95
) {
  pooled <- pool_scalar_rubin(
    estimates = log(risk_ratio),
    variances = (std.error / risk_ratio)^2,
    conf.level = conf.level
  )

  pooled[, .(
    mean_risk_ratio = exp(estimate),
    std.error = exp(estimate) * std.error,
    lower_ci = exp(conf.low),
    upper_ci = exp(conf.high),
    p.value = p.value
  )]
}
