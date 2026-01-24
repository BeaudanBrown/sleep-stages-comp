mice.impute.truncated_norm <- function(y, ry, x, wy = NULL, lower = -Inf, ...) {
  if (is.null(wy)) {
    wy <- !ry
  }

  # Only want lower for missing vars
  lower <- lower[wy]

  x <- cbind(1, as.matrix(x))
  parm <- mice:::.norm.draw(y, ry, x, ...)
  mean_prediction <- x[wy, ] %*% parm$beta

  imputed_values <- truncnorm::rtruncnorm(
    n = sum(wy),
    a = lower,
    mean = mean_prediction,
    sd = parm$sigma
  )

  imputed_values
}

make_ilrs <- function(dt) {
  comp <- compositions::acomp(dt[,
    ..comp_vars
  ])

  ilr_vars <- ilr(comp, V = v) |>
    as.data.table()
}

make_comp_limits <- function(dt) {
  quants <- lapply(comp_vars, function(var) {
    q_1_99 <- quantile(dt[[var]], probs = c(0.01, 0.99), na.rm = TRUE)
    list(
      lower = q_1_99[1],
      upper = q_1_99[2]
    )
  }) |>
    setNames(comp_vars)
}

apply_substitution <- function(dt, from_var, to_var, duration, comp_limits) {
  lower_from <- comp_limits[[from_var]]$lower
  upper_to <- comp_limits[[to_var]]$upper

  max_from_change <- dt[[from_var]] - lower_from
  max_to_change <- upper_to - dt[[to_var]]
  can_substitute <- (max_from_change >= duration) & (max_to_change >= duration)

  sub <- copy(dt)
  sub[[from_var]] <- sub[[from_var]] - (can_substitute * duration)
  sub[[to_var]] <- sub[[to_var]] + (can_substitute * duration)
  sub[["substituted"]] <- can_substitute

  ilr_vars <- make_ilrs(sub)

  sub[, c("R1", "R2", "R3", "R4")] <- ilr_vars

  data.table(
    results = list(sub),
    from_var = from_var,
    to_var = to_var,
    duration = duration
  )
}

perform_isotemporal_substitution <- function(
  dt,
  models,
  density_model,
  timegroup_cuts,
  comp_limits,
  from,
  to,
  duration
) {
  # 1. Apply substitution
  sub_res <- apply_substitution(dt, from, to, duration, comp_limits)
  dt_sub <- sub_res$results[[1]]

  # 2. Check density
  valid_density <- check_density(dt_sub, density_model)

  # 3. Revert invalid density rows to original ILRs (and component vars if needed, but model uses ILRs)
  # The intervention is: "Change if plausible and possible, else keep original."

  if (any(!valid_density)) {
    ilr_cols <- c("R1", "R2", "R3", "R4")
    dt_sub[!valid_density, (ilr_cols) := dt[!valid_density, ..ilr_cols]]
  }

  # 4. Predict
  risk_curve <- predict_risks(dt_sub, models, timegroup_cuts)

  # Return result with metadata
  data.table(
    mean_risk = risk_curve$mean_risk,
    timegroup = risk_curve$timegroup,
    from = from,
    to = to,
    duration = duration
  )
}


get_primary_formula <- function(dt) {
  knots_r1 <- quantile(
    dt[["R1"]],
    c(0.1, 0.5, 0.9)
  )
  knots_r2 <- quantile(
    dt[["R2"]],
    c(0.1, 0.5, 0.9)
  )
  knots_r3 <- quantile(
    dt[["R3"]],
    c(0.1, 0.5, 0.9)
  )
  knots_r4 <- quantile(
    dt[["R4"]],
    c(0.1, 0.5, 0.9)
  )

  knots_time <- quantile(dt$timegroup, probs = c(0.1, 0.5, 0.9))

  primary_formula <- as.formula(
    ~ rcs(R1, knots_r1) +
      rcs(R2, knots_r2) +
      rcs(R3, knots_r3) +
      rcs(R4, knots_r4) +
      rcs(timegroup, knots_time)
  )

  primary_formula
}

fit_model <- function(dt) {
  # Fit linear regression
  model_formula <- get_primary_formula(dt)
  dem_model_formula <- update(model_formula, dem_or_mci_status ~ .)
  death_model_formula <- update(model_formula, death ~ .)

  dem_model <- lm(dem_model_formula, dt)
  death_model <- lm(death_model_formula, dt)

  list(dem = strip_lm(dem_model), death = strip_lm(death_model))
}

make_cuts <- function(dt) {
  max_follow_up <- max(
    dt[dem_or_mci_status == 1, ]$dem_or_mci_surv_date,
    na.rm = TRUE
  )
  timegroup_steps <- ceiling(max_follow_up / 365)

  timegroup_cuts <-
    seq(
      from = 0,
      to = max_follow_up,
      length.out = timegroup_steps + 1
    )
  timegroup_cuts
}


