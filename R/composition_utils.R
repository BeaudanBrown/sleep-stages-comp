make_ilrs <- function(dt, comp_vars, ilr_base) {
  dt <- as.data.table(dt)
  comp <- compositions::acomp(dt[, .SD, .SDcols = comp_vars])

  ilr_vars <- ilr(comp, V = ilr_base) |>
    as.data.table()

  ilr_names <- paste0("R", seq_len(length(comp_vars) - 1))
  setnames(ilr_vars, ilr_names)

  ilr_vars
}

# Component order is fixed: (N1, N2, N3, REM)
get_sbp <- function() {
  sbp <- matrix(
    c(
      -1,
      -1,
      1,
      1, # R1: (N1, N2) vs (N3, REM)
      1,
      -1,
      0,
      0, # R2: N1 vs N2
      0,
      0,
      1,
      -1 # R3: N3 vs REM
    ),
    ncol = 4,
    byrow = TRUE
  )

  compositions::gsi.buildilrBase(t(sbp))
}
