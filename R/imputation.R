make_imputation_methods <- function(imp_dt) {
  meth <- mice::make.method(imp_dt)
  meth[] <- ""

  no_impute <- intersect(imputation_no_impute_vars(), names(meth))
  candidate_cols <- setdiff(names(meth), no_impute)

  for (col in candidate_cols) {
    if (!anyNA(imp_dt[[col]])) {
      next
    }

    if (is.numeric(imp_dt[[col]]) || is.integer(imp_dt[[col]])) {
      meth[col] <- "pmm"
    } else if (is.factor(imp_dt[[col]])) {
      n_levels <- length(levels(droplevels(imp_dt[[col]])))
      meth[col] <- if (n_levels <= 2L) "logreg" else "polyreg"
    }
  }

  meth
}

make_imputation_predictor_matrix <- function(imp_dt) {
  pred <- mice::make.predictorMatrix(imp_dt)
  pred[,] <- 0

  candidate_predictors <- intersect(imputation_predictor_vars(), colnames(pred))

  meth <- make_imputation_methods(imp_dt)
  active_targets <- names(meth)[meth != ""]

  for (target in active_targets) {
    predictors <- setdiff(candidate_predictors, target)
    pred[target, predictors] <- 1
  }

  pred
}

make_imputation_input_dt <- function(dt) {
  model_covars <- unique(c(
    "age_s1",
    "bmi_s1",
    "gender",
    "educat",
    "IDTYPE",
    provisional_confounder_main_effects(dt)
  ))
  model_covars <- intersect(model_covars, names(dt))

  imp_cols <- intersect(
    c(
      "PID",
      model_covars,
      sleep_history_vars,
      sleep_exposure_vars,
      survival_model_outcome_vars
    ),
    names(dt)
  )
  imp_dt <- dt[, ..imp_cols]
  imp_dt[, (imputation_auxiliary_vars) := log(get(survival_outcome_vars[[2L]]))]

  imp_dt
}

add_imputed_columns <- function(dt, comp_dt) {
  out_dt <- data.table::copy(dt)
  update_cols <- setdiff(names(comp_dt), "PID")
  out_dt[comp_dt, (update_cols) := mget(paste0("i.", update_cols)), on = "PID"]

  ilr_vars <- make_ilrs(out_dt)
  out_dt[, (ilr_names) := ilr_vars]

  out_dt
}

impute_data <- function(dt, m = 1, maxit = 5) {
  imp_dt <- make_imputation_input_dt(dt)
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
    return(mice::mice(
      imp_dt,
      m = m,
      maxit = 0,
      meth = meth,
      pred = pred,
      printFlag = FALSE
    ))
  }

  mice::mice(
    imp_dt,
    m = m,
    maxit = maxit,
    meth = meth,
    pred = pred,
    printFlag = FALSE
  )
}

complete_imputed_dataset <- function(imp, dt, action = 1) {
  comp_dt <- data.table::as.data.table(mice::complete(imp, action = action))
  drop_cols <- imputation_auxiliary_vars
  drop_cols <- intersect(drop_cols, names(comp_dt))

  if (length(drop_cols) > 0) {
    comp_dt[, (drop_cols) := NULL]
  }

  add_imputed_columns(dt, comp_dt)
}

complete_imputed_datasets <- function(imp, dt) {
  lapply(seq_len(imp$m), function(action) {
    complete_imputed_dataset(imp = imp, dt = dt, action = action)
  })
}
