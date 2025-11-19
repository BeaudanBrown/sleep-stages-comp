prepare_dataset <- function(dt_raw) {
  # FIXME: is there a reason slp_time contains so many NA?
  # dt_raw <- tar_read(dt_raw)
  dt <- dt_raw[, `:=`(
    slp_time = n1 + n2 + n3 + rem,
    slp_time_s2 = n1_s2 + n2_s2 + n3_s2 + rem_s2,
    wake = 24 * 60 - (n1 + n2 + n3 + rem),
    wake_s2 = 24 * 60 - (n1_s2 + n2_s2 + n3_s2 + rem_s2)
  )]

  dt[,
    first_dem_or_mci := pmin(
      impairment_date_1_adjusted,
      impairment_date_2_adjusted,
      impairment_date_3_adjusted,
      fifelse(DEM_STATUS == 1, DEM_SURVDATE, NA),
      na.rm = TRUE
    )
  ]

  ilr_vars <- make_ilrs(dt)
  dt[, c("R1", "R2", "R3", "R4")] <- ilr_vars
  dt
}

impute_data <- function(dt, m, maxit) {
  predmat <- quickpred(
    df,
    mincor = 0,
    exclude = c(
      "avg_sleep",
      "avg_inactivity",
      "avg_light",
      "avg_mvpa",
      "eid",
      "id"
    )
  )
  imp <- mice(
    df,
    m = m,
    predictorMatrix = predmat,
    maxit = maxit
  )
  imp
}
