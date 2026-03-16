make_imputation_methods <- function(imp_dt) {
  meth <- mice::make.method(imp_dt)
  meth[] <- ""

  if ("educat" %in% names(meth)) {
    meth["educat"] <- "pmm"
  }

  meth
}

make_imputation_predictor_matrix <- function(imp_dt) {
  pred <- mice::make.predictorMatrix(imp_dt)
  pred[,] <- 0

  educat_predictors <- intersect(
    c(
      "age_s1",
      "bmi_s1",
      "gender",
      "n1",
      "n2",
      "n3",
      "rem",
      "waso",
      "n1_s2",
      "n2_s2",
      "n3_s2",
      "rem_s2",
      "waso_s2",
      "dem_or_mci_surv_date",
      "log_dem_time"
    ),
    colnames(pred)
  )

  if ("educat" %in% rownames(pred)) {
    pred["educat", educat_predictors] <- 1
    pred["educat", "educat"] <- 0
  }

  pred
}

impute_data <- function(dt, m = 1, maxit = 5) {
  base_covars <- c("age_s1", "bmi_s1", "gender", "educat", "IDTYPE")
  base_covars <- intersect(base_covars, names(dt))

  sleep_vars <- c(
    "n1",
    "n2",
    "n3",
    "rem",
    "waso",
    "slp_time",
    "n1_s2",
    "n2_s2",
    "n3_s2",
    "rem_s2",
    "waso_s2",
    "slp_time_s2"
  )

  outcome_vars <- c(
    "dem_or_mci_status",
    "dem_or_mci_surv_date",
    "death_status",
    "death_date"
  )

  imp_cols <- intersect(
    c("PID", base_covars, sleep_vars, outcome_vars),
    names(dt)
  )
  imp_dt <- dt[, ..imp_cols]
  imp_dt[, log_dem_time := log(dem_or_mci_surv_date)]

  meth <- make_imputation_methods(imp_dt)
  pred <- make_imputation_predictor_matrix(imp_dt)

  # Only run mice when at least one configured target still has missingness.
  active_targets <- names(meth)[meth != ""]
  needs_imputation <- any(vapply(
    active_targets,
    function(col) {
      anyNA(imp_dt[[col]])
    },
    logical(1)
  ))

  if (!needs_imputation) {
    out_dt <- data.table::copy(dt)
    ilr_vars <- make_ilrs(out_dt)
    out_dt[, (ilr_names) := ilr_vars]
    return(out_dt)
  }

  imp <- mice::mice(
    imp_dt,
    m = m,
    maxit = maxit,
    meth = meth,
    pred = pred,
    printFlag = FALSE
  )

  comp_dt <- data.table::as.data.table(mice::complete(imp, action = 1))

  drop_cols <- c("log_dem_time")
  comp_dt[, (drop_cols) := NULL]

  out_dt <- data.table::copy(dt)
  update_cols <- setdiff(names(comp_dt), "PID")

  out_dt[comp_dt, (update_cols) := mget(paste0("i.", update_cols)), on = "PID"]

  ilr_vars <- make_ilrs(out_dt)
  out_dt[, (ilr_names) := ilr_vars]

  out_dt
}
