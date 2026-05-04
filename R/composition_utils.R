make_ilrs <- function(dt) {
  dt <- as.data.table(dt)
  comp <- compositions::acomp(dt[, .SD, .SDcols = comp_vars])

  ilr_vars <- ilr(comp, V = v) |>
    as.data.table()

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

validate_comp_hull_input <- function(dt, vars = comp_vars) {
  dt <- as.data.table(dt)
  x <- as.matrix(dt[, ..vars])
  storage.mode(x) <- "double"

  complete <- stats::complete.cases(x)
  finite <- complete & apply(is.finite(x), 1L, all)
  finite_x <- x[finite, , drop = FALSE]

  data.table::data.table(
    n_rows = nrow(x),
    n_complete = sum(complete),
    n_finite = sum(finite),
    n_nonfinite = sum(!finite),
    n_unique_finite = if (nrow(finite_x)) {
      nrow(unique(as.data.table(finite_x)))
    } else {
      0L
    },
    rank_finite = if (nrow(finite_x)) qr(finite_x)$rank else 0L,
    n_vars = length(vars),
    min_total_minutes = if (nrow(finite_x)) {
      min(rowSums(finite_x))
    } else {
      NA_real_
    },
    max_total_minutes = if (nrow(finite_x)) max(rowSums(finite_x)) else NA_real_
  )
}
