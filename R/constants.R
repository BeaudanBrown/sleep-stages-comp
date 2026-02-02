comp_vars <- c(
  "n1_s2",
  "n2_s2",
  "n3_s2",
  "waso_s2",
  "rem_s2"
)

ilr_names <- paste0("R", seq_len(length(comp_vars) - 1))

# Component order is fixed: (N1, N2, N3, WASO, REM)
sbp <- matrix(
  c(
    -1,
    -1,
    1,
    1,
    0, # R1: (N1, N2) vs (N3, REM)
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

# # Component order is fixed: (N1, N2, N3, REM)
# sbp <- matrix(
#   c(
#     -1,
#     -1,
#     1,
#     1,
#     0,
#     0,
#     1,
#     -1,
#     1,
#     -1,
#     0,
#     0
#   ),
#   ncol = 4,
#   byrow = TRUE
# )

v <- compositions::gsi.buildilrBase(t(sbp))
