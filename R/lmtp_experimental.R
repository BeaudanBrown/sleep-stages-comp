run_lmtp_tmle_substitution_sim <- function(
  dt,
  outcome_cols,
  cens_cols,
  compete_cols,
  trt_cols,
  baseline_covars,
  comp_limits,
  substitution,
  learners_outcome,
  learners_trt,
  folds
) {
  data <- read.csv("sim.csv")
  setDT(data)

  n <- nrow(data)
  data[, `:=`(
    A_1 = NULL,
    A_2 = NULL,
    L1_1 = NULL,
    L1_2 = NULL,
    L2_1 = NULL,
    L2_2 = NULL,
    A1 = rnorm(n, mean = 0, sd = 1),
    A2 = rnorm(n, mean = 0, sd = 1)
  )]
  time_points <- 1:2

  for (t in time_points) {
    c_col <- paste0("C_", t)
    c2_col <- paste0("C_", t + 1)
    d_col <- paste0("D_", t)
    y_col <- paste0("Y_", t)

    cols_to_zero <- c(d_col, y_col, c2_col)
    cols_to_zero <- cols_to_zero[cols_to_zero %in% names(data)]

    if (length(cols_to_zero) > 0) {
      data[get(c_col) == 0, (cols_to_zero) := 0]
    }
    if (c2_col %in% names(data)) {
      data[get(d_col) == 1, (c2_col) := 0]
    }
  }
  data <- as.data.frame(data)

  trt_cols <- list(c("A1", "A2"))
  outcome_cols <- c("Y_1", "Y_2")
  baseline_arg <- c("W1", "W2")
  cens_cols <- c("C_1", "C_2")
  compete_cols <- c("D_1", "D_2")
  learners_trt <- c("glm")
  learners_outcome <- learners_trt
  shift_fn <- function(data, trt) {
    as.data.frame(data[, trt], check.names = FALSE)
  }
  folds <- 5
  fit <- lmtp::lmtp_tmle(
    data = data,
    trt = trt_cols,
    outcome = outcome_cols,
    baseline = baseline_arg,
    time_vary = NULL,
    cens = cens_cols,
    compete = compete_cols,
    shift = shift_fn,
    mtp = TRUE,
    outcome_type = "survival",
    learners_outcome = learners_outcome,
    learners_trt = learners_trt,
    folds = folds
  )

  shift_fn <- make_lmtp_shift(
    substitution$from,
    substitution$to,
    substitution$duration,
    comp_limits
  )

  fit <- lmtp::lmtp_tmle(
    data = data,
    trt = trt_cols,
    outcome = outcome_cols,
    baseline = baseline_covars_or_null(baseline_covars),
    time_vary = NULL,
    cens = cens_cols,
    compete = compete_cols,
    shift = shift_fn,
    mtp = TRUE,
    outcome_type = "survival",
    learners_outcome = learners_outcome,
    learners_trt = learners_trt,
    folds = folds
  )

  estimate_dt <- data.table::as.data.table(generics::tidy(fit))
  cbind(
    data.table::data.table(
      from = substitution$from,
      to = substitution$to,
      duration = substitution$duration
    ),
    estimate_dt
  )
}
