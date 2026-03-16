comparison_direction <- function(risk_ratio, tolerance = 1e-8) {
  out <- rep(NA_integer_, length(risk_ratio))
  finite_idx <- is.finite(risk_ratio)

  out[finite_idx & risk_ratio > 1 + tolerance] <- 1L
  out[finite_idx & risk_ratio < 1 - tolerance] <- -1L
  out[finite_idx & abs(risk_ratio - 1) <= tolerance] <- 0L

  out
}

normalize_method_comparison_summary <- function(summary_dt) {
  dt <- data.table::as.data.table(summary_dt)
  required_cols <- c(
    "from",
    "to",
    "duration",
    "ratio_substituted",
    "mean_risk_ratio"
  )
  missing_cols <- setdiff(required_cols, names(dt))

  if (length(missing_cols) > 0L) {
    stop(
      sprintf(
        "summary_dt is missing required comparison columns: %s",
        paste(missing_cols, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  if (!"lower_ci" %in% names(dt)) {
    dt[, lower_ci := NA_real_]
  }
  if (!"upper_ci" %in% names(dt)) {
    dt[, upper_ci := NA_real_]
  }

  dt <- data.table::copy(dt)[,
    .(
      from,
      to,
      duration,
      ratio_substituted,
      mean_risk_ratio,
      lower_ci,
      upper_ci
    )
  ]
  data.table::setorderv(dt, c("from", "to", "duration"))
  dt
}

join_method_substitution_summaries <- function(
  pooled_summary,
  lmtp_summary,
  ratio_threshold = comparison_ratio_threshold()
) {
  pooled_dt <- normalize_method_comparison_summary(pooled_summary)
  lmtp_dt <- normalize_method_comparison_summary(lmtp_summary)

  pooled_dt <- data.table::copy(pooled_dt)
  lmtp_dt <- data.table::copy(lmtp_dt)

  data.table::setnames(
    pooled_dt,
    old = setdiff(names(pooled_dt), c("from", "to", "duration")),
    new = paste0(
      "pooled_",
      setdiff(names(pooled_dt), c("from", "to", "duration"))
    )
  )
  data.table::setnames(
    lmtp_dt,
    old = setdiff(names(lmtp_dt), c("from", "to", "duration")),
    new = paste0("lmtp_", setdiff(names(lmtp_dt), c("from", "to", "duration")))
  )

  joined <- merge(
    pooled_dt,
    lmtp_dt,
    by = c("from", "to", "duration"),
    all = TRUE,
    sort = FALSE
  )

  joined[, pooled_direction := comparison_direction(pooled_mean_risk_ratio)]
  joined[, lmtp_direction := comparison_direction(lmtp_mean_risk_ratio)]
  joined[, same_direction := pooled_direction == lmtp_direction]
  joined[is.na(pooled_direction) | is.na(lmtp_direction), same_direction := NA]
  joined[, direction_reversed := pooled_direction == -lmtp_direction]
  joined[
    pooled_direction %in%
      c(NA_integer_, 0L) |
      lmtp_direction %in% c(NA_integer_, 0L),
    direction_reversed := FALSE
  ]
  joined[,
    abs_risk_ratio_gap := abs(pooled_mean_risk_ratio - lmtp_mean_risk_ratio)
  ]
  joined[,
    abs_log_risk_ratio_gap := abs(
      log(pooled_mean_risk_ratio) - log(lmtp_mean_risk_ratio)
    )
  ]
  joined[, pooled_plot_eligible := pooled_ratio_substituted >= ratio_threshold]
  joined[, lmtp_plot_eligible := lmtp_ratio_substituted >= ratio_threshold]
  joined[,
    shared_plot_eligible := pooled_plot_eligible %in%
      TRUE &
      lmtp_plot_eligible %in% TRUE
  ]
  joined[,
    pooled_only_plot_eligible := pooled_plot_eligible %in%
      TRUE &
      !(lmtp_plot_eligible %in% TRUE)
  ]
  joined[,
    lmtp_only_plot_eligible := lmtp_plot_eligible %in%
      TRUE &
      !(pooled_plot_eligible %in% TRUE)
  ]

  data.table::setorderv(
    joined,
    c("direction_reversed", "shared_plot_eligible", "abs_log_risk_ratio_gap"),
    order = c(-1L, -1L, -1L)
  )

  joined[]
}

summarize_method_comparison <- function(comparison_dt) {
  dt <- data.table::as.data.table(comparison_dt)

  data.table::data.table(
    n_rows = nrow(dt),
    n_shared_plot_eligible = sum(
      dt$shared_plot_eligible %in% TRUE,
      na.rm = TRUE
    ),
    n_direction_reversed = sum(dt$direction_reversed %in% TRUE, na.rm = TRUE),
    n_same_direction = sum(dt$same_direction %in% TRUE, na.rm = TRUE),
    pooled_only_plot_eligible = sum(
      dt$pooled_only_plot_eligible %in% TRUE,
      na.rm = TRUE
    ),
    lmtp_only_plot_eligible = sum(
      dt$lmtp_only_plot_eligible %in% TRUE,
      na.rm = TRUE
    ),
    mean_abs_risk_ratio_gap = mean(dt$abs_risk_ratio_gap, na.rm = TRUE),
    mean_abs_log_risk_ratio_gap = mean(dt$abs_log_risk_ratio_gap, na.rm = TRUE),
    max_abs_risk_ratio_gap = max(dt$abs_risk_ratio_gap, na.rm = TRUE),
    max_abs_log_risk_ratio_gap = max(dt$abs_log_risk_ratio_gap, na.rm = TRUE)
  )
}

extract_comparison_debug_rows <- function(comparison_dt, n = 12L) {
  dt <- data.table::as.data.table(comparison_dt)
  dt <- dt[
    direction_reversed %in%
      TRUE |
      shared_plot_eligible %in% TRUE |
      pooled_only_plot_eligible %in% TRUE |
      lmtp_only_plot_eligible %in% TRUE
  ]

  data.table::setorderv(
    dt,
    c("direction_reversed", "shared_plot_eligible", "abs_log_risk_ratio_gap"),
    order = c(-1L, -1L, -1L)
  )

  utils::head(dt, n)
}
