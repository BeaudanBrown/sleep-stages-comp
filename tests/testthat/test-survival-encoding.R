test_that("make_cuts returns increasing finite cut points from follow-up", {
  dt <- make_test_survival_dt()

  cuts <- make_cuts(dt)

  expect_true(is.numeric(cuts))
  expect_true(all(is.finite(cuts)))
  expect_true(length(cuts) >= 2)
  expect_equal(cuts[1], 0)
  expect_true(all(diff(cuts) > 0))
  expect_equal(max(cuts), max(dt$dem_or_mci_surv_date))
})

test_that("make_cuts works when there are no dementia events", {
  dt <- make_test_survival_dt()
  dt[, dem_or_mci_status := 0]

  cuts <- make_cuts(dt)

  expect_true(all(is.finite(cuts)))
  expect_true(length(cuts) >= 2)
  expect_equal(max(cuts), max(dt$dem_or_mci_surv_date))
})

test_that("expand_surv_dt creates ordered timegroups and mutually exclusive events", {
  dt <- make_test_survival_dt()
  cuts <- make_test_timegroup_cuts()

  surv_dt <- expand_surv_dt(dt, cuts)

  expect_s3_class(surv_dt, "data.table")
  expect_true(all(diff(surv_dt[PID == 1, timegroup]) > 0))
  expect_true(all(surv_dt$death %in% c(0, 1)))
  expect_true(all(surv_dt$dem_or_mci %in% c(0, 1)))
  expect_false(any(surv_dt$death == 1 & surv_dt$dem_or_mci == 1))

  expect_equal(surv_dt[PID == 1, dem_or_mci], c(0, 1))
  expect_equal(surv_dt[PID == 2, death], c(0, 1))
})

test_that("make_surv_wide carries forward outcomes and uses lmtp censoring convention", {
  dt <- make_test_survival_dt()
  cuts <- make_test_timegroup_cuts()

  surv_dt <- expand_surv_dt(dt, cuts)
  wide <- suppressWarnings(make_surv_wide(surv_dt))

  expect_true(all(
    c("Y_1", "Y_2", "Y_3", "D_1", "D_2", "D_3", "C_1", "C_2", "C_3") %in%
      names(wide)
  ))

  expect_equal(
    as.numeric(wide[wide$PID == 1, c("Y_1", "Y_2", "Y_3")]),
    c(0, 1, 1)
  )
  expect_equal(
    as.numeric(wide[wide$PID == 2, c("D_1", "D_2", "D_3")]),
    c(0, 1, 1)
  )

  expect_equal(
    as.numeric(wide[wide$PID == 1, c("C_1", "C_2", "C_3")]),
    c(1, 1, 0)
  )
  expect_equal(
    as.numeric(wide[wide$PID == 2, c("C_1", "C_2", "C_3")]),
    c(1, 1, 0)
  )
  expect_equal(
    as.numeric(wide[wide$PID == 3, c("C_1", "C_2", "C_3")]),
    c(1, 1, 1)
  )
})

test_that("get_lmtp_surv_cols returns aligned ordered survival columns", {
  dt <- make_test_survival_dt()
  cuts <- make_test_timegroup_cuts()

  surv_dt <- expand_surv_dt(dt, cuts)
  wide <- suppressWarnings(make_surv_wide(surv_dt))
  cols <- get_lmtp_surv_cols(wide)

  expect_named(cols, c("outcome", "cens", "compete"))
  expect_equal(cols$outcome, c("Y_1", "Y_2", "Y_3"))
  expect_equal(cols$cens, c("C_1", "C_2", "C_3"))
  expect_equal(cols$compete, c("D_1", "D_2", "D_3"))
})
