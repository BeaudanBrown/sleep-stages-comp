bootstrap_intervals <- function(data, parameter) {
  data$Y <- data[[parameter]]
  B <- uniqueN(data$B)
  # estimate between and within mean sum of squares
  model <- aov(Y ~ as.factor(B), data = data)
  MSB <- summary(model)[[1]]$`Mean Sq`[1]
  MSW <- summary(model)[[1]]$`Mean Sq`[2]
  sigma1 <- (MSB - MSW) / 2
  sigma1 <- ifelse(sigma1 < 0, 0, sigma1)
  sigma2 <- ifelse(sigma1 < 0, var(data$Y), MSW)
  Var <- ((1 + (1 / B)) * sigma1) + ((1 / (B * 2)) * sigma2)
  df_numerator <- (((B + 1) / (2 * B)) * MSB - (MSW / 2))^2
  df_denominator <- ((((B + 1) / (2 * B))^2 * MSB^2) / (B - 1)) +
    (MSW^2 / (4 * B))
  df <- if (df_denominator == 0) Inf else df_numerator / df_denominator
  estimate <- mean(data$Y)
  se <- sqrt(Var)
  lower <- estimate - qt(0.975, df) * se
  upper <- estimate + qt(0.975, df) * se

  data.table(
    parameter = parameter,
    estimate = estimate,
    se = se,
    lower = lower,
    upper = upper,
    df = df
  )
}

summary_bootstrap_intervals <- function(estimates) {
  parameters <- c("pred", "mean_difference")
  group_cols <- c("from", "to", "duration", "outcome")

  rbindlist(lapply(parameters, \(parameter) {
    estimates[, bootstrap_intervals(.SD, parameter), by = group_cols]
  }))
}
