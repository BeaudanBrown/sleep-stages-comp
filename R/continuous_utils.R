compute_substitution_table <- function(
  dt,
  substitutions,
  comp_hull,
  fitted_models,
  ref_dt,
  comp_vars,
  ilr_base
) {
  res_list <- lapply(seq_len(nrow(substitutions)), function(i) {
    row <- substitutions[i]
    compute_substituted_mean(
      dt,
      row$from,
      row$to,
      row$duration,
      comp_hull,
      fitted_models,
      ref_dt,
      comp_vars = comp_vars,
      ilr_base = ilr_base
    )
  })

  out <- data.table::rbindlist(res_list)
  out
}

compute_substituted_mean <- function(
  dt,
  from,
  to,
  duration,
  comp_hull,
  fitted_models,
  ref_dt,
  comp_vars,
  ilr_base
) {
  sub_dt <- compute_shifted_exposures(
    dt,
    from,
    to,
    duration,
    comp_hull,
    comp_vars,
    ilr_base
  )
  sub_dt <- update_continuous_sleep_duration(sub_dt, from, to)

  int_dt <- gcomp(
    fitted_models,
    sub_dt
  )

  coverage <- summarize_substitution_coverage(sub_dt)

  int_dt[, `:=`(
    from = from,
    to = to,
    duration = duration,
    n_intervened = coverage$n_intervened,
    n_total = coverage$n_total,
    mean_applied_duration = coverage$mean_applied_duration
  )]

  reference_index <- match(int_dt$outcome, ref_dt$outcome)
  int_dt[, `:=`(
    mean_difference = pred - ref_dt$pred[reference_index],
    imputation_id = ref_dt$imputation_id[reference_index]
  )]

  int_dt
}

update_continuous_sleep_duration <- function(dt, from, to) {
  out <- copy(dt)
  from_is_sleep <- as.integer(from != "waso_s2")
  to_is_sleep <- as.integer(to != "waso_s2")
  tst_delta <- out[["applied_duration"]] * (to_is_sleep - from_is_sleep)

  out[["slp_time_s2"]] <- out[["slp_time_s2"]] + tst_delta
  out
}

gcomp <- function(model, newdata) {
  pred <- mean(predict(model$model, newdata = newdata))
  outcome <- model$outcome
  data.table(outcome = outcome, pred = pred)
}

apply_fixed_composition <- function(
  dt,
  composition,
  comp_vars,
  ilr_base
) {
  out <- copy(dt)
  for (var in comp_vars) {
    set(out, j = var, value = composition[[var]][1L])
  }

  sleep_stage_vars <- setdiff(comp_vars, "waso_s2")
  out[, slp_time_s2 := rowSums(.SD), .SDcols = sleep_stage_vars]

  ilr_names <- paste0("R", seq_len(length(comp_vars) - 1L), "_s2")
  out[, (ilr_names) := make_ilrs(out, comp_vars, ilr_base)]
  out
}

evaluate_composition_grid <- function(
  dt,
  composition_grid,
  fitted_model,
  comp_vars,
  ilr_base
) {
  rbindlist(lapply(seq_len(nrow(composition_grid)), function(i) {
    composition <- composition_grid[i]
    intervention_dt <- apply_fixed_composition(
      dt,
      composition,
      comp_vars,
      ilr_base
    )

    cbind(
      composition,
      mean_cog_pred = gcomp(fitted_model, intervention_dt)$pred
    )
  }))
}

fit_ideal_composition_split <- function(
  dt,
  split_id,
  comp_vars,
  ilr_base,
  support_k,
  support_quantile
) {
  train_imp <- as.data.table(impute_data(dt, method = "cart", m = 1)[[1L]])
  train_cog <- get_cog_score(train_imp)

  list(
    split_id = split_id,
    train_cog = train_cog,
    model = fit_models_cont(train_cog, outcome = "pc1_s2"),
    support = fit_knn_composition_support(
      dt,
      comp_vars,
      ilr_base,
      support_k,
      support_quantile
    )
  )
}

evaluate_ideal_composition_split_batch <- function(
  composition_grid,
  split_fit,
  comp_vars,
  ilr_base
) {
  supported_grid <- filter_knn_composition_support(
    composition_grid,
    split_fit$support,
    comp_vars,
    ilr_base
  )
  if (nrow(supported_grid) == 0L) {
    return(data.table())
  }

  predictions <- evaluate_composition_grid(
    split_fit$train_cog,
    supported_grid,
    split_fit$model,
    comp_vars,
    ilr_base
  )
  predictions[, split_id := split_fit$split_id]
  predictions[unique(c(
    which.max(mean_cog_pred),
    which.min(mean_cog_pred)
  ))]
}

compute_composition_table <- function(
  dt,
  compositions,
  fitted_model,
  ref_dt,
  comp_vars,
  ilr_base
) {
  composition_vars <- comp_vars
  rbindlist(lapply(seq_len(nrow(compositions)), function(i) {
    composition <- compositions[i]
    intervention_dt <- apply_fixed_composition(
      dt,
      composition,
      comp_vars,
      ilr_base
    )
    estimate <- gcomp(fitted_model, intervention_dt)
    reference_index <- match(estimate$outcome, ref_dt$outcome)

    estimate[, `:=`(
      policy = composition$policy,
      mean_difference = pred - ref_dt$pred[reference_index],
      imputation_id = ref_dt$imputation_id[reference_index]
    )]
    estimate[, (composition_vars) := composition[, .SD, .SDcols = composition_vars]]
    estimate
  }))
}

fit_models_cont <- function(dt, outcome) {
  model_formula <- get_primary_formula_cont(dt)

  outcome_model_formula <- update(
    model_formula,
    paste0(outcome, " ~ . ")
  )

  model <- strip_lm(lm(outcome_model_formula, data = dt))

  list(model = model, outcome = outcome)
}

get_primary_formula_cont <- function(dt) {
  model_vars <- c(
    "R1_s2",
    "R2_s2",
    "R3_s2",
    "R4_s2",
    "slp_time_s2",
    "R1_s1",
    "R2_s1",
    "R3_s1",
    "R4_s1",
    "slp_time",
    "s1_incomplete",
    "pc1_s1",
    "Cerebrum_tcv_s1",
    "Cerebrum_tcb_s1",
    "Hippo_s1",
    "age_s1",
    "gender",
    "bmi_s1",
    "oahi",
    "sleeping_pills",
    "hypertension"
  )
  binary_vars <- c(
    "s1_incomplete",
    "gender",
    "sleeping_pills",
    "hypertension"
  )
  spline_vars <- setdiff(model_vars, binary_vars)

  for (var in spline_vars) {
    assign(
      paste0("knots_", var),
      quantile(dt[[var]], c(0.1, 0.5, 0.9), na.rm = TRUE)
    )
  }

  spline_terms <- setNames(
    paste0(
      "rcs(",
      spline_vars,
      ", knots_",
      spline_vars,
      ")"
    ),
    spline_vars
  )
  model_terms <- vapply(
    model_vars,
    \(var) {
      if (var %in% binary_vars) var else spline_terms[[var]]
    },
    character(1)
  )

  reformulate(model_terms, response = "Y")
}
