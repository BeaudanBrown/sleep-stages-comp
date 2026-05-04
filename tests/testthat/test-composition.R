test_that("make_ilrs returns named ILR coordinates with expected dimensions", {
  dt <- make_test_comp_dt()

  ilrs <- make_ilrs(dt)

  expect_s3_class(ilrs, "data.table")
  expect_equal(ncol(ilrs), length(ilr_names))
  expect_named(ilrs, ilr_names)
  expect_equal(nrow(ilrs), nrow(dt))
  expect_true(all(vapply(ilrs, is.numeric, logical(1))))
})

test_that("composition constants stay on the 5-part SHHS-2 exposure contract", {
  expect_equal(
    comp_vars,
    c("n1_s2", "n2_s2", "n3_s2", "waso_s2", "rem_s2")
  )
  expect_equal(stage_labels[["waso_s2"]], "WASO")
  expect_equal(length(ilr_names), 4L)
  expect_equal(dim(sbp), c(4L, 5L))
})

test_that("make_ilrs is deterministic for identical input", {
  dt <- make_test_comp_dt()

  ilrs_first <- make_ilrs(dt)
  ilrs_second <- make_ilrs(dt)

  expect_equal(ilrs_first, ilrs_second)
})

test_that("make_comp_limits returns lower and upper bounds for each component", {
  dt <- make_test_comp_dt()

  limits <- make_comp_limits(dt)

  expect_named(limits, comp_vars)
  expect_true(all(vapply(
    limits,
    function(x) all(c("lower", "upper") %in% names(x)),
    logical(1)
  )))
  expect_true(all(vapply(limits, function(x) x$lower <= x$upper, logical(1))))
})

test_that("validate_comp_hull_input reports aggregate hull diagnostics", {
  dt <- make_test_comp_dt()
  dt[1, n1_s2 := NA_real_]

  diagnostics <- validate_comp_hull_input(dt)

  expect_named(
    diagnostics,
    c(
      "n_rows",
      "n_complete",
      "n_finite",
      "n_nonfinite",
      "n_unique_finite",
      "rank_finite",
      "n_vars",
      "min_total_minutes",
      "max_total_minutes"
    )
  )
  expect_equal(diagnostics$n_rows, 4L)
  expect_equal(diagnostics$n_complete, 3L)
  expect_equal(diagnostics$n_finite, 3L)
  expect_equal(diagnostics$n_nonfinite, 1L)
  expect_equal(diagnostics$n_vars, length(comp_vars))
})
