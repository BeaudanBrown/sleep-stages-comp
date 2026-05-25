make_ilrs <- function(dt, comp_vars, ilr_base) {
  dt <- as.data.table(dt)
  comp <- compositions::acomp(dt[, .SD, .SDcols = comp_vars])

  ilr_vars <- ilr(comp, V = ilr_base) |>
    as.data.table()

  ilr_names <- paste0("R", seq_len(length(comp_vars) - 1))
  setnames(ilr_vars, ilr_names)

  ilr_vars
}

make_comp_limits <- function(dt) {
  lapply(comp_vars, function(var) {
    q_1_99 <- quantile(dt[[var]], probs = c(0.01, 0.99), na.rm = TRUE)
    list(
      lower = q_1_99[1],
      upper = q_1_99[2]
    )
  }) |>
    setNames(comp_vars)
}

# Component order is fixed: (N1, N2, N3, WASO, REM)
get_sbp <- function() {
  sbp <- matrix(
    c(
      -1,
      -1,
      1,
      1,
      0, # R1: (N1, N2) vs (N3, WASO)
      -1,
      0,
      0,
      1,
      1, # R2: N1 vs WASO, REM
      0,
      -1,
      1,
      0,
      1, # R3: N2 vs N3, REM
      0,
      0,
      -1,
      1,
      1 # R4: N3 vs WASO, REM
    ),
    ncol = 5,
    byrow = TRUE
  )

  compositions::gsi.buildilrBase(t(sbp))
}
