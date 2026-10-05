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
  expect_false(any(c("waso", "R4_s1", "R4_s2") %in% vars))
  expect_equal(intersect(vars, paste0("R", 1:3, "_s2")), paste0("R", 1:3, "_s2"))

  dt <- as.data.table(setNames(
    rep(list(seq_len(20)), length(vars)),
    vars
  ))
  formula <- get_primary_formula_cont(dt)
  terms <- attr(terms(formula), "term.labels")
  expect_true(any(grepl("rcs\\(waso_s2,", terms)))
  expect_false(any(grepl("R4|rcs\\(waso,", terms)))
})
