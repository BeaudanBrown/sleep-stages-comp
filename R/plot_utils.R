base_substitution_theme <- function() {
  cowplot::theme_cowplot() +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", color = NA),
      panel.background = ggplot2::element_rect(fill = "white", color = NA)
    )
}

compute_substitution_plot_scales <- function(
  summary_dt,
  ratio_threshold = 0.75,
  default_rr_limits = c(0.95, 1.05)
) {
  dt <- data.table::as.data.table(summary_dt)
  dt_plot <- dt[
    is.finite(ratio_substituted) &
      ratio_substituted >= ratio_threshold &
      is.finite(mean_risk_ratio) &
      is.finite(lower_ci) &
      is.finite(upper_ci)
  ]

  rr_vals <- c(
    dt_plot$mean_risk_ratio,
    dt_plot$lower_ci,
    dt_plot$upper_ci,
    1
  )
  rr_vals <- rr_vals[is.finite(rr_vals)]

  if (length(rr_vals) == 0L) {
    rr_limits <- default_rr_limits
  } else {
    rr_limits <- range(rr_vals)
    if (!is.finite(rr_limits[1]) || !is.finite(rr_limits[2])) {
      rr_limits <- default_rr_limits
    } else if (rr_limits[1] == rr_limits[2]) {
      rr_limits <- rr_limits + c(-0.05, 0.05)
    }
  }

  rs_limits <- c(ratio_threshold, 1)
  if (rs_limits[1] >= rs_limits[2]) {
    rs_limits <- c(0, 1)
  }

  ratio_to_rr <- function(ratio) {
    (ratio - rs_limits[1]) /
      (rs_limits[2] - rs_limits[1]) *
      (rr_limits[2] - rr_limits[1]) +
      rr_limits[1]
  }

  rr_to_ratio <- function(rr) {
    (rr - rr_limits[1]) /
      (rr_limits[2] - rr_limits[1]) *
      (rs_limits[2] - rs_limits[1]) +
      rs_limits[1]
  }

  list(
    ratio_threshold = ratio_threshold,
    rr_limits = rr_limits,
    rs_limits = rs_limits,
    ratio_to_rr = ratio_to_rr,
    rr_to_ratio = rr_to_ratio
  )
}

empty_substitution_plot <- function(title, subtitle, y_label, scales) {
  ggplot2::ggplot() +
    base_substitution_theme() +
    ggplot2::labs(
      title = title,
      subtitle = subtitle,
      x = "Minutes shifted",
      y = y_label
    ) +
    ggplot2::annotate(
      "text",
      x = 0,
      y = mean(scales$rr_limits),
      label = "No data"
    ) +
    ggplot2::scale_y_continuous(
      limits = scales$rr_limits,
      sec.axis = ggplot2::sec_axis(
        transform = ~ scales$rr_to_ratio(.),
        name = "Ratio substituted",
        labels = function(x) sprintf("%d%%", round(x * 100))
      )
    ) +
    ggplot2::scale_x_continuous(
      breaks = seq(-60, 60, by = 15),
      limits = c(-60, 60)
    )
}

write_substitution_plots <- function(plot_dt, dir_path, file_prefix) {
  dir.create(dir_path, showWarnings = FALSE, recursive = TRUE)
  paths <- vapply(
    seq_len(nrow(plot_dt)),
    function(i) {
      from_label <- tolower(stage_labels[plot_dt$from[i]])
      to_label <- tolower(stage_labels[plot_dt$to[i]])
      path <- file.path(
        dir_path,
        sprintf(
          "%s_from_%s_to_%s.png",
          file_prefix,
          from_label,
          to_label
        )
      )
      ggplot2::ggsave(
        path,
        plot = plot_dt$plot[[i]],
        width = 10,
        height = 6,
        bg = "white"
      )
      path
    },
    character(1)
  )
  unname(paths)
}

plot_bootstrap_substitutions <- function(
  summary_dt,
  from,
  to,
  scales,
  ratio_threshold = scales$ratio_threshold
) {
  dt_all <- data.table::copy(summary_dt)
  data.table::setorder(dt_all, duration)

  dt_ratio <- dt_all[
    is.finite(ratio_substituted) &
      ratio_substituted >= ratio_threshold
  ]
  dt_risk <- dt_all[
    ratio_substituted >= ratio_threshold &
      is.finite(mean_risk_ratio) &
      is.finite(lower_ci) &
      is.finite(upper_ci)
  ]

  from_label <- stage_labels[from]
  to_label <- stage_labels[to]

  if (nrow(dt_ratio) == 0) {
    return(empty_substitution_plot(
      title = sprintf("Shift %s \u2192 %s", from_label, to_label),
      subtitle = sprintf(
        "No data above %d%% substitution coverage",
        round(ratio_threshold * 100)
      ),
      y_label = "Risk ratio",
      scales = scales
    ))
  }

  dt_ratio[, ratio_substituted_scaled := scales$ratio_to_rr(ratio_substituted)]

  ggplot2::ggplot() +
    ggplot2::geom_ribbon(
      data = dt_risk,
      ggplot2::aes(
        x = duration,
        ymin = pmin(lower_ci, upper_ci),
        ymax = pmax(lower_ci, upper_ci)
      ),
      alpha = 0.2,
      color = NA,
      fill = "grey70"
    ) +
    ggplot2::geom_smooth(
      data = dt_risk,
      ggplot2::aes(x = duration, y = mean_risk_ratio),
      method = "loess",
      se = FALSE,
      formula = y ~ x,
      linewidth = 0.9
    ) +
    ggplot2::geom_point(
      data = dt_ratio,
      ggplot2::aes(x = duration, y = ratio_substituted_scaled),
      size = 1.6,
      color = "steelblue"
    ) +
    base_substitution_theme() +
    ggplot2::scale_y_continuous(
      limits = scales$rr_limits,
      sec.axis = ggplot2::sec_axis(
        transform = ~ scales$rr_to_ratio(.),
        name = "Ratio substituted",
        labels = function(x) sprintf("%d%%", round(x * 100))
      )
    ) +
    ggplot2::scale_x_continuous(
      breaks = seq(-60, 60, by = 15),
      limits = c(-60, 60)
    ) +
    ggplot2::labs(
      x = "Minutes shifted",
      y = "Risk ratio",
      title = sprintf("Shift %s \u2192 %s", from_label, to_label),
      subtitle = sprintf(
        "Shown only when ratio substituted \u2265 %d%%",
        round(ratio_threshold * 100)
      )
    )
}

