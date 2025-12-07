comp_vars <- c(
  "wake",
  "n1",
  "n2",
  "n3",
  "rem"
)

# FIXME: Choose the SBP more carefully?
sbp <- matrix(
  c(
    1,
    1,
    -1,
    -1,
    -1,
    -1,
    -1,
    1,
    0,
    0,
    1,
    0,
    -1,
    1,
    1,
    0,
    1,
    -1,
    1,
    -1
  ),
  ncol = 5,
  byrow = TRUE
)

v <- compositions::gsi.buildilrBase(t(sbp))
