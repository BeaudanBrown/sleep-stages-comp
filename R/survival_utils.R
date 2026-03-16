make_formula_knots <- function(dt, vars, probs = c(0.1, 0.5, 0.9)) {
  knots <- list()

  for (var in vars) {
    if (!(var %in% names(dt))) {
      next
    }

    vals <- dt[[var]]
    if (!is.numeric(vals) || all(is.na(vals))) {
      next
    }

    knot_name <- paste0("knots_", var)
    knots[[knot_name]] <- quantile(vals, probs = probs, na.rm = TRUE)
  }

  knots
}

rcs_term <- function(var) {
  paste0("rcs(", var, ", knots_", var, ")")
}

required_sleep_history_covars <- function(dt) {
  intersect(
    c("n1", "n2", "n3", "rem", "slp_time_s2", "s1_incomplete"),
    names(dt)
  )
}

required_sleep_history_spline_covars <- function(dt) {
  intersect(c("n1", "n2", "n3", "rem", "slp_time_s2"), names(dt))
}

provisional_confounder_main_effects <- function(dt) {
  intersect(
    c(
      "age_s1",
      "bmi_s1",
      "gender",
      "educat",
      "IDTYPE",
      "waist_circumference",
      "hypertension",
      "diabetes",
      "cvd_status",
      "smoking_status",
      "alcohol_use",
      "physical_activity",
      "apoe_e4",
      "sedative_use",
      "sleeping_pill_use",
      "antidepressant_use"
    ),
    names(dt)
  )
}

get_primary_formula <- function(dt) {
  comparison_contract <- build_comparison_contract(dt)
  spline_vars <- c(
    comparison_contract$trt_cols,
    "timegroup",
    "n1",
    "n2",
    "n3",
    "rem",
    "slp_time_s2"
  )
  knots <- make_formula_knots(dt, spline_vars)

  terms <- c(
    vapply(comparison_contract$trt_cols, rcs_term, character(1)),
    if ("timegroup" %in% names(dt)) rcs_term("timegroup"),
    vapply(
      comparison_contract$sleep_history_spline_covars,
      rcs_term,
      character(1)
    ),
    intersect("s1_incomplete", names(dt)),
    comparison_contract$confounder_main_effects
  )

  # The sleep-history contract is fixed here. Broader confounder selection is
  # still provisional and limited to additive main effects until finalized.
  primary_formula <- as.formula(paste("~", paste(terms, collapse = " + ")))
  environment(primary_formula) <- list2env(knots, parent = parent.frame())

  primary_formula
}

fit_model <- function(dt) {
  model_formula <- get_primary_formula(dt)
  dem_model_formula <- update(model_formula, dem_or_mci_status ~ .)
  death_model_formula <- update(model_formula, death ~ .)

  dem_model <- lm(dem_model_formula, dt)
  death_model <- lm(death_model_formula, dt)

  list(dem = strip_lm(dem_model), death = strip_lm(death_model))
}

