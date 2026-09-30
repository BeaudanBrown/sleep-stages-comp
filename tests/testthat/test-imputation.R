test_that("prepare_dataset recovers missing slp_time from observed S1 stage reads", {
  dt_raw <- make_test_raw_dataset()

  prepared <- prepare_dataset(dt_raw, sub("_s2$", "", comp_vars), get_sbp())

  expect_equal(prepared$s1_incomplete, c(0L, 1L))
  expect_equal(prepared$slp_time, c(400, 385))
  expect_equal(
    prepared[2, slp_time],
    prepared[2, n1 + n2 + n3 + rem]
  )
})
