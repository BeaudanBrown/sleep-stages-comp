comp_vars <- c(
  "n1_s2",
  "n2_s2",
  "n3_s2",
  "rem_s2"
)

ilr_names <- paste0("R", seq_len(length(comp_vars) - 1))

# Component order is fixed: (N1, N2, N3, REM)
sbp <- matrix(
  c(
    -1,
    -1,
    1,
    1,
    0,
    0,
    1,
    -1,
    1,
    -1,
    0,
    0
  ),
  ncol = 4,
  byrow = TRUE
)

v <- compositions::gsi.buildilrBase(t(sbp))
