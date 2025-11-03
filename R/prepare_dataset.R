prepare_dataset <- function(dt_raw) {
  # FIXME: is there a reason slp_time contains so many NA?
  # dt_raw <- tar_read(dt_raw)
  dt <- dt_raw[, `:=`(
    slp_time = n1 + n2 + n3 + rem,
    wake = 24 * 60 - (n1 + n2 + n3 + rem)
  )]

  ilr_vars <- make_ilrs(dt)

  dt[, c("R1", "R2", "R3", "R4")] <- ilr_vars

  dt
}
