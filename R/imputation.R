mice.impute.truncated_norm <- function(y, ry, x, wy = NULL, lower = -Inf, ...) {
  if (is.null(wy)) {
    wy <- !ry
  }

  lower <- lower[wy]

  x <- cbind(1, as.matrix(x))
  parm <- mice:::.norm.draw(y, ry, x, ...)
  mean_prediction <- x[wy, ] %*% parm$beta

  truncnorm::rtruncnorm(
    n = sum(wy),
    a = lower,
    mean = mean_prediction,
    sd = parm$sigma
  )
}

impute_data <- function(dt, m = 1, maxit = 5) {
  base_covars <- c("age_s1", "bmi_s1", "gender", "educat", "IDTYPE")
  base_covars <- intersect(base_covars, names(dt))

  sleep_vars <- c(
    "n1",
    "n2",
    "n3",
    "rem",
    "waso",
    "slp_time",
    "n1_s2",
    "n2_s2",
    "n3_s2",
    "rem_s2",
    "waso_s2",
    "slp_time_s2"
  )

  outcome_vars <- c(
    "dem_or_mci_status",
    "dem_or_mci_surv_date",
    "death_status",
    "death_date"
  )

  imp_cols <- c("PID", base_covars, sleep_vars, outcome_vars)
  imp_dt <- dt[, ..imp_cols]
  imp_dt[, log_dem_time := log(dem_or_mci_surv_date)]

  setnames(
    imp_dt,
    c("n1", "n2", "n3", "rem"),
    c("n1_raw", "n2_raw", "n3_raw", "rem_raw")
  )

  imp_dt[, `:=`(
    n1 = fifelse(is.na(slp_time), NA_real_, n1_raw),
    n2 = fifelse(is.na(slp_time), NA_real_, n2_raw),
    n3 = fifelse(is.na(slp_time), NA_real_, n3_raw),
    rem = fifelse(is.na(slp_time), NA_real_, rem_raw)
  )]

  imp_dt[, slp_time_raw := n1_raw + n2_raw + n3_raw + rem_raw]

  init <- mice::mice(imp_dt, maxit = 0, printFlag = FALSE)

  meth <- init$meth
  meth[c("slp_time")] <- "pmm"
  meth[c("educat")] <- "pmm"
  meth[c("n1", "n2", "n3", "rem")] <- "truncated_norm"

  meth[c(
    "dem_or_mci_status",
    "dem_or_mci_surv_date",
    "death_status",
    "death_date",
    "log_dem_time",
    "PID",
    "n1_raw",
    "n2_raw",
    "n3_raw",
    "rem_raw",
    "slp_time_raw"
  )] <- ""

  pred <- init$pred

  pred[, c(
    "PID",
    "n1_raw",
    "n2_raw",
    "n3_raw",
    "rem_raw",
    "slp_time_raw",
    "death_date"
  )] <- 0

  pred[
    c(
      "PID",
      "n1_raw",
      "n2_raw",
      "n3_raw",
      "rem_raw",
      "slp_time_raw",
      "dem_or_mci_status",
      "dem_or_mci_surv_date",
      "death_status",
      "death_date",
      "log_dem_time"
    ),
  ] <- 0

  imp <- mice::mice(
    imp_dt,
    m = m,
    maxit = maxit,
    meth = meth,
    pred = pred,
    blots = list(
      n1 = list(lower = imp_dt$n1_raw),
      n2 = list(lower = imp_dt$n2_raw),
      n3 = list(lower = imp_dt$n3_raw),
      rem = list(lower = imp_dt$rem_raw)
    ),
    printFlag = FALSE
  )

  comp_dt <- data.table::as.data.table(mice::complete(imp, action = 1))

  drop_cols <- c(
    "n1_raw",
    "n2_raw",
    "n3_raw",
    "rem_raw",
    "slp_time_raw",
    "log_dem_time"
  )
  comp_dt[, (drop_cols) := NULL]

  out_dt <- data.table::copy(dt)
  update_cols <- setdiff(names(comp_dt), "PID")

  out_dt[comp_dt, (update_cols) := mget(paste0("i.", update_cols)), on = "PID"]

  ilr_vars <- make_ilrs(out_dt)
  out_dt[, (ilr_names) := ilr_vars]

  out_dt
}
