prepare_dataset <- function(dt_raw, comp_vars, ilr_base) {
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
    "fram_cvd_date",
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

  dt <- data.table::copy(dt_raw)

  dt[, s1_incomplete := as.integer(is.na(slp_time))]
  dt[is.na(slp_time), slp_time := n1 + n2 + n3 + rem]

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
    dem_or_mci_date := pmin(
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
    is.na(dem_or_mci_date),
    dem_or_mci_date := do.call(pmax, c(.SD, na.rm = TRUE)),
    .SDcols = all_cols
  ]

  dt <- dt[!is.na(dem_or_mci_date), ]

  # Exclude ppts with dem/mci before PSG 2
  dt <- dt[is.na(dem_or_mci_date) | dem_or_mci_date > 0, ]

  # Exclude participants with <4 hours sleep at PSG2
  dt <- dt[n1_s2 + n2_s2 + n3_s2 + rem_s2 >= 4]

  ## Add ILR vars to data

  # s1
  ilr_vars_s1 <- make_ilrs(dt, comp_vars, ilr_base)
  ilr_names_s1 <- paste0("R", seq_len(length(comp_vars) - 1), "_s1")
  dt[, (ilr_names_s1) := ilr_vars_s1]

  # s2
  ilr_vars_s2 <- make_ilrs(dt, paste0(comp_vars, "_s2"), ilr_base)
  ilr_names_s2 <- paste0("R", seq_len(length(comp_vars) - 1), "_s2")
  dt[, (ilr_names_s2) := ilr_vars_s2]

  mri_value_prefixes <- c(
    "DSE_wmh",
    "Cerebrum_tcv",
    "Cerebrum_tcb",
    "Hippo"
  )

  mri_selected <- gather_domain_visits(
    dt,
    mri_value_prefixes,
    "mri_date",
    "mri"
  )
  dt <- merge(dt, mri_selected, by = "PID", all.x = TRUE)

  mri_value_cols <- grep(
    paste0("^(", paste(mri_value_prefixes, collapse = "|"), ")_[0-9]+$"),
    names(dt),
    value = TRUE
  )
  mri_date_cols <- grep("^mri_date_[0-9]+$", names(dt), value = TRUE)
  dt[, c(mri_value_cols, mri_date_cols) := NULL]

  cog_value_prefixes <- c(
    "TRAILSB",
    "LMI",
    "LMD",
    "VRI",
    "VRD",
    "SIM"
  )

  cog_selected <- gather_domain_visits(
    dt,
    cog_value_prefixes,
    "COG_DATE",
    "cog"
  )
  dt <- merge(dt, cog_selected, by = "PID", all.x = TRUE)

  cog_value_cols <- grep(
    paste0("^(", paste(cog_value_prefixes, collapse = "|"), ")_[0-9]+$"),
    names(dt),
    value = TRUE
  )
  cog_date_cols <- grep("^COG_DATE_[0-9]+$", names(dt), value = TRUE)
  dt[, c(cog_value_cols, cog_date_cols) := NULL]

  dt[,
    cvd_pre_cog := fcase(
      fram_cvd == 1 & (fram_cvd_date - cog_s2_date) < 0,
      1,
      fram_cvd == 0 & (fram_cvd_date - cog_s2_date) < 0,
      NA,
      default = 0
    )
  ]

  dt[,
    cvd_pre_mri := fcase(
      fram_cvd == 1 & (fram_cvd_date - mri_s2_date) < 0,
      1,
      fram_cvd == 0 & (fram_cvd_date - mri_s2_date) < 0,
      NA,
      default = 0
    )
  ]

  # Exclude observations that die within follow-up window and did not do cog or mri

  dt[
    !(death_status == 1 &
      (is.na(cog_s2_date) | is.na(mri_s2_date)) &
      death_date < 365 * 7)
  ]
}

# Select one visit per participant/window from domain dates, then extract all
# domain measures from that selected visit.
gather_domain_visits <- function(
  dt,
  value_prefixes,
  date_prefix,
  domain_prefix
) {
  window_start <- 3
  window_end <- 7
  window_centre <- mean(c(window_start, window_end))

  date_cols <- grep(
    paste0("^", date_prefix, "_[0-9]+$"),
    names(dt),
    value = TRUE
  )
  visits <- as.integer(sub(paste0("^", date_prefix, "_"), "", date_cols))

  date_dt <- melt(
    dt,
    id.vars = c("PID", "days_psg1_to_psg2"),
    measure.vars = date_cols,
    variable.name = "visit",
    value.name = "date"
  )
  date_dt[, visit := visits[visit]]
  date_dt <- date_dt[!is.na(date)]

  date_dt[, shhs1_date := -days_psg1_to_psg2]
  date_dt[, pre_distance := abs(date - shhs1_date)]

  pre_visits <- date_dt[date < 0]
  setorder(pre_visits, PID, pre_distance, date)
  pre_visits <- pre_visits[, .SD[1], by = PID]
  pre_visits <- pre_visits[, .(PID, s1_visit = visit, s1_date = date)]

  post_visits <- date_dt[date >= window_start * 365 & date <= window_end * 365]
  post_visits[, post_distance := abs(date - window_centre * 365)]
  setorder(post_visits, PID, post_distance, date)
  post_visits <- post_visits[, .SD[1], by = PID]
  post_visits <- post_visits[, .(PID, s2_visit = visit, s2_date = date)]

  out <- unique(dt[, .(PID)])
  out <- merge(out, pre_visits, by = "PID", all.x = TRUE)
  out <- merge(out, post_visits, by = "PID", all.x = TRUE)
  setnames(
    out,
    c("s1_date", "s2_date"),
    c(paste0(domain_prefix, "_s1_date"), paste0(domain_prefix, "_s2_date"))
  )

  row_idx <- match(out$PID, dt$PID)

  for (prefix in value_prefixes) {
    value_pattern <- paste0("^", prefix, "_[0-9]+$")
    value_cols <- grep(value_pattern, names(dt), value = TRUE)
    value_visits <- as.integer(sub(paste0("^", prefix, "_"), "", value_cols))

    values <- as.matrix(dt[, ..value_cols])
    s1_col_idx <- match(out$s1_visit, value_visits)
    s2_col_idx <- match(out$s2_visit, value_visits)

    out[, (paste0(prefix, "_s1")) := values[cbind(row_idx, s1_col_idx)]]
    out[, (paste0(prefix, "_s2")) := values[cbind(row_idx, s2_col_idx)]]
  }

  out[, c("s1_visit", "s2_visit") := NULL]
}
