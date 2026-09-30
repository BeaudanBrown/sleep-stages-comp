test_that("make_ilrs returns named ILR coordinates with expected dimensions", {
  dt <- make_test_comp_dt()

  ilrs <- make_ilrs(dt, comp_vars, get_sbp())

  expect_s3_class(ilrs, "data.table")
  expect_equal(ncol(ilrs), length(ilr_names))
  expect_named(ilrs, paste0("R", 1:4))
  expect_equal(nrow(ilrs), nrow(dt))
  expect_true(all(vapply(ilrs, is.numeric, logical(1))))
})

test_that("composition constants stay on the 5-part SHHS-2 exposure contract", {
  expect_equal(
    comp_vars,
    c("n1_s2", "n2_s2", "n3_s2", "waso_s2", "rem_s2")
  )
  expect_equal(length(ilr_names), 4L)
  expect_equal(dim(get_sbp()), c(5L, 4L))
})

test_that("make_ilrs is deterministic for identical input", {
  dt <- make_test_comp_dt()

  ilrs_first <- make_ilrs(dt, comp_vars, get_sbp())
  ilrs_second <- make_ilrs(dt, comp_vars, get_sbp())

  expect_equal(ilrs_first, ilrs_second)
})