make_cuts <- function(dt) {
  max_follow_up <- max(
    dt$dem_or_mci_surv_date,
    na.rm = TRUE
  )

  if (!is.finite(max_follow_up) || max_follow_up <= 0) {
    stop("Cannot construct timegroup cuts without positive finite follow-up.")
  }

  timegroup_steps <- ceiling(max_follow_up / (365 * 3))
  timegroup_steps <- max(timegroup_steps, 1)

  seq(
    from = 0,
    to = max_follow_up,
    length.out = timegroup_steps + 1
  )
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

expand_for_prediction <- function(dt, timegroup_cuts) {
  dt_pred <- copy(dt)

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

carry_forward_event_cols <- function(dt, id_var, cols) {
  dt[,
    (cols) := {
      vals <- unlist(.SD, use.names = FALSE)
      first_one <- match(TRUE, vals == 1, nomatch = 0L)
      if (first_one > 0L) {
        vals[first_one:length(vals)] <- 1
      }
      as.list(vals)
    },
    by = id_var,
    .SDcols = cols
  ]
}

make_surv_wide <- function(dt_surv_long, id_var = "PID") {
  dt <- copy(dt_surv_long)

  max_timegroup <- max(dt$timegroup, na.rm = TRUE)

  grid_dt <- CJ(
    id_val = unique(dt[[id_var]]),
    timegroup = seq(1, max_timegroup)
  )
  setnames(grid_dt, "id_val", id_var)

  dt <- merge(
    grid_dt,
    dt,
    by = c(id_var, "timegroup"),
    all.x = TRUE,
    sort = FALSE
  )

  observed_row <- !is.na(dt$dem_or_mci)
  dt[, cens := fifelse(observed_row, 1, 0)]
  dt[
    !observed_row,
    `:=`(
      dem_or_mci = NA_real_,
      death = NA_real_
    )
  ]

  cast_formula <- as.formula(sprintf("%s ~ timegroup", id_var))

  y_wide <- dcast(dt, cast_formula, value.var = "dem_or_mci", fill = NA_real_)
  d_wide <- dcast(dt, cast_formula, value.var = "death", fill = NA_real_)
  c_wide <- dcast(dt, cast_formula, value.var = "cens", fill = NA_real_)

  time_names <- seq_len(max_timegroup)
  setnames(y_wide, setdiff(names(y_wide), id_var), paste0("Y_", time_names))
  setnames(d_wide, setdiff(names(d_wide), id_var), paste0("D_", time_names))
  setnames(c_wide, setdiff(names(c_wide), id_var), paste0("C_", time_names))

  y_cols <- paste0("Y_", time_names)
  d_cols <- paste0("D_", time_names)

  carry_forward_event_cols(y_wide, id_var = id_var, cols = y_cols)
  carry_forward_event_cols(d_wide, id_var = id_var, cols = d_cols)

  drop_cols <- intersect(
    c(
      "start",
      "end",
      "timegroup",
      "dem_or_mci",
      "death",
      "cens",
      "dem_or_mci_status",
      "dem_or_mci_surv_date",
      "death_status",
      "death_date"
    ),
    names(dt)
  )

  base_dt <- unique(
    dt[, setdiff(names(dt), drop_cols), with = FALSE],
    by = id_var
  )

  as.data.frame(Reduce(
    \(x, y) merge(x, y, by = id_var, sort = FALSE),
    list(base_dt, y_wide, d_wide, c_wide)
  ))
}

get_surv_cols <- function(dt, prefix) {
  cols <- grep(sprintf("^%s_\\d+$", prefix), names(dt), value = TRUE)
  cols[order(as.integer(sub(sprintf("^%s_", prefix), "", cols)))]
}

get_lmtp_surv_cols <- function(dt) {
  outcome_cols <- get_surv_cols(dt, "Y")
  cens_cols <- get_surv_cols(dt, "C")
  compete_cols <- get_surv_cols(dt, "D")

  n_periods <- min(
    length(outcome_cols),
    length(cens_cols),
    length(compete_cols)
  )
  if (n_periods == 0) {
    stop("No survival columns available for LMTP.")
  }

  informative_outcome <- vapply(
    outcome_cols[seq_len(n_periods)],
    function(col) data.table::uniqueN(dt[[col]], na.rm = FALSE) > 1,
    logical(1)
  )

  if (!any(informative_outcome)) {
    stop("No informative outcome periods available for LMTP.")
  }

  keep_n <- max(which(informative_outcome))

  list(
    outcome = outcome_cols[seq_len(keep_n)],
    cens = cens_cols[seq_len(keep_n)],
    compete = compete_cols[seq_len(keep_n)]
  )
}

default_baseline_covars <- function(dt) {
  build_comparison_contract(dt)$baseline_covars
}

predict_risks <- function(dt, models, timegroup_cuts) {
  surv_dt <- expand_for_prediction(dt, timegroup_cuts)

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

  model_death <- glm(
    death_model_formula,
    data = surv_dt,
    family = binomial()
  )

  list(
    dem = strip_glm(model_dem),
    death = strip_glm(model_death)
  )
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
