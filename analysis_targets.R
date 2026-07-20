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
            comp_hull = substitution_masks_always,
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
  )
)
