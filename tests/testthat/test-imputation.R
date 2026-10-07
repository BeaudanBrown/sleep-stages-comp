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

test_that("prepared data retains DSE baseline and FLAIR follow-up WMH", {
  dt_raw <- make_test_raw_dataset()
  dt_raw[, FLAIR_wmh_1 := NA_real_]
  dt_raw[, FLAIR_wmh_2 := c(21, 22)]

  prepared <- prepare_dataset(dt_raw, sub("_s2$", "", comp_vars), get_sbp())

  expect_false("FLAIR_wmh_s1" %in% names(prepared))
  expect_equal(prepared$DSE_wmh_s1, c(10, 12))
  expect_equal(prepared$FLAIR_wmh_s2, c(21, 22))
})
