analysis_targets <- list(
  tar_target(outcome_vars, c("pc1_s2", "Hippo_s2", "Cerebrum_tcb_s2")),

  # generate bootstrap samples
  tar_rep(
    dt_boot,
    command = {
      rows <- sample(1:nrow(dt), nrow(dt), replace = TRUE)
      data <- dt[rows, ]
      data[, PID_original := PID]
      data[, PID := seq_len(.N)]
      data[]
    },
    batches = 1000
  ),

  # impute missing data
  tar_target(
    dt_imp,
    impute_data(dt_boot, method = "cart"),
    pattern = map(dt_boot)
  ),
  # calculate cognitive summary score (see INSERT REF)
  tar_target(
    dt_imp_cog_score,
    lapply(dt_imp, \(imp) get_cog_score(as.data.table(imp))),
    pattern = map(dt_imp)
  ),
  # fit outcome model
  tar_target(
    outcome_models_cont,
    lapply(dt_imp_cog_score, fit_models_cont, outcome = outcome_vars),
    pattern = cross(dt_imp_cog_score, outcome_vars)
  ),
  # expected outcome under no intervention
  tar_target(
    mean_no_int,
    rbindlist(
      Map(gcomp, outcome_models_cont, dt_imp_cog_score),
      idcol = "imputation_id"
    ),
    pattern = map(
      outcome_models_cont,
      cross(dt_imp_cog_score, outcome_vars)
    )
  ),
  tar_target(
    estimates,
    {
      out <- rbindlist(
        lapply(seq_along(dt_imp_cog_score), \(i) {
          compute_substitution_table(
            dt = dt_imp_cog_score[[i]],
            substitutions = substitutions,
            comp_hull = comp_hull_masks,
            fitted_models = outcome_models_cont[[i]],
            ref_dt = mean_no_int[imputation_id == i],
            comp_vars = paste0(comp_vars, "_s2"),
            ilr_base = ilr_base
          )
        })
      )
      out[, B := unique(dt_imp_cog_score[[1]]$tar_batch)]
      out
    },
    pattern = map(
      outcome_models_cont,
      mean_no_int,
      cross(dt_imp_cog_score, outcome_vars)
    )
  ),
  tar_target(estimates_summary, summary_bootstrap_intervals(estimates)),
  tar_target(
    estimates_summary_by_pair,
    split(
      as.data.table(
        estimates_summary[
          parameter == "mean_difference" &
            (from %in% "n3_s2" | to %in% "n3_s2")
        ]
      ),
      by = c("from", "to", "outcome"),
      keep.by = TRUE
    ),
    iteration = "list"
  ),
  tar_target(
    estimates_summary_pair_plot,
    plot_continuous_summary_pair(
      estimates_summary_by_pair,
      labels = stage_labels,
      right_stage = "n3_s2"
    ),
    pattern = map(estimates_summary_by_pair),
    iteration = "list"
  ),

  ### Best and worst compositions
  # Split once so the two samples differ in size by at most one participant.
  tar_target(
    train_rows,
    sample(seq_len(nrow(dt)), size = nrow(dt) %/% 2L)
  ),
  tar_target(dt_train, dt[train_rows]),
  tar_target(dt_test, dt[-train_rows]),

  # Candidate policies are learned from training exposures only.
  tar_target(
    comp_grid,
    unique(
      dt_train[,
        lapply(.SD, \(comp) comp / slp_time_s2),
        .SDcols = paste0(comp_vars, "_s2")
      ]
    )
  ),

  # single imputation
  tar_target(
    dt_train_imp,
    as.data.table(impute_data(dt_train, method = "cart", m = 1)[[1L]])
  ),

  # fit model for cognitive outcome
  # calculate cognitive summary score (see INSERT REF)
  tar_target(dt_train_cog, get_cog_score(copy(dt_train_imp))),

  # fit outcome model
  tar_target(
    cog_model_train,
    fit_models_cont(dt_train_cog, outcome = "pc1_s2")
  ),

  # generate predictions under each of the compositions in the comp_grid
  tar_target(
    mean_cog_pred,
    evaluate_composition_grid(
      dt = dt_train_cog,
      composition_grid = comp_grid,
      fitted_model = cog_model_train,
      comp_vars = paste0(comp_vars, "_s2"),
      ilr_base = ilr_base
    )
  ),

  # return "best" and "worst" compositions W/R/T cognitive function
  tar_target(best_comp, mean_cog_pred[which.max(mean_cog_pred)]),
  tar_target(worst_comp, mean_cog_pred[which.min(mean_cog_pred)]),
  tar_target(
    extreme_compositions,
    rbindlist(list(
      copy(best_comp)[, policy := "best"],
      copy(worst_comp)[, policy := "worst"]
    ))[, mean_cog_pred := NULL]
  ),

  ## Evaluate the cognition-selected compositions in the testing data
  # generate bootstrap samples
  tar_rep(
    dt_test_boot,
    command = {
      rows <- sample(1:nrow(dt_test), nrow(dt_test), replace = TRUE)
      data <- dt_test[rows, ]
      data[, PID_original := PID]
      data[, PID := seq_len(.N)]
      data[]
    },
    batches = 1000
  ),

  # impute missing data
  tar_target(
    dt_test_imp,
    impute_data(dt_test_boot, method = "cart"),
    pattern = map(dt_test_boot)
  ),
  # calculate cognitive summary score
  tar_target(
    dt_test_cog,
    lapply(dt_test_imp, \(imp) get_cog_score(as.data.table(imp))),
    pattern = map(dt_test_imp)
  ),
  # fit outcome model
  tar_target(
    outcome_models_test,
    lapply(dt_test_cog, fit_models_cont, outcome = outcome_vars),
    pattern = cross(dt_test_cog, outcome_vars)
  ),
  # expected outcome under no intervention
  tar_target(
    mean_no_int_test,
    rbindlist(
      Map(gcomp, outcome_models_test, dt_test_cog),
      idcol = "imputation_id"
    ),
    pattern = map(
      outcome_models_test,
      cross(dt_test_cog, outcome_vars)
    )
  ),
  # expected outcome under best and worst compositions
  tar_target(
    estimates_test,
    {
      out <- rbindlist(
        lapply(seq_along(dt_test_cog), \(i) {
          compute_composition_table(
            dt = dt_test_cog[[i]],
            compositions = extreme_compositions,
            fitted_model = outcome_models_test[[i]],
            ref_dt = mean_no_int_test[imputation_id == i],
            comp_vars = paste0(comp_vars, "_s2"),
            ilr_base = ilr_base
          )
        })
      )
      out[, B := unique(dt_test_cog[[1]]$tar_batch)]
      out
    },
    pattern = map(
      outcome_models_test,
      mean_no_int_test,
      cross(dt_test_cog, outcome_vars)
    )
  ),
  tar_target(
    estimates_test_summary,
    summary_composition_bootstrap_intervals(
      estimates_test,
      comp_vars = paste0(comp_vars, "_s2")
    )
  )
)
