test_that("continuous substitution estimates emit one tagged row per substitution", {
  comp_names <- c("n1_s2", "n2_s2", "n3_s2", "waso_s2", "rem_s2")
  model_ilr_names <- paste0("R", seq_len(length(comp_names) - 1L), "_s2")
  basis <- get_sbp()
  dt <- make_test_comp_dt()
  dt[, (model_ilr_names) := make_ilrs(dt, comp_names, basis)]
  dt[, outcome_value := 10 + 2 * R1_s2]

  fitted_model <- list(
    model = lm(outcome_value ~ R1_s2, data = dt),
    outcome = "outcome_value"
  )
  substitutions <- data.table::data.table(
    from = c("n2_s2", "n2_s2"),
    to = c("n3_s2", "n3_s2"),
    duration = c(15L, 30L)
  )
  masks <- make_test_substitution_masks(dt, substitutions)
  reference <- gcomp(fitted_model, dt)
  reference[, imputation_id := "2"]

  estimates <- compute_substitution_table(
    dt = dt,
    substitutions = substitutions,
    comp_hull = masks,
    fitted_models = fitted_model,
    ref_dt = reference,
    comp_vars = comp_names,
    ilr_base = basis
  )

  expect_equal(nrow(estimates), nrow(substitutions))
  expect_false(anyNA(estimates[, .(from, to, duration)]))
  expect_equal(sum(names(estimates) == "imputation_id"), 1L)
  expect_type(estimates$imputation_id, "character")
  expect_equal(unique(estimates$imputation_id), "2")
  expect_false("pred_reference" %in% names(estimates))
  expect_equal(estimates$mean_applied_duration, substitutions$duration)
  expect_equal(
    estimates$mean_difference,
    estimates$pred - reference$pred
  )
})
