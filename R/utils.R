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

  return(primary_formula)
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
      death_status == 1 & end > death_date , 1 ,
      default = 0
    )
  ]

  surv_dt[, death := fifelse(dem_or_mci == 1, NA_integer_, death)]

  # remove rows after death
  surv_dt[, sumdeath := cumsum(death), by = "PID"]
  surv_dt <- surv_dt[sumdeath < 2 | is.na(sumdeath), ]
  surv_dt[, sumdeath := NULL]

  surv_dt
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
    data = surv_dt[death == 0 | is.na(death), ],
    family = binomial()
  )

  model_dem <- strip_glm(model_dem)

  model_death <- glm(
    death_model_formula,
    data = surv_dt[dem_or_mci == 0, ],
    family = binomial()
  )

  model_death <- strip_glm(model_death)

  list(dem = model_dem, death = model_death)
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
