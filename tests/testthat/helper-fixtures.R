comp_vars <- c("n1_s2", "n2_s2", "n3_s2", "rem_s2")
ilr_names <- paste0("R", 1:3, "_s2")

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

make_test_raw_dataset <- function() {
  dt <- data.table::data.table(
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
    edu_years = c(12L, 16L),
    waso = c(20, 25),
    fram_cvd = c(0L, 0L),
    fram_cvd_date = c(3000, 3000),
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
  for (visit in 1:2) {
    dt[, (paste0("mri_date_", visit)) := c(100, 2125)[visit]]
    dt[, (paste0("COG_DATE_", visit)) := c(100, 2125)[visit]]
    for (measure in c(
      "DSE_wmh",
      "Cerebrum_tcv",
      "Cerebrum_tcb",
      "Hippo",
      "TRAILSB",
      "LMI",
      "LMD",
      "VRI",
      "VRD",
      "SIM"
    )) {
      dt[, (paste0(measure, "_", visit)) := c(10, 12)]
    }
  }
  dt
}
