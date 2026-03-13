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

  dt <- data.table::data.table(
    PID = seq_len(n),
    n1_s2 = runif(n, 40, 100),
    n2_s2 = runif(n, 120, 220),
    n3_s2 = runif(n, 40, 120),
    waso_s2 = runif(n, 10, 60),
    rem_s2 = runif(n, 50, 120)
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
    comp_limits = make_comp_limits(wide)
  )
}
