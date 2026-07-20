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

  expect_equal(predictions[which.max(mean_cog_pred)]$n3_s2, 100)
  expect_equal(predictions[which.min(mean_cog_pred)]$n3_s2, 40)
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
