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

test_that("imputation spec limits educat predictors to the curated set", {
  dt_raw <- make_test_raw_dataset()
  prepared <- prepare_dataset(dt_raw)

  imp_cols <- intersect(
    c(
      "PID",
      "age_s1",
      "bmi_s1",
      "gender",
      "educat",
      "IDTYPE",
      "n1",
      "n2",
      "n3",
      "rem",
      "n1_s2",
      "n2_s2",
      "n3_s2",
      "rem_s2",
      "waso_s2",
      "slp_time_s2",
      "dem_or_mci_surv_date",
      "death_status",
      "death_date"
    ),
    names(prepared)
  )
  imp_dt <- prepared[, ..imp_cols]
  imp_dt[, log_dem_time := log(dem_or_mci_surv_date)]

  meth <- make_imputation_methods(imp_dt)
  pred <- make_imputation_predictor_matrix(imp_dt)

  expect_equal(unname(meth["educat"]), "pmm")
  expect_true(all(meth[setdiff(names(meth), "educat")] == ""))
  expect_false("IDTYPE" %in% names(which(pred["educat", ] == 1)))
  expect_false("slp_time" %in% names(which(pred["educat", ] == 1)))
  expect_false("slp_time_s2" %in% names(which(pred["educat", ] == 1)))
  expect_false("dem_or_mci_status" %in% names(which(pred["educat", ] == 1)))
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

  imp <- suppressWarnings(impute_data(prepared, m = 2, maxit = 1))
  imputed <- complete_imputed_dataset(imp = imp, dt = prepared, action = 1)

  expect_s3_class(imp, "mids")
  expect_equal(imp$m, 2L)
  expect_equal(imputed$s1_incomplete, prepared$s1_incomplete)
  expect_equal(imputed$slp_time, prepared$slp_time)
  expect_equal(imputed$n1, prepared$n1)
  expect_equal(imputed$n2, prepared$n2)
  expect_equal(imputed$n3, prepared$n3)
  expect_equal(imputed$rem, prepared$rem)
  expect_false(anyNA(imputed$educat))
})

test_that("complete_imputed_datasets materializes one ILR-ready dataset per imputation", {
  dt_raw <- make_test_raw_dataset()
  dt_raw <- data.table::rbindlist(
    list(
      dt_raw,
      data.table::copy(dt_raw)[, `:=`(
        PID = PID + 2L,
        age_s1 = age_s1 + 4,
        bmi_s1 = bmi_s1 + 2,
        educat = educat + 1L,
        DEM_SURVDATE = DEM_SURVDATE + 60
      )]
    ),
    use.names = TRUE
  )
  dt_raw[2, educat := NA_integer_]
  prepared <- prepare_dataset(dt_raw)
  imp <- suppressWarnings(impute_data(prepared, m = 3, maxit = 1))

  completed <- complete_imputed_datasets(imp = imp, dt = prepared)

  expect_length(completed, 3L)
  expect_true(all(vapply(completed, data.table::is.data.table, logical(1))))
  expect_true(all(vapply(completed, function(x) !anyNA(x$educat), logical(1))))
  expect_true(all(vapply(
    completed,
    function(x) all(ilr_names %in% names(x)),
    logical(1)
  )))
})