plot_lmtp_substitutions <- function(
  summary_dt,
  from,
  to,
  scales,
  ratio_threshold = scales$ratio_threshold
) {
  dt_all <- data.table::copy(summary_dt)
  data.table::setorder(dt_all, duration)

  dt_ratio <- dt_all[
    is.finite(ratio_substituted) &
      ratio_substituted >= ratio_threshold
  ]
  dt_risk <- dt_all[
    ratio_substituted >= ratio_threshold &
      is.finite(mean_risk_ratio) &
      is.finite(lower_ci) &
      is.finite(upper_ci)
  ]

  from_label <- stage_labels[from]
  to_label <- stage_labels[to]

  if (nrow(dt_ratio) == 0 || nrow(dt_risk) == 0) {
    return(empty_substitution_plot(
      title = sprintf("LMTP Shift %s -> %s", from_label, to_label),
      subtitle = sprintf(
        "No LMTP results above %d%% substitution coverage",
        round(ratio_threshold * 100)
      ),
      y_label = "Risk ratio vs no intervention",
      scales = scales
    ))
  }

  dt_ratio[, ratio_substituted_scaled := scales$ratio_to_rr(ratio_substituted)]

  ggplot2::ggplot() +
    ggplot2::geom_hline(
      yintercept = 1,
      linetype = "dashed",
      linewidth = 0.5,
      color = "grey40"
    ) +
    ggplot2::geom_ribbon(
      data = dt_risk,
      ggplot2::aes(
        x = duration,
        ymin = pmin(lower_ci, upper_ci),
        ymax = pmax(lower_ci, upper_ci)
      ),
      alpha = 0.2,
      color = NA,
      fill = "grey70"
    ) +
    ggplot2::geom_line(
      data = dt_risk,
      ggplot2::aes(x = duration, y = mean_risk_ratio),
      linewidth = 0.9
    ) +
    ggplot2::geom_point(
      data = dt_risk,
      ggplot2::aes(x = duration, y = mean_risk_ratio),
      size = 1.8
    ) +
    ggplot2::geom_line(
      data = dt_ratio,
      ggplot2::aes(x = duration, y = ratio_substituted_scaled),
      linewidth = 0.7,
      color = "steelblue",
      alpha = 0.8
    ) +
    ggplot2::geom_point(
      data = dt_ratio,
      ggplot2::aes(x = duration, y = ratio_substituted_scaled),
      size = 1.4,
      color = "steelblue"
    ) +
    base_substitution_theme() +
    ggplot2::scale_y_continuous(
      name = "Risk ratio vs no intervention",
      limits = scales$rr_limits,
      sec.axis = ggplot2::sec_axis(
        transform = ~ scales$rr_to_ratio(.),
        name = "Participants shifted",
        labels = function(x) sprintf("%d%%", round(x * 100))
      )
    ) +
    ggplot2::scale_x_continuous(
      breaks = seq(-60, 60, by = 15),
      limits = c(-60, 60)
    ) +
    ggplot2::labs(
      x = "Minutes shifted",
      title = sprintf("LMTP Shift %s -> %s", from_label, to_label),
      subtitle = sprintf(
        "Shown only when ratio substituted \u2265 %d%%",
        round(ratio_threshold * 100)
      )
    )
}

make_bootstrap_substitution_plots <- function(
  summary_dt,
  ratio_threshold = 0.75
) {
  scales <- compute_substitution_plot_scales(
    summary_dt = summary_dt,
    ratio_threshold = ratio_threshold
  )

  summary_dt[,
    .(
      plot = list(
        plot_bootstrap_substitutions(
          .SD,
          from = from[1],
          to = to[1],
          scales = scales,
          ratio_threshold = ratio_threshold
        )
      )
    ),
    by = .(from, to)
  ]
}

make_lmtp_substitution_plots <- function(summary_dt, ratio_threshold = 0.75) {
  scales <- compute_substitution_plot_scales(
    summary_dt = summary_dt,
    ratio_threshold = ratio_threshold
  )

  summary_dt[,
    .(
      plot = list(
        plot_lmtp_substitutions(
          .SD,
          from = from[1],
          to = to[1],
          scales = scales,
          ratio_threshold = ratio_threshold
        )
      )
    ),
    by = .(from, to)
  ]
}

write_bootstrap_substitution_plots <- function(plot_dt, dir_path) {
  write_substitution_plots(
    plot_dt = plot_dt,
    dir_path = dir_path,
    file_prefix = "bootstrap_substitution_risk_ratio"
  )
}

write_lmtp_substitution_plots <- function(plot_dt, dir_path) {
  write_substitution_plots(
    plot_dt = plot_dt,
    dir_path = dir_path,
    file_prefix = "lmtp_substitution_risk_ratio"
  )
}
