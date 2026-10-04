test_that("fixed compositions update duration and modeled ILR coordinates", {
  comp_vars <- c("n1_s2", "n2_s2", "n3_s2", "waso_s2", "rem_s2")
  ilr_names <- paste0("R", 1:4, "_s2")
  dt <- make_test_comp_dt()
  dt[, slp_time_s2 := n1_s2 + n2_s2 + n3_s2 + rem_s2]
  dt[, (ilr_names) := make_ilrs(dt, comp_vars, get_sbp())]
  composition <- data.table(
    n1_s2 = 30,
    n2_s2 = 180,
    n3_s2 = 90,
    waso_s2 = 45,
    rem_s2 = 75
  )

  shifted <- apply_fixed_composition(
    dt,
    composition,
    comp_vars,
    get_sbp()
  )

  expect_equal(unique(shifted$slp_time_s2), 375)
  expect_equal(uniqueN(shifted[, ..ilr_names]), 1L)
  repeated_composition <- rbindlist(list(composition, composition))
  expected_ilrs <- make_ilrs(repeated_composition, comp_vars, get_sbp())
  setnames(expected_ilrs, ilr_names)
  expect_equal(
    shifted[1, ..ilr_names],
    expected_ilrs[1]
  )
})

test_that("composition-grid evaluation finds known best and worst policies", {
  comp_vars <- c("n1_s2", "n2_s2", "n3_s2", "waso_s2", "rem_s2")
  ilr_names <- paste0("R", 1:4, "_s2")
  dt <- make_test_comp_dt()
  dt[, slp_time_s2 := n1_s2 + n2_s2 + n3_s2 + rem_s2]
  dt[, (ilr_names) := make_ilrs(dt, comp_vars, get_sbp())]
  dt[, outcome_value := 2 * R1_s2]
  fitted_model <- list(
    model = lm(outcome_value ~ R1_s2, data = dt),
    outcome = "outcome_value"
  )
  grid <- data.table(
    n1_s2 = c(60, 20),
    n2_s2 = c(180, 180),
    n3_s2 = c(40, 100),
    waso_s2 = c(40, 40),
    rem_s2 = c(80, 80)
  )

  predictions <- evaluate_composition_grid(
    dt,
    grid,
    fitted_model,
    comp_vars,
    get_sbp()
  )

  expect_equal(predictions[which.max(mean_outcome_pred)]$n3_s2, 100)
  expect_equal(predictions[which.min(mean_outcome_pred)]$n3_s2, 40)
})

test_that("fixed-composition estimates retain policy contrasts", {
  comp_vars <- c("n1_s2", "n2_s2", "n3_s2", "waso_s2", "rem_s2")
  ilr_names <- paste0("R", 1:4, "_s2")
  dt <- make_test_comp_dt()
  dt[, slp_time_s2 := n1_s2 + n2_s2 + n3_s2 + rem_s2]
  dt[, (ilr_names) := make_ilrs(dt, comp_vars, get_sbp())]
  dt[, outcome_value := R1_s2]
  fitted_model <- list(
    model = lm(outcome_value ~ R1_s2, data = dt),
    outcome = "outcome_value"
  )
  compositions <- data.table(
    policy = c("best", "worst"),
    n1_s2 = c(20, 60),
    n2_s2 = 180,
    n3_s2 = c(100, 40),
    waso_s2 = 40,
    rem_s2 = 80
  )
  reference <- gcomp(fitted_model, dt)
  reference[, imputation_id := "1"]

  estimates <- compute_composition_table(
    dt,
    compositions,
    fitted_model,
    reference,
    comp_vars,
    get_sbp()
  )

  expect_equal(estimates$policy, c("best", "worst"))
  expect_equal(estimates$mean_difference, estimates$pred - reference$pred)
  expect_equal(estimates$imputation_id, rep("1", 2))
})

test_that("split-specific TST extremes are evaluated on their held-out model", {
  comp_vars <- c("n1_s2", "n2_s2", "n3_s2", "waso_s2", "rem_s2")
  ilr_names <- paste0("R", 1:4, "_s2")
  test_data <- make_test_comp_dt()
  test_data[, slp_time_s2 := n1_s2 + n2_s2 + n3_s2 + rem_s2]
  test_data[, (ilr_names) := make_ilrs(test_data, comp_vars, get_sbp())]
  test_data[, outcome_value := 2 * R1_s2]
  fitted_model <- list(
    model = lm(outcome_value ~ R1_s2, data = test_data),
    outcome = "outcome_value"
  )
  selections <- data.table(
    split_id = c(1L, 1L, 2L, 1L),
    outcome = c("outcome_value", "outcome_value", "outcome_value", "other"),
    tst_minutes = 380L,
    policy = c("best", "worst", "best", "best"),
    n1_s2 = c(20, 60, 40, 40),
    n2_s2 = 180,
    n3_s2 = c(100, 60, 80, 80),
    waso_s2 = 40,
    rem_s2 = 80,
    mean_outcome_pred = c(100, -100, 999, 999)
  )
  split_fit <- list(
    split_id = 1L,
    outcome = "outcome_value",
    test_data = test_data,
    model = fitted_model
  )

  estimates <- evaluate_ideal_split_extremes_by_tst(
    selections,
    split_fit,
    comp_vars,
    get_sbp()
  )
  expected <- evaluate_composition_grid(
    test_data,
    selections[1:2, ..comp_vars],
    fitted_model,
    comp_vars,
    get_sbp()
  )$mean_outcome_pred

  expect_equal(estimates$policy, c("best", "worst"))
  expect_equal(estimates$tst_minutes, c(380L, 380L))
  expect_equal(estimates$mean_outcome_pred_train, c(100, -100))
  expect_equal(estimates$mean_outcome_pred_test, expected)
  expect_equal(
    estimates$mean_difference_test,
    expected - gcomp(fitted_model, test_data)$pred
  )

  split_fit$split_id <- 3L
  unsupported <- evaluate_ideal_split_extremes_by_tst(
    selections,
    split_fit,
    comp_vars,
    get_sbp()
  )
  expect_equal(nrow(unsupported), 0L)
  expect_true(all(
    c(
      "mean_outcome_pred_train",
      "mean_outcome_pred_test",
      "mean_outcome_pred_no_int_test",
      "mean_difference_test"
    ) %in%
      names(unsupported)
  ))
})
