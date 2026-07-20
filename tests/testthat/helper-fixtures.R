make_test_comp_dt <- function() {
  data.table::data.table(
    PID = 1:4,
    n1_s2 = c(60, 70, 80, 90),
    n2_s2 = c(140, 150, 160, 170),
    n3_s2 = c(90, 80, 70, 60),
    waso_s2 = c(20, 25, 30, 35),
    rem_s2 = c(90, 85, 80, 75)
  )
}

make_test_comp_limits <- function() {
  list(
    n1_s2 = list(lower = 50, upper = 100),
    n2_s2 = list(lower = 120, upper = 180),
    n3_s2 = list(lower = 50, upper = 110),
    waso_s2 = list(lower = 10, upper = 40),
    rem_s2 = list(lower = 60, upper = 100)
  )
}

make_test_comp_hull <- function() {
  make_test_substitution_masks(
    make_test_comp_dt(),
    data.table::data.table(
      from = c("n2_s2", "n2_s2"),
      to = c("n3_s2", "n3_s2"),
      duration = c(15L, -10L)
    )
  )
}

make_test_substitution_masks <- function(
  dt,
  substitutions,
  substituted = TRUE,
  applied_duration = NULL
) {
  dt <- data.table::as.data.table(dt)
  substitutions <- data.table::as.data.table(substitutions)

  data.table::rbindlist(lapply(seq_len(nrow(substitutions)), function(i) {
    row <- substitutions[i]
    mask <- if (length(substituted) == 1L) {
      rep(as.logical(substituted), nrow(dt))
    } else {
      as.logical(substituted)
    }
    realized <- if (is.null(applied_duration)) {
      mask * row$duration
    } else if (length(applied_duration) == 1L) {
      rep(as.numeric(applied_duration), nrow(dt))
    } else {
      as.numeric(applied_duration)
    }

    data.table::data.table(
      from = row$from,
      to = row$to,
      duration = as.integer(row$duration),
      row_id = seq_len(nrow(dt)),
      PID = as.character(dt$PID),
      substituted = mask,
      applied_duration = realized
    )
  }))
}

comp_total <- function(dt) {
  rowSums(as.matrix(dt[, ..comp_vars]))
}

make_test_survival_dt <- function() {
  data.table::data.table(
    PID = 1:3,
    dem_or_mci_status = c(1, 0, 0),
    dem_or_mci_surv_date = c(400, 300, 500),
    death_status = c(0, 1, 0),
    death_date = c(NA_real_, 300, NA_real_),
    n1_s2 = c(60, 60, 60),
    n2_s2 = c(140, 140, 140),
    n3_s2 = c(90, 90, 90),
    waso_s2 = c(20, 20, 20),
    rem_s2 = c(90, 90, 90)
  )
}

make_test_timegroup_cuts <- function() {
  c(0, 200, 400, 600)
}

