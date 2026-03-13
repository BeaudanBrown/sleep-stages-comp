test_that("get_primary_formula includes current ILR and timegroup spline terms", {
  dt <- make_test_model_dt()
  surv_dt <- expand_surv_dt(dt, make_cuts(dt))

  formula_obj <- get_primary_formula(surv_dt)
  formula_txt <- paste(deparse(formula_obj), collapse = " ")

  for (name in ilr_names) {
    expect_match(formula_txt, paste0("rcs\\(", name, ","), perl = TRUE)
  }
  expect_match(formula_txt, "rcs\\(timegroup, knots_time\\)", perl = TRUE)

  env_names <- ls(environment(formula_obj))
  expect_true("knots_time" %in% env_names)
  for (name in ilr_names) {
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
