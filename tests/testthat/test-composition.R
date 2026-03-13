test_that("make_ilrs returns named ILR coordinates with expected dimensions", {
  dt <- make_test_comp_dt()

  ilrs <- make_ilrs(dt)

  expect_s3_class(ilrs, "data.table")
  expect_equal(ncol(ilrs), length(ilr_names))
  expect_named(ilrs, ilr_names)
  expect_equal(nrow(ilrs), nrow(dt))
  expect_true(all(vapply(ilrs, is.numeric, logical(1))))
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
