prepare_dataset <- function(dt_raw, v) {
  # FIXME: is there a reason slp_time contains so many NA?
  # dt_raw <- tar_read(dt_raw)
  dt <- dt_raw[, `:=`(
    slp_time = timest1 + timest2 + timest34 + timerem,
    wake = 24 * 60 - (timest1 + timest2 + timest34 + timerem)
  )]

  comp <- compositions::acomp(dt[,
    .(
      wake,
      timest1,
      timest2,
      timest34,
      timerem
    )
  ])

  ilr_vars <- ilr(comp, V = v) |>
    as.data.table()

  dt[, c("R1", "R2", "R3", "R4")] <- ilr_vars

  dt
}
