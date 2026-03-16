test_that("prepare_dataset recovers missing slp_time from observed S1 stage reads", {
  dt_raw <- make_test_raw_dataset()

  prepared <- prepare_dataset(dt_raw)

  expect_equal(prepared$s1_incomplete, c(0L, 1L))
  expect_equal(prepared$slp_time, c(400, 385))
  expect_equal(
    prepared[2, slp_time],
    prepared[2, n1 + n2 + n3 + rem]
  )
})

test_that("impute_data preserves recorded S1 stage reads for incomplete rows", {
  dt_raw <- make_test_raw_dataset()
  dt_raw <- data.table::rbindlist(
    list(
      dt_raw,
      data.table::copy(dt_raw)[, `:=`(
        PID = PID + 2L,
        age_s1 = age_s1 + 3,
        bmi_s1 = bmi_s1 + 1,
        educat = educat + 2L,
        DEM_SURVDATE = DEM_SURVDATE + 50,
        n1 = n1 + 5,
        n2 = n2 - 5,
        n3 = n3 + 5,
        rem = rem - 5,
        n1_s2 = n1_s2 + 5,
        n2_s2 = n2_s2 - 5,
        n3_s2 = n3_s2 + 5,
        rem_s2 = rem_s2 - 5
      )]
    ),
    use.names = TRUE
  )
  dt_raw[2, educat := NA_integer_]
  prepared <- prepare_dataset(dt_raw)

  imputed <- suppressWarnings(impute_data(prepared, m = 1, maxit = 1))

  expect_equal(imputed$s1_incomplete, prepared$s1_incomplete)
  expect_equal(imputed$slp_time, prepared$slp_time)
  expect_equal(imputed$n1, prepared$n1)
  expect_equal(imputed$n2, prepared$n2)
  expect_equal(imputed$n3, prepared$n3)
  expect_equal(imputed$rem, prepared$rem)
  expect_false(anyNA(imputed$educat))
})
