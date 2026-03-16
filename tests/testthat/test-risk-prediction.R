test_that("get_primary_formula includes the current sleep-history contract terms", {
  dt <- make_test_model_dt()
  surv_dt <- expand_surv_dt(dt, make_cuts(dt))

  formula_obj <- get_primary_formula(surv_dt)
  formula_txt <- paste(deparse(formula_obj), collapse = " ")
  formula_txt <- gsub("[[:space:]]+", " ", formula_txt)

  for (name in ilr_names) {
    expect_match(formula_txt, paste0("rcs\\(", name, ","), perl = TRUE)
  }
  expect_match(formula_txt, "rcs\\(timegroup, knots_timegroup\\)", perl = TRUE)
  for (name in c("n1", "n2", "n3", "rem", "slp_time_s2")) {
    expect_match(
      formula_txt,
      paste0("rcs\\(", name, ", +knots_", name, "\\)"),
      perl = TRUE
    )
  }
  expect_match(formula_txt, "\\bs1_incomplete\\b", perl = TRUE)
  expect_false(grepl("rcs\\(s1_incomplete,", formula_txt, perl = TRUE))
  expect_match(formula_txt, "\\bage_s1\\b", perl = TRUE)
  expect_match(formula_txt, "\\bgender\\b", perl = TRUE)
  expect_match(formula_txt, "\\bhypertension\\b", perl = TRUE)

  env_names <- ls(environment(formula_obj))
  for (name in c(
    ilr_names,
    "timegroup",
    "n1",
    "n2",
    "n3",
    "rem",
    "slp_time_s2"
  )) {
    expect_true(paste0("knots_", name) %in% env_names)
  }
})

test_that("fit_models returns prediction-capable dem and death models", {
  dt <- make_test_model_dt()
  cuts <- make_cuts(dt)

  models <- fit_models(dt, cuts)
  pred_dt <- expand_for_prediction(dt, cuts)

  expect_named(models, c("dem", "death"))
  expect_true(inherits(models$dem, "glm"))
  expect_true(inherits(models$death, "glm"))

  dem_pred <- predict(models$dem, newdata = pred_dt, type = "response")
  death_pred <- predict(models$death, newdata = pred_dt, type = "response")

  expect_equal(length(dem_pred), nrow(pred_dt))
  expect_equal(length(death_pred), nrow(pred_dt))
  expect_true(all(is.finite(dem_pred)))
  expect_true(all(is.finite(death_pred)))
  expect_true(all(dem_pred >= 0 & dem_pred <= 1))
  expect_true(all(death_pred >= 0 & death_pred <= 1))
})

test_that("predict_risks returns bounded non-decreasing mean risks over time", {
  dt <- make_test_model_dt()
  cuts <- make_cuts(dt)
  models <- fit_models(dt, cuts)

  risks <- predict_risks(dt, models, cuts)

  expect_s3_class(risks, "data.table")
  expect_named(risks, c("timegroup", "risk"))
  expect_true(all(is.finite(risks$risk)))
  expect_true(all(risks$risk >= 0 & risks$risk <= 1))
  expect_true(all(diff(risks$timegroup) > 0))
  expect_true(all(diff(risks$risk) >= -1e-8))
})

test_that("prepare_dataset creates the LMTP sleep-history baseline terms", {
  dt_raw <- make_test_raw_dataset()

  prepared <- prepare_dataset(dt_raw)

  expect_true(all(
    c("n1", "n2", "n3", "rem", "slp_time_s2", "s1_incomplete") %in%
      names(prepared)
  ))
  expect_equal(prepared$s1_incomplete, c(0L, 1L))
})

test_that("default_baseline_covars keeps the intended LMTP sleep-history covariates", {
  dt_raw <- make_test_raw_dataset()
  prepared <- prepare_dataset(dt_raw)
  cuts <- make_cuts(prepared)
  surv_dt <- expand_surv_dt(prepared, cuts)
  wide <- make_surv_wide(surv_dt)

  covars <- default_baseline_covars(wide)

  expect_true(all(
    c("n1", "n2", "n3", "rem", "slp_time_s2", "s1_incomplete") %in% covars
  ))
  expect_true(all(c("age_s1", "gender", "hypertension") %in% covars))
})

test_that("required sleep-history helpers separate spline and indicator terms", {
  dt_raw <- make_test_raw_dataset()
  prepared <- prepare_dataset(dt_raw)
  cuts <- make_cuts(prepared)
  surv_dt <- expand_surv_dt(prepared, cuts)
  wide <- make_surv_wide(surv_dt)

  expect_equal(
    required_sleep_history_spline_covars(wide),
    c("n1", "n2", "n3", "rem", "slp_time_s2")
  )
  expect_equal(
    required_sleep_history_covars(wide),
    c("n1", "n2", "n3", "rem", "slp_time_s2", "s1_incomplete")
  )
})
