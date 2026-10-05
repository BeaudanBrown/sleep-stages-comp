summarize_analysis_covariates <- function(dt, outcome_vars) {
  model_vars <- continuous_model_vars()
  stage_vars <- c("n1", "n2", "n3", "waso", "rem")
  table_vars <- c(
    paste0(stage_vars, "_s2"),
    "slp_time_s2",
    stage_vars,
    "slp_time",
    setdiff(
      model_vars,
      c(grep("^R[1-3]_s[12]$", model_vars, value = TRUE), "waso_s2", "slp_time_s2", "slp_time")
    ),
    outcome_vars
  )
  binary_vars <- continuous_binary_vars()
  continuous_vars <- setdiff(table_vars, binary_vars)
  # Derive both cognitive scores from recorded tests, retaining missing values.
  data <- get_cog_score(copy(dt))[, ..table_vars]
  data[, (binary_vars) := lapply(.SD, factor), .SDcols = binary_vars]

  labels <- c(
    n1_s2 = "SHHS-2 N1 (minutes)",
    n2_s2 = "SHHS-2 N2 (minutes)",
    n3_s2 = "SHHS-2 N3 (minutes)",
    waso_s2 = "SHHS-2 WASO (minutes)",
    rem_s2 = "SHHS-2 REM (minutes)",
    slp_time_s2 = "SHHS-2 total sleep time (minutes)",
    n1 = "SHHS-1 N1 (minutes)",
    n2 = "SHHS-1 N2 (minutes)",
    n3 = "SHHS-1 N3 (minutes)",
    waso = "SHHS-1 WASO (minutes)",
    rem = "SHHS-1 REM (minutes)",
    slp_time = "SHHS-1 total sleep time (minutes)",
    s1_incomplete = "Incomplete SHHS-1 sleep recording",
    pc1_s1 = "Baseline cognitive summary score",
    Cerebrum_tcv_s1 = "Baseline cerebral volume (Cerebrum_tcv)",
    Cerebrum_tcb_s1 = "Baseline cerebral brain volume (Cerebrum_tcb)",
    Hippo_s1 = "Baseline hippocampal volume",
    age_s1 = "Age at SHHS-1 (years)",
    gender = "Sex (recorded code)",
    bmi_s1 = "BMI at SHHS-1 (kg/m²)",
    oahi = "Obstructive apnoea–hypopnoea index",
    sleeping_pills = "Sleeping-pill use (recorded code)",
    hypertension = "Hypertension (recorded code)",
    pc1_s2 = "Follow-up cognitive summary score",
    Hippo_s2 = "Follow-up hippocampal volume",
    Cerebrum_tcb_s2 = "Follow-up cerebral brain volume (Cerebrum_tcb)"
  )

  gtsummary::tbl_summary(
    data,
    label = as.list(labels),
    type = c(
      setNames(as.list(rep("continuous", length(continuous_vars))), continuous_vars),
      setNames(as.list(rep("categorical", length(binary_vars))), binary_vars)
    ),
    statistic = list(
      gtsummary::all_continuous() ~ "{mean} ({sd})",
      gtsummary::all_categorical() ~ "{n} ({p}%)"
    ),
    digits = gtsummary::all_continuous() ~ 2,
    missing = "always",
    missing_text = "Missing",
    missing_stat = "{N_miss}"
  ) |>
    gtsummary::modify_caption(
      "**Cohort characteristics and follow-up outcomes, before imputation**"
    ) |>
    gtsummary::bold_labels()
}
