test_that("make_ilrs returns named ILR coordinates with expected dimensions", {
  dt <- make_test_comp_dt()

  ilrs <- make_ilrs(dt, comp_vars, get_sbp())

  expect_s3_class(ilrs, "data.table")
  expect_equal(ncol(ilrs), length(ilr_names))
  expect_named(ilrs, paste0("R", 1:3))
  expect_equal(nrow(ilrs), nrow(dt))
  expect_true(all(vapply(ilrs, is.numeric, logical(1))))
})

test_that("composition constants stay on the four-stage SHHS-2 exposure contract", {
  expect_equal(
    comp_vars,
    c("n1_s2", "n2_s2", "n3_s2", "rem_s2")
  )
  expect_equal(length(ilr_names), 3L)
  expect_equal(dim(get_sbp()), c(4L, 3L))
})

test_that("make_ilrs is deterministic for identical input", {
  dt <- make_test_comp_dt()

  ilrs_first <- make_ilrs(dt, comp_vars, get_sbp())
  ilrs_second <- make_ilrs(dt, comp_vars, get_sbp())

  expect_equal(ilrs_first, ilrs_second)
})

test_that("continuous model adjusts for SHHS-2 WASO with three ILRs", {
  vars <- continuous_model_vars()
  expect_true("waso_s2" %in% vars)
  expect_true("edu_years" %in% vars)
  expect_false("educat" %in% vars)
  expect_false(any(c("waso", "R4_s1", "R4_s2") %in% vars))
  expect_equal(intersect(vars, paste0("R", 1:3, "_s2")), paste0("R", 1:3, "_s2"))

  dt <- as.data.table(setNames(
    rep(list(seq_len(20)), length(vars)),
    vars
  ))
  dt[, pc1_s1 := seq_len(.N)]
  formula <- get_primary_formula_cont(dt, "pc1_s2")
  terms <- attr(terms(formula), "term.labels")
  expect_true(any(grepl("rcs\\(waso_s2,", terms)))
  expect_true("edu_years" %in% terms)
  expect_false(any(grepl("R4|rcs\\(waso,", terms)))
})

test_that("continuous formulas use DSE baseline WMH for the FLAIR outcome", {
  cog_vars <- continuous_model_vars()
  mri_vars <- continuous_model_vars_mri()
  outcomes <- c("pc1_s2", "Hippo_s2", "Cerebrum_tcb_s2", "FLAIR_wmh_s2")
  baselines <- c("pc1_s1", "Hippo_s1", "Cerebrum_tcb_s1", "DSE_wmh_s1")
  dt <- as.data.table(setNames(
    rep(list(seq_len(20)), length(unique(c(cog_vars, mri_vars, baselines)))),
    unique(c(cog_vars, mri_vars, baselines))
  ))

  for (i in seq_along(outcomes)) {
    formula_vars <- all.vars(get_primary_formula_cont(dt, outcomes[i]))
    formula_vars <- setdiff(formula_vars[!startsWith(formula_vars, "knots_")], "Y")
    expected_vars <- if (outcomes[i] == "pc1_s2") cog_vars else mri_vars
    expect_setequal(formula_vars, c(expected_vars, baselines[i]))
  }
})
