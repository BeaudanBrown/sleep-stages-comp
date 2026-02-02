prepare_dataset <- function(dt_raw) {
  ## Adjust cog dates to be relative to recruitment
  mci_cols <- grep("^impairment_date_", names(dt_raw), value = TRUE)
  cog_cols <- grep("^COG_DATE_", names(dt_raw), value = TRUE)
  mri_cols <- grep("^mri_date_", names(dt_raw), value = TRUE)

  # Merge death status
  dt_raw <- dt_raw[,
    death_status := fifelse(
      fram_death_status == 1 | shhs_alive_status == 0,
      1,
      0
    )
  ]

  # Ensure all dates are relative to PSG2
  fram_cols <- c(
    mci_cols,
    mri_cols,
    cog_cols,
    "fram_death_date",
    "DEM_SURVDATE"
  )
  shhs_cols <- c("shhs_death_date", "shhs_cens_date")

  dt_raw <- dt_raw[,
    days_to_psg2 := days_to_psg1 + days_psg1_to_psg2
  ]

  dt_raw <- dt_raw[,
    (shhs_cols) := lapply(.SD, \(x) x - dt_raw$days_psg1_to_psg2),
    .SDcols = shhs_cols
  ]

  dt_raw <- dt_raw[,
    (fram_cols) := lapply(.SD, \(x) x - days_to_psg2),
    .SDcols = fram_cols
  ]

  dt_raw <- dt_raw[,
    death_date := fifelse(
      fram_death_status == 1 | shhs_alive_status == 0,
      pmax(fram_death_date, shhs_cens_date),
      NA
    )
  ]

  dt <- dt_raw[, `:=`(
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
  dt[, (ilr_names) := ilr_vars]
  dt
}

impute_data <- function(dt, m, maxit) {
  imp_dt <- dt[, .(
    PID,
    n1,
    n2,
    n3,
    rem,
    n1_s2,
    n2_s2,
    n3_s2,
    rem_s2,
    slp_time,
    slp_time_s2,
    age_s1,
    bmi_s1
  )]

  setnames(
    imp_dt,
    c("n1", "n2", "n3", "rem"),
    c("n1_raw", "n2_raw", "n3_raw", "rem_raw")
  )

  # Set dubious values to NA
  imp_dt[, `:=`(
    n1 = fifelse(is.na(slp_time), NA, n1_raw),
    n2 = fifelse(is.na(slp_time), NA, n2_raw),
    n3 = fifelse(is.na(slp_time), NA, n3_raw),
    rem = fifelse(is.na(slp_time), NA, rem_raw)
  )]

  imp_dt$slp_time_raw <- imp_dt$n1_raw +
    imp_dt$n2_raw +
    imp_dt$n3_raw +
    imp_dt$rem_raw

  # Correlation tests
  # m <- lm(n1 ~ I(n1_raw / slp_time_raw), imp_dt)
  # m2 <- lm(n2 ~ I(n2_raw / slp_time_raw), imp_dt)
  # m3 <- lm(n3 ~ I(n3_raw / slp_time_raw), imp_dt)
  # mrem <- lm(rem ~ I(rem_raw / slp_time_raw), imp_dt)
  # summary(m)
  # summary(m2)
  # summary(m3)
  # summary(m1)

  init <- mice(
    imp_dt,
    maxit = 0
  )

  meth <- init$meth
  meth[c("slp_time")] <- ""
  meth[c("n1", "n2", "n3", "rem")] <- "truncated_norm"

  pred <- init$pred
  pred[, c("PID", "n1_raw", "n2_raw", "n3_raw", "rem_raw")] <- 0
  pred[c("PID", "n1_raw", "n2_raw", "n3_raw", "rem_raw", "slp_time"), ] <- 0

  imp <- mice(
    imp_dt,
    meth = meth,
    pred = pred,
    blots = list(
      slp_time = list(lower = imp_dt$slp_time_raw),
      n1 = list(lower = imp_dt$n1_raw),
      n2 = list(lower = imp_dt$n2_raw),
      n3 = list(lower = imp_dt$n3_raw),
      rem = list(lower = imp_dt$rem_raw)
    )
  )

  imp <- as.data.table(complete(imp))
  imp
}
