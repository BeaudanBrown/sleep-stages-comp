impute_data <- function(data, method, m = 2, iter = 10) {
  ## Variables to exclude from imputation
  exclude_patterns <- list(
    identifiers = c("IDTYPE$", "pptidr$", "pptidu"),
    sleep_stage_reads = c("waso", "^n1", "^n2", "^n3", "^rem"),
    time_to_event = c(
      "time",
      "alive",
      "death",
      "cens",
      "Status",
      "eddd",
      "DEM",
      "fram_cvd_date",
      "fram_cvd"
    ),
    cognitive_review = c(
      "review",
      "normal",
      "moderate",
      "impairment",
      "mild",
      "severe"
    ),
    selected_visit_dates = c("s1_date", "s2_date"),
    other_vars = c("waist")
  )

  exclude_vars <- grep(
    paste(unlist(exclude_patterns, use.names = FALSE), collapse = "|"),
    names(data),
    value = TRUE
  )

  imp_data <- data[, !..exclude_vars]

  # excluded vars dataset
  exclude_vars <- c(exclude_vars, "PID")
  excluded_data <- data[, ..exclude_vars]

  ## Exclude PID as a predictor in imputation model
  predmat <- quickpred(imp_data, mincor = 0, exclude = "PID")

  ## Fit imputation model
  imp <- mice(
    imp_data,
    method = method,
    m = m,
    iter = iter,
    predictorMatrix = predmat,
    remove.collinear = FALSE
  )

  imp <- complete(imp, action = "all")

  # return full dataset with imputed analysis variables
  lapply(imp, \(.x) merge(.x, excluded_data, by = "PID", all = TRUE))
}
