test_that("descriptive table reports raw stages, follow-up outcomes and missingness", {
  model_vars <- continuous_model_vars()
  stage_vars <- c("n1", "n2", "n3", "waso", "rem")
  outcome_vars <- c("pc1_s2", "Hippo_s2", "Cerebrum_tcb_s2")
  fixture_vars <- c(model_vars, stage_vars, paste0(stage_vars, "_s2"), outcome_vars)
  dt <- as.data.table(setNames(
    rep(list(seq_len(20)), length(fixture_vars)),
    fixture_vars
  ))
  binary_vars <- continuous_binary_vars()
  dt[, (binary_vars) := lapply(.SD, \(x) x %% 2), .SDcols = binary_vars]
  for (visit in c("s1", "s2")) {
    for (measure in c("TRAILSB", "LMI", "LMD", "VRI", "VRD", "SIM")) {
      dt[, (paste0(measure, "_", visit)) := seq_len(20)]
    }
  }
  dt[1, `:=`(age_s1 = NA_real_, LMI_s1 = NA_real_, LMI_s2 = NA_real_, Hippo_s2 = NA_real_)]
  original <- copy(dt)
  table <- summarize_analysis_covariates(dt, outcome_vars)
  body <- table$table_body

  expect_s3_class(table, "tbl_summary")
  expect_setequal(unique(body$variable), fixture_vars[!grepl("^R[1-4]_s[12]$", fixture_vars)])
  expect_false(any(grepl("ILR", body$label)))
  expect_equal(body[body$variable == "n1_s2" & body$row_type == "label", ]$stat_0, "10.50 (5.92)")
  expect_equal(body[body$variable == "age_s1" & body$row_type == "missing", ]$stat_0, "1")
  expect_equal(body[body$variable == "pc1_s1" & body$row_type == "missing", ]$stat_0, "1")
  expect_equal(body[body$variable == "pc1_s2" & body$row_type == "missing", ]$stat_0, "1")
  expect_equal(body[body$variable == "Hippo_s2" & body$row_type == "missing", ]$stat_0, "1")
  expect_equal(dt, original)
  formula_vars <- all.vars(get_primary_formula_cont(dt))
  expect_setequal(
    setdiff(formula_vars[!startsWith(formula_vars, "knots_")], "Y"),
    model_vars
  )
})
