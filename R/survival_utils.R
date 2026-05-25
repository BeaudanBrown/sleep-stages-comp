make_cuts <- function(dt, outcome_date, cut_width_years = 1) {
  max_follow_up <- max(dt[[outcome_date]], na.rm = TRUE)

  timegroup_steps <- ceiling(max_follow_up / (365 * cut_width_years))
  timegroup_steps <- max(timegroup_steps, 1)

  seq(
    from = 0,
    to = max_follow_up,
    length.out = timegroup_steps + 1
  )
}

expand_surv_dt <- function(dt, timegroup_cuts, event_date, event_var) {
  surv_formula <- as.formula(sprintf(
    "Surv(time = %s, event = %s) ~ .",
    event_date,
    event_var
  ))

  surv_dt <- survSplit(
    surv_formula,
    data = dt,
    cut = timegroup_cuts,
    episode = "timegroup",
    end = "end",
    event = "dem_or_mci",
    start = "start"
  )
  setDT(surv_dt)

  surv_dt[, timegroup := timegroup - 1]

  surv_dt[,
    death := fcase(
      death_status == 1 & end >= death_date ,
                                          1 ,
      default = 0
    )
  ]

  surv_dt
}

predict_risks <- function(dt, models, timegroup_cuts, event_var, event_date) {
  surv_dt <- expand_for_prediction(dt, timegroup_cuts, event_var, event_date)

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

expand_for_prediction <- function(dt, timegroup_cuts, event_var, event_date) {
  dt_pred <- copy(dt)

  max_time <- max(timegroup_cuts)
  dt_pred[, (event_date) := max_time]
  dt_pred[, (event_var) := 0]

  surv_formula <- as.formula(sprintf(
    "Surv(time = %s, event = %s) ~ .",
    event_date,
    event_var
  ))

  surv_dt <- survSplit(
    surv_formula,
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

fit_models <- function(dt) {
  model_formula <- get_primary_formula()

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
    data = dt[death == 0, ],
    family = binomial()
  )

  model_death <- glm(
    death_model_formula,
    data = dt,
    family = binomial()
  )

  list(
    dem = strip_glm(model_dem),
    death = strip_glm(model_death)
  )
}

get_primary_formula <- function() {
  Y ~
    R1_s2 +
    R2_s2 +
    R3_s2 +
    R4_s2 +
    R1_s1 +
    R2_s1 +
    R3_s1 +
    R4_s1 +
    age_s1 +
    gender
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

  cm
}
