test_that("analysis targets do not reference single-imputation helpers", {
  path <- file.path(project_root, "analysis_targets.R")
  lines <- readLines(path, warn = FALSE)

  disallowed_patterns <- c(
    "complete_imputed_dataset\\s*\\(",
    "action\\s*=\\s*1",
    "tryCatch\\s*\\("
  )

  matches <- vapply(
    disallowed_patterns,
    function(pattern) {
      any(grepl(pattern, lines, perl = TRUE))
    },
    logical(1)
  )
  expect_false(any(matches))
})

test_that("bootstrap targets expose resampling, imputation, completion, and averaging", {
  path <- file.path(project_root, "analysis_targets.R")
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")

  expected_targets <- c(
    "boot_resampled_dt",
    "boot_imp_mids",
    "boot_imp_datasets",
    "boot_substituted_risk_by_imputation",
    "boot_substituted_risk"
  )

  for (target_name in expected_targets) {
    expect_match(text, sprintf("tar_target\\(\\s*%s\\b", target_name))
  }

  expect_match(text, "bootstrap_resample\\(dt, bootstrap_seeds\\)")
  expect_match(text, "impute_data\\(boot_resampled_dt")
  expect_match(text, "complete_imputed_datasets\\(imp = boot_imp_mids")
  expect_match(text, "compute_bootstrap_substitution_risk_by_imputation\\(")
  expect_match(text, "average_bootstrap_substitution_replicate\\(")
})

test_that("bootstrapping executes raw-data resample before imputation and branch fitting", {
  calls <- character()
  substitutions <- data.table::data.table(
    from = "n1_s2",
    to = "n2_s2",
    duration = 0L
  )
  base_dt <- data.table::data.table(
    PID = c(1L, 2L, 3L),
    val = c(1.0, 2.0, 3.0)
  )

  original_bindings <- list(
    bootstrap_resample = bootstrap_resample,
    impute_data = impute_data,
    complete_imputed_datasets = complete_imputed_datasets,
    make_cuts = make_cuts,
    fit_models = fit_models,
    predict_risks = predict_risks,
    compute_substitution_risk_table = compute_substitution_risk_table
  )

  assign(
    "bootstrap_resample",
    function(dt, seed) {
      calls <<- c(calls, "bootstrap_resample")
      data.table::data.table(
        dt,
        PID_original = dt$PID
      )
    },
    envir = globalenv()
  )
  assign(
    "impute_data",
    function(dt, m, maxit) {
      calls <<- c(calls, "impute_data")
      list(
        m = m,
        maxit = maxit,
        dt = dt
      )
    },
    envir = globalenv()
  )
  assign(
    "complete_imputed_datasets",
    function(imp, dt) {
      calls <<- c(calls, "complete_imputed_datasets")
      replicate(
        imp$m,
        data.table::copy(dt),
        simplify = FALSE
      )
    },
    envir = globalenv()
  )
  assign(
    "make_cuts",
    function(dt) {
      calls <<- c(calls, "make_cuts")
      c(0L, 1L)
    },
    envir = globalenv()
  )
  assign(
    "fit_models",
    function(dt, timegroup_cuts) {
      calls <<- c(calls, "fit_models")
      list(model = "pooled", rows = nrow(dt), cuts = timegroup_cuts)
    },
    envir = globalenv()
  )
  assign(
    "predict_risks",
    function(dt, fitted_models, timegroup_cuts) {
      calls <<- c(calls, "predict_risks")
      data.table::data.table(
        time = timegroup_cuts
      )
    },
    envir = globalenv()
  )
  assign(
    "compute_substitution_risk_table",
    function(
      dt,
      substitutions,
      comp_hull,
      fitted_models,
      timegroup_cuts,
      baseline_risk,
      imputation_id = NULL
    ) {
      calls <<- c(calls, "compute_substitution_risk_table")
      data.table::data.table(
        timegroup = timegroup_cuts,
        from = substitutions$from,
        to = substitutions$to,
        duration = substitutions$duration,
        mean_risk_baseline = 0.10,
        mean_risk_substituted = 0.11,
        n_intervened = 10L,
        n_total = 20L,
        imputation_id = as.character(imputation_id)
      )
    },
    envir = globalenv()
  )
  on.exit(
    {
      assign(
        "bootstrap_resample",
        original_bindings$bootstrap_resample,
        envir = globalenv()
      )
      assign("impute_data", original_bindings$impute_data, envir = globalenv())
      assign(
        "complete_imputed_datasets",
        original_bindings$complete_imputed_datasets,
        envir = globalenv()
      )
      assign("make_cuts", original_bindings$make_cuts, envir = globalenv())
      assign("fit_models", original_bindings$fit_models, envir = globalenv())
      assign(
        "predict_risks",
        original_bindings$predict_risks,
        envir = globalenv()
      )
      assign(
        "compute_substitution_risk_table",
        original_bindings$compute_substitution_risk_table,
        envir = globalenv()
      )
    },
    add = TRUE
  )

  out <- run_bootstrap_rep(
    dt = base_dt,
    substitutions = substitutions,
    comp_hull = data.table::data.table(
      from = "n1_s2",
      to = "n2_s2",
      duration = 0L,
      PID = as.character(base_dt$PID),
      substituted = TRUE
    ),
    seed = 123L,
    m = 2L,
    maxit = 3L
  )

  expect_s3_class(out, "data.table")
  expect_equal(
    calls,
    c(
      "bootstrap_resample",
      "impute_data",
      "complete_imputed_datasets",
      rep(
        c(
          "make_cuts",
          "fit_models",
          "predict_risks",
          "compute_substitution_risk_table"
        ),
        times = 2L
      )
    )
  )
  expect_equal(
    out$timegroup,
    c(0L, 1L)
  )
  expect_equal(out$bootstrap_seed, c(123L, 123L))
})

test_that("substitution risk tables can tag imputation branches internally", {
  original <- compute_substituted_risk
  assign(
    "compute_substituted_risk",
    function(
      dt,
      from,
      to,
      duration,
      comp_hull,
      fitted_models,
      timegroup_cuts,
      baseline_risk
    ) {
      data.table::data.table(
        timegroup = timegroup_cuts,
        from = from,
        to = to,
        duration = duration,
        mean_risk_baseline = 0.10,
        mean_risk_substituted = 0.11,
        n_intervened = 3L,
        n_total = 4L
      )
    },
    envir = globalenv()
  )
  on.exit(
    assign("compute_substituted_risk", original, envir = globalenv()),
    add = TRUE
  )

  out <- compute_substitution_risk_table(
    dt = data.table::data.table(),
    substitutions = data.table::data.table(
      from = "n1_s2",
      to = "n2_s2",
      duration = c(0L, 15L)
    ),
    comp_hull = list(),
    fitted_models = list(),
    timegroup_cuts = c(1L, 2L),
    baseline_risk = data.table::data.table(),
    imputation_id = 4L
  )

  expect_equal(nrow(out), 4L)
  expect_equal(unique(out$imputation_id), "4")
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
