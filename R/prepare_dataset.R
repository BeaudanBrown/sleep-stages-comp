prepare_dataset <- function(dt_raw) {
  ## Adjust cog dates to be relative to recruitment
  mci_cols <- grep("^impairment_date_", names(dt_raw), value = TRUE)
  cog_cols <- grep("^COG_DATE_", names(dt_raw), value = TRUE)

  # Merge death status
  dt_raw <- dt_raw[,
    death_status := fifelse(
      fram_death_status == 1 | shhs_alive_status == 0,
      1,
      0
    )
  ]

  # Ensure all dates are relative to PSG2
  fram_cols <- c(mci_cols, cog_cols, "fram_death_date", "DEM_SURVDATE")
  shhs_cols <- c("shhs_death_date", "shhs_cens_date")

  dt_raw <- dt_raw[,
    days_to_psg2 := days_to_psg1 + days_psg1_to_psg2
  ]

  dt_raw <- dt_raw[,
    (shhs_cols) := lapply(.SD, function(x) x - dt_raw$days_psg1_to_psg2),
    .SDcols = shhs_cols
  ]

  dt_raw <- dt_raw[,
    (fram_cols) := lapply(.SD, function(x) x - days_to_psg2),
    .SDcols = fram_cols
  ]

  dt_raw <- dt_raw[,
    death_date := fifelse(
      fram_death_status == 1 | shhs_alive_status == 0,
      pmax(fram_death_date, shhs_cens_date),
      NA
    )
  ]

  # FIXME: is there a reason slp_time contains so many NA?
  dt <- dt_raw[, `:=`(
    slp_time = n1 + n2 + n3 + rem,
    slp_time_s2 = n1_s2 + n2_s2 + n3_s2 + rem_s2,
    wake = 24 * 60 - (n1 + n2 + n3 + rem),
    wake_s2 = 24 * 60 - (n1_s2 + n2_s2 + n3_s2 + rem_s2)
  )]

  dt[,
    dem_or_mci_status := fifelse(
      DEM_STATUS == 1 |
        !is.na(impairment_date_1) |
        !is.na(impairment_date_2) |
        !is.na(impairment_date_3),
      1,
      0
    )
  ]

  dt[,
    dem_or_mci_surv_date := pmin(
      impairment_date_1,
      impairment_date_2,
      impairment_date_3,
      DEM_SURVDATE,
      na.rm = TRUE
    )
  ]

  impairment_cols <- grep("impairment_date_.*", names(dt), value = TRUE)
  cog_cols <- grep("COG_DATE_.*", names(dt), value = TRUE)
  all_cols <- c(impairment_cols, cog_cols)

  dt[
    is.na(dem_or_mci_surv_date),
    dem_or_mci_surv_date := do.call(pmax, c(.SD, na.rm = TRUE)),
    .SDcols = all_cols
  ]

  dt <- dt[!is.na(dem_or_mci_surv_date), ]

  # Exclude ppts with dem/mci before PSG 2
  dt <- dt[is.na(dem_or_mci_surv_date) | dem_or_mci_surv_date > 0, ]

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