make_test_model_dt <- function(n = 120L) {
  set.seed(20260313)

  n1_s2 <- runif(n, 40, 100)
  n2_s2 <- runif(n, 120, 220)
  n3_s2 <- runif(n, 40, 120)
  waso_s2 <- runif(n, 10, 60)
  rem_s2 <- runif(n, 50, 120)

  dt <- data.table::data.table(
    PID = seq_len(n),
    age_s1 = runif(n, 45, 85),
    bmi_s1 = runif(n, 20, 38),
    gender = sample(c(0L, 1L), n, replace = TRUE),
    educat = sample(8:20, n, replace = TRUE),
    IDTYPE = sample(c(1L, 2L, 7L), n, replace = TRUE),
    n1_s2 = n1_s2,
    n2_s2 = n2_s2,
    n3_s2 = n3_s2,
    waso_s2 = waso_s2,
    rem_s2 = rem_s2,
    n1 = runif(n, 30, 90),
    n2 = runif(n, 100, 210),
    n3 = runif(n, 30, 120),
    rem = runif(n, 45, 120),
    s1_incomplete = sample(c(0L, 1L), n, replace = TRUE),
    slp_time_s2 = n1_s2 + n2_s2 + n3_s2 + rem_s2,
    waist_circumference = runif(n, 70, 130),
    hypertension = sample(c(0L, 1L), n, replace = TRUE),
    diabetes = sample(c(0L, 1L), n, replace = TRUE),
    cvd_status = sample(c(0L, 1L), n, replace = TRUE),
    smoking_status = sample(c(0L, 1L, 2L), n, replace = TRUE),
    alcohol_use = sample(c(0L, 1L), n, replace = TRUE),
    physical_activity = runif(n, 0, 10),
    apoe_e4 = sample(c(0L, 1L), n, replace = TRUE),
    sedative_use = sample(c(0L, 1L), n, replace = TRUE),
    sleeping_pill_use = sample(c(0L, 1L), n, replace = TRUE),
    antidepressant_use = sample(c(0L, 1L), n, replace = TRUE)
  )

  ilrs <- make_ilrs(dt)
  dt[, (ilr_names) := ilrs]

  follow_up <- sample(c(365, 730, 1460, 2190, 2555, 2920), n, replace = TRUE)
  death_status <- rbinom(n, 1, 0.20)
  death_date <- ifelse(death_status == 1, follow_up, NA_real_)

  dem_status <- rbinom(n, 1, 0.18)
  dem_status[death_status == 1] <- 0L
  dem_date <- ifelse(dem_status == 1, follow_up, NA_real_)

  dem_or_mci_surv_date <- fifelse(
    dem_status == 1,
    dem_date,
    fifelse(death_status == 1, death_date, follow_up)
  )

  dt[, `:=`(
    dem_or_mci_status = as.integer(dem_status),
    dem_or_mci_surv_date = as.numeric(dem_or_mci_surv_date),
    death_status = as.integer(death_status),
    death_date = as.numeric(death_date)
  )]

  dt
}

make_test_lmtp_inputs <- function(n = 120L) {
  dt <- make_test_model_dt(n)
  cuts <- make_cuts(dt)
  surv_dt <- expand_surv_dt(dt, cuts)
  wide <- suppressWarnings(make_surv_wide(surv_dt))
  cols <- get_lmtp_surv_cols(wide)

  list(
    dt = dt,
    cuts = cuts,
    surv_dt = surv_dt,
    wide = wide,
    cols = cols,
    comp_hull = make_test_substitution_masks(
      wide,
      data.table::data.table(
        from = "n2_s2",
        to = "n3_s2",
        duration = 15L
      )
    )
  )
}

make_test_raw_dataset <- function() {
  data.table::data.table(
    PID = 1:2,
    IDTYPE = c(1L, 7L),
    fram_death_status = c(0L, 0L),
    shhs_alive_status = c(1L, 1L),
    days_to_psg1 = c(100, 100),
    days_psg1_to_psg2 = c(200, 200),
    shhs_death_date = c(NA_real_, NA_real_),
    shhs_cens_date = c(1200, 1200),
    fram_death_date = c(NA_real_, NA_real_),
    DEM_SURVDATE = c(900, 950),
    DEM_STATUS = c(0L, 0L),
    impairment_date_1 = c(NA_real_, NA_real_),
    impairment_date_2 = c(NA_real_, NA_real_),
    impairment_date_3 = c(NA_real_, NA_real_),
    age_s1 = c(64, 71),
    bmi_s1 = c(24.5, 28.2),
    gender = c(0L, 1L),
    educat = c(12L, 16L),
    n1 = c(50, 60),
    n2 = c(180, 170),
    n3 = c(90, 80),
    rem = c(80, 75),
    slp_time = c(400, NA_real_),
    n1_s2 = c(55, 65),
    n2_s2 = c(175, 165),
    n3_s2 = c(95, 85),
    waso_s2 = c(25, 30),
    rem_s2 = c(85, 80),
    slp_time_s2 = c(410, 395),
    waist_circumference = c(88, 102),
    hypertension = c(0L, 1L),
    diabetes = c(0L, 0L),
    cvd_status = c(0L, 1L),
    smoking_status = c(0L, 2L),
    alcohol_use = c(1L, 0L),
    physical_activity = c(4.5, 2.0),
    apoe_e4 = c(0L, 1L),
    sedative_use = c(0L, 0L),
    sleeping_pill_use = c(0L, 1L),
    antidepressant_use = c(0L, 1L)
  )
}
