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

  setnames(ilr_vars, ilr_names)

  ilr_vars
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
  sub[, (ilr_names) := ilr_vars]

  sub
}

compute_substituted_risk <- function(
  dt,
  from,
  to,
  duration,
  comp_limits,
  fitted_models,
  timegroup_cuts,
  baseline_risk
) {
  sub_dt <- apply_substitution(
    dt,
    from,
    to,
    duration,
    comp_limits
  )

  risk_dt <- predict_risks(sub_dt, fitted_models, timegroup_cuts)
  setnames(risk_dt, "risk", "mean_risk_substituted")

  baseline_dt <- copy(baseline_risk)
  setnames(baseline_dt, "risk", "mean_risk_baseline")

  risk_dt[, `:=`(
    from = from,
    to = to,
    duration = duration,
    n_intervened = sum(sub_dt$substituted),
    n_total = nrow(sub_dt)
  )]

  merge(
    baseline_dt,
    risk_dt,
    by = "timegroup"
  )
}
get_primary_formula <- function(dt) {
  knots <- lapply(ilr_names, function(name) {
    quantile(dt[[name]], c(0.1, 0.5, 0.9))
  })
  names(knots) <- paste0("knots_", ilr_names)

  knots_time <- quantile(dt$timegroup, probs = c(0.1, 0.5, 0.9))
  knots$knots_time <- knots_time

  ilr_terms <- paste0(
    "rcs(",
    ilr_names,
    ", ",
    names(knots)[seq_along(ilr_names)],
    ")"
  )
  term_str <- paste(
    c(ilr_terms, "rcs(timegroup, knots_time)"),
    collapse = " + "
  )
  primary_formula <- as.formula(paste("~", term_str))
  environment(primary_formula) <- list2env(knots, parent = parent.frame())

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
      death_status == 1 & end >= death_date ,
                                          1 ,
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

bootstrap_resample <- function(dt, seed) {
  set.seed(seed)

  pids <- unique(dt$PID)
  draw <- sample(pids, size = length(pids), replace = TRUE)

  boot_dt <- dt[
    data.table::data.table(PID = draw),
    on = "PID",
    allow.cartesian = TRUE
  ]
  boot_dt[, PID_original := PID]
  boot_dt[, PID := seq_len(.N)]

  boot_dt
}

run_bootstrap_rep <- function(dt, substitutions, seed) {
  boot_dt <- bootstrap_resample(dt, seed)

  timegroup_cuts <- make_cuts(boot_dt)
  fitted_models <- fit_models(boot_dt, timegroup_cuts)
  comp_limits <- make_comp_limits(boot_dt)
  baseline_risk <- predict_risks(boot_dt, fitted_models, timegroup_cuts)

  res_list <- lapply(seq_len(nrow(substitutions)), function(i) {
    row <- substitutions[i]
    compute_substituted_risk(
      boot_dt,
      row$from,
      row$to,
      row$duration,
      comp_limits,
      fitted_models,
      timegroup_cuts,
      baseline_risk
    )
  })

  data.table::rbindlist(res_list)
}

summarize_bootstrap_substitutions <- function(boot_substituted_risk) {
  dt <- copy(boot_substituted_risk)
  dt[, risk_ratio := mean_risk_substituted / mean_risk_baseline]

  dt[, max_timegroup := max(timegroup), by = bootstrap_seed]
  dt <- dt[timegroup == max_timegroup]

  dt[,
    .(
      risk_ratio_mean = mean(risk_ratio),
      risk_ratio_lo = quantile(risk_ratio, 0.025),
      risk_ratio_hi = quantile(risk_ratio, 0.975)
    ),
    by = .(from, to, duration)
  ]
}

plot_bootstrap_substitutions <- function(summary_dt) {
  ggplot2::ggplot(
    summary_dt,
    ggplot2::aes(
      x = duration,
      y = risk_ratio_mean,
      ymin = risk_ratio_lo,
      ymax = risk_ratio_hi
    )
  ) +
    ggplot2::geom_ribbon(alpha = 0.2) +
    ggplot2::geom_line() +
    ggplot2::geom_point() +
    ggplot2::facet_grid(from ~ to) +
    ggplot2::theme_minimal() +
    ggplot2::labs(
      x = "Minutes shifted",
      y = "Risk ratio",
      title = "Bootstrap risk ratio by substitution",
      subtitle = "CI: 2.5th and 97.5th percentiles"
    )
}

write_bootstrap_substitution_plot <- function(plot, path) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  ggplot2::ggsave(path, plot = plot, width = 12, height = 8)
  path
}
