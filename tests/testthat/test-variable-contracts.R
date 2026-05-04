test_that("shared variable contracts centralize imputation and survival fields", {
  expect_equal(
    sleep_exposure_vars,
    c("n1_s2", "n2_s2", "n3_s2", "waso_s2", "rem_s2", "slp_time_s2")
  )
  expect_equal(
    survival_model_outcome_vars,
    c("dem_or_mci_status", "dem_or_mci_surv_date", "death_status", "death_date")
  )
  expect_true(all(sleep_exposure_vars %in% imputation_no_impute_vars()))
  expect_true(all(survival_model_outcome_vars %in% imputation_no_impute_vars()))
  expect_true(all(sleep_history_spline_vars %in% sleep_history_model_vars))
  expect_false("slp_time" %in% imputation_predictor_vars())
  expect_false("slp_time_s2" %in% imputation_predictor_vars())
})