expand_surv_dt <- function(dt, timegroup_cuts) {
  surv_dt <- survSplit(
    Surv(time = dem_or_mci_surv_date, event = dem_or_mci_status) ~ .,
    data = dt,
    cut = timegroup_cuts,
    episode = "timegroup",
    end = "end",
    event = "dem_or_mci",
    start = "start"
  )
  setDT(surv_dt)

  # start timegroup at 1
  surv_dt[, timegroup := timegroup - 1]

  surv_dt[,
    death := fcase(
      death_status == 1 & end >= death_date,
      1,
      default = 0
    )
  ]

  # dem_or_mci_surv_date is EITHER dem/mci or censoring or death
  # Therefore death and dem_or_mci all always exclusive

  surv_dt
}

expand_for_prediction <- function(dt, timegroup_cuts) {
  dt_pred <- copy(dt)

  # Force full follow-up for everyone
  max_time <- max(timegroup_cuts)
  dt_pred[, dem_or_mci_surv_date := max_time]
  dt_pred[, dem_or_mci_status := 0]

  surv_dt <- survSplit(
    Surv(time = dem_or_mci_surv_date, event = dem_or_mci_status) ~ .,
    data = dt_pred,
    cut = timegroup_cuts,
    episode = "timegroup",
    end = "end",
    event = "dem_or_mci",
    start = "start"
  )
  setDT(surv_dt)

  surv_dt[, timegroup := timegroup - 1]
  surv_dt
}

predict_risks <- function(dt, models, timegroup_cuts) {
  surv_dt <- expand_for_prediction(dt, timegroup_cuts)

  # Predict probabilities
  surv_dt[,
    haz_dem := predict(models$dem, newdata = surv_dt, type = "response")
  ]
  surv_dt[,
    haz_death := predict(models$death, newdata = surv_dt, type = "response")
  ]

  setorder(surv_dt, PID, timegroup)

  surv_dt[,
    risk := cumsum(
      haz_dem *
        (1 - haz_death) *
        cumprod(
          (1 - lag(haz_dem, default = 0)) * (1 - lag(haz_death, default = 0))
        )
    ),
    by = PID
  ]
  surv_dt[,
    .(risk = mean(risk)),
    by = timegroup
  ]
}

fit_models <- function(dt, timegroup_cuts) {
  surv_dt <- expand_surv_dt(dt, timegroup_cuts)

  model_formula <- get_primary_formula(surv_dt)

  # Add timegroup spline to formulas
  dem_model_formula <- update(
    model_formula,
    dem_or_mci ~ .
  )
  death_model_formula <- update(
    model_formula,
    death ~ .
  )

  model_dem <- glm(
    dem_model_formula,
    data = surv_dt[death == 0, ],
    family = binomial()
  )

  model_dem <- strip_glm(model_dem)

  model_death <- glm(
    death_model_formula,
    data = surv_dt,
    family = binomial()
  )

  model_death <- strip_glm(model_death)

  list(dem = model_dem, death = model_death)
}

fit_density_model <- function(dt) {
  ilr_cols <- c("R1", "R2", "R3", "R4")
  data <- as.matrix(dt[, ..ilr_cols])

  mu <- colMeans(data, na.rm = TRUE)
  sigma <- cov(data, use = "complete.obs")

  list(mu = mu, sigma = sigma)
}

check_density <- function(dt, density_model, threshold_quantile = 0.05) {
  ilr_cols <- c("R1", "R2", "R3", "R4")
  data <- as.matrix(dt[, ..ilr_cols])

  d2 <- mahalanobis(data, center = density_model$mu, cov = density_model$sigma)

  # Threshold based on Chi-squared distribution (df = 4 for 4 ILRs)
  # We want points with density > threshold, which corresponds to distance < critical_value
  threshold <- qchisq(1 - threshold_quantile, df = 4)

  d2 <= threshold
}

strip_lm <- function(cm) {
  cm$y <- c()
  cm$model <- c()

  cm$residuals <- c()
  cm$fitted.values <- c()
  cm$effects <- c()
  cm$qr$qr <- c()
  cm$linear.predictors <- c()
  cm$weights <- c()
  cm$prior.weights <- c()
  cm$data <- c()

  cm
}

strip_glm <- function(cm) {
  cm$y <- c()
  cm$model <- c()

  cm$residuals <- c()
  cm$fitted.values <- c()
  cm$effects <- c()
  cm$qr$qr <- c()
  cm$linear.predictors <- c()
  cm$weights <- c()
  cm$prior.weights <- c()
  cm$data <- c()

  cm$family$variance <- c()
  cm$family$dev.resids <- c()
  cm$family$aic <- c()
  cm$family$validmu <- c()
  cm$family$simulate <- c()

  return(cm)
}
