test_that("analysis targets do not reference the legacy imp target", {
  path <- file.path(project_root, "analysis_targets.R")
  lines <- readLines(path, warn = FALSE)
  token_matches <- gregexpr(
    "(?<![[:alnum:]_])imp(?![[:alnum:]_])",
    lines,
    perl = TRUE
  )

  expect_false(any(unlist(token_matches) > 0))
})

test_that("shared MI helper combiners are conservative and deterministic", {
  cuts <- list(c(0, 10, 20), c(0, 10, 20))
  expect_equal(combine_timegroup_cuts(cuts), c(0, 10, 20))

  surv_cols <- list(
    list(
      outcome = c("Y_1", "Y_2", "Y_3"),
      cens = c("C_1", "C_2", "C_3"),
      compete = c("D_1", "D_2", "D_3")
    ),
    list(
      outcome = c("Y_1", "Y_2"),
      cens = c("C_1", "C_2"),
      compete = c("D_1", "D_2")
    )
  )
  expect_equal(
    combine_lmtp_surv_cols(surv_cols),
    list(
      outcome = c("Y_1", "Y_2"),
      cens = c("C_1", "C_2"),
      compete = c("D_1", "D_2")
    )
  )

  limits_a <- list(
    n1_s2 = list(lower = 5, upper = 50),
    n2_s2 = list(lower = 10, upper = 60)
  )
  limits_b <- list(
    n1_s2 = list(lower = 7, upper = 45),
    n2_s2 = list(lower = 9, upper = 55)
  )
  expect_equal(
    combine_imputation_comp_limits(list(limits_a, limits_b)),
    list(
      n1_s2 = list(lower = 7, upper = 45),
      n2_s2 = list(lower = 10, upper = 55)
    )
  )
})

test_that("shared comparison contract can be built from completed datasets", {
  dt <- make_test_model_dt()
  substitutions <- data.table::data.table(
    from = c("n1_s2", "n1_s2", "n1_s2"),
    to = c("n2_s2", "n2_s2", "n2_s2"),
    duration = c(-15L, 0L, 15L)
  )

  contract <- build_shared_comparison_contract(
    dt_list = list(data.table::copy(dt), data.table::copy(dt)),
    substitutions = substitutions
  )

  expect_equal(contract$substitutions, substitutions)
  expect_equal(contract$trt_cols, ilr_names)
  expect_true(all(
    c("n1", "n2", "n3", "rem", "slp_time_s2", "s1_incomplete") %in%
      contract$baseline_covars
  ))
})
