comp_vars <- c(
  "n1_s2",
  "n2_s2",
  "n3_s2",
  "waso_s2",
  "rem_s2"
)

ilr_names <- paste0("R", seq_len(length(comp_vars) - 1))

stage_labels <- c(
  n1_s2 = "N1",
  n2_s2 = "N2",
  n3_s2 = "N3",
  waso_s2 = "WASO",
  rem_s2 = "REM"
)

sleep_history_stage_vars <- c(
  "n1",
  "n2",
  "n3",
  "rem",
  "waso"
)

sleep_history_vars <- c(
  sleep_history_stage_vars,
  "slp_time"
)

sleep_duration_vars <- "slp_time_s2"

sleep_history_spline_vars <- c(
  "n1",
  "n2",
  "n3",
  "rem",
  sleep_duration_vars
)

sleep_history_model_vars <- c(
  sleep_history_spline_vars,
  "s1_incomplete"
)

sleep_exposure_vars <- unique(c(
  comp_vars,
  sleep_duration_vars
))

survival_outcome_vars <- c(
  "dem_or_mci_status",
  "dem_or_mci_surv_date"
)

competing_event_vars <- c(
  "death_status",
  "death_date"
)

survival_model_outcome_vars <- c(
  survival_outcome_vars,
  competing_event_vars
)

imputation_auxiliary_vars <- "log_dem_time"

imputation_no_impute_vars <- function() {
  unique(c(
    "PID",
    sleep_history_vars,
    sleep_exposure_vars,
    survival_model_outcome_vars,
    imputation_auxiliary_vars
  ))
}

imputation_predictor_vars <- function() {
  unique(c(
    "age_s1",
    "bmi_s1",
    "gender",
    sleep_history_stage_vars,
    comp_vars,
    survival_outcome_vars,
    competing_event_vars[[1L]],
    imputation_auxiliary_vars
  ))
}

# Component order is fixed: (N1, N2, N3, WASO, REM)
sbp <- matrix(
  c(
    -1,
    -1,
    1,
    1,
    0, # R1: (N1, N2) vs (N3, WASO)
    -1,
    0,
    0,
    1,
    1, # R2: N1 vs WASO, REM
    0,
    -1,
    1,
    0,
    1, # R3: N2 vs N3, REM
    0,
    0,
    -1,
    1,
    1 # R4: N3 vs WASO, REM
  ),
  ncol = 5,
  byrow = TRUE
)

v <- compositions::gsi.buildilrBase(t(sbp))
