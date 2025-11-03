make_ilrs <- function(dt) {
  comp <- compositions::acomp(dt[,
    ..comp_vars
  ])

  ilr_vars <- ilr(comp, V = v) |>
    as.data.table()
}

make_comp_limits <- function(dt) {
  quants <- lapply(comp_vars, function(var) {
    q_1_99 <- quantile(dt[[var]], probs = c(0.01, 0.99), na.rm = TRUE)
    list(
      lower = q_1_99[1],
      upper = q_1_99[2]
    )
  }) |>
    setNames(comp_vars)
}
