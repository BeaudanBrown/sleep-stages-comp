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
    n_total = coverage$n_total
  )]

  rbindlist(
    list(
      ref_dt,
      int_dt
    ),
    fill = TRUE
  )
}

gcomp <- function(model, newdata) {
  pred <- mean(predict(model$model, newdata = newdata))
  outcome <- model$outcome
  data.table(outcome = outcome, pred = pred)
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
