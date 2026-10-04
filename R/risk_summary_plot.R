orient_risk_summary_pair <- function(dt, right_stage) {
  dt <- copy(as.data.table(dt))
  pair <- unique(dt[, .(from, to)])

  if (pair$from[[1]] == right_stage) {
    dt[, `:=`(
      from = pair$to[[1]],
      to = pair$from[[1]],
      duration = -duration
    )]
  }

  dt
}

make_risk_summary_x_breaks <- function(x_limit) {
  x_limit <- max(abs(x_limit))
  breaks <- pretty(c(-x_limit, x_limit), n = 6L)
  unique(c(-x_limit, breaks[breaks > -x_limit & breaks < x_limit], x_limit))
}

make_risk_plot_direction <- function(from_label, to_label) {
  grid::grobTree(
    grid::segmentsGrob(
      x0 = grid::unit(c(0.40, 0.60), "npc"),
      x1 = grid::unit(c(0.20, 0.80), "npc"),
      y0 = grid::unit(-0.215, "npc"),
      y1 = grid::unit(-0.215, "npc"),
      arrow = grid::arrow(length = grid::unit(0.1, "inches"), type = "open"),
      gp = grid::gpar(col = "grey25", lwd = 1)
    ),
    left_more_label = grid::textGrob(
      sprintf("More %s", from_label),
      name = "left_more_label",
      x = 0.30,
      y = -0.26,
      gp = grid::gpar(col = "grey20", fontsize = 14, fontfamily = "serif")
    ),
    left_less_label = grid::textGrob(
      sprintf("Less %s", to_label),
      name = "left_less_label",
      x = 0.30,
      y = -0.17,
      gp = grid::gpar(col = "grey20", fontsize = 14, fontfamily = "serif")
    ),
    right_less_label = grid::textGrob(
      sprintf("Less %s", from_label),
      name = "right_less_label",
      x = 0.70,
      y = -0.26,
      gp = grid::gpar(col = "grey20", fontsize = 14, fontfamily = "serif")
    ),
    right_more_label = grid::textGrob(
      sprintf("More %s", to_label),
      name = "right_more_label",
      x = 0.70,
      y = -0.17,
      gp = grid::gpar(col = "grey20", fontsize = 14, fontfamily = "serif")
    )
  )
}

plot_continuous_summary_pair <- function(
  dt,
  labels = NULL,
  right_stage = NULL,
  output_file = NULL
) {
  dt <- copy(as.data.table(dt))
  file_pair <- unique(dt[, .(from, to)])

  if (!is.null(right_stage)) {
    dt <- orient_risk_summary_pair(dt, right_stage = right_stage)
  }

  pair <- unique(dt[, .(from, to)])
  outcome <- unique(dt$outcome)
  setorder(dt, duration)

  x_limit <- max(abs(dt$duration), na.rm = TRUE)
  x_limits <- c(-x_limit, x_limit)
  x_breaks <- make_risk_summary_x_breaks(x_limit)

  y_axis <- switch(
    outcome,
    pc1_s2 = list(
      limits = c(-0.05, 0.05),
      breaks = seq(-0.05, 0.05, by = 0.025),
      label = "Mean difference in cognitive summary score"
    ),
    Hippo_s2 = list(
      limits = c(-0.025, 0.025),
      breaks = seq(-0.025, 0.025, by = 0.0125),
      label = "Mean difference (mL)"
    ),
    Cerebrum_tcb_s2 = list(
      limits = c(-1, 1),
      breaks = seq(-1, 1, by = 0.5),
      label = "Mean difference (mL)"
    )
  )

  stage_label <- function(stage) {
    if (!is.null(labels) && stage %in% names(labels)) {
      return(unname(labels[[stage]]))
    }
    stage
  }
  from_label <- stage_label(pair$from[[1]])
  to_label <- stage_label(pair$to[[1]])
  file_from_label <- stage_label(file_pair$from[[1]])
  file_to_label <- stage_label(file_pair$to[[1]])

  plot <- ggplot(
    dt,
    aes(x = duration, y = estimate)
  ) +
    geom_hline(
      yintercept = 0,
      linetype = "dotted",
      linewidth = 0.4,
      color = "grey25"
    ) +
    geom_ribbon(
      aes(ymin = lower, ymax = upper),
      fill = "#D9A9AF",
      alpha = 0.50
    ) +
    geom_line(linewidth = 0.8, color = "#AB4D54") +
    annotation_custom(
      make_risk_plot_direction(from_label, to_label),
      xmin = x_limits[[1]],
      xmax = x_limits[[2]],
      ymin = -Inf,
      ymax = Inf
    ) +
    scale_x_continuous(
      limits = x_limits,
      breaks = x_breaks,
      labels = function(x) {
        vapply(
          x,
          format,
          character(1),
          trim = TRUE,
          scientific = FALSE
        )
      },
      expand = expansion(mult = 0)
    ) +
    scale_y_continuous(
      limits = y_axis$limits,
      breaks = y_axis$breaks,
      minor_breaks = NULL,
      oob = scales::squish,
      expand = expansion(mult = 0)
    ) +
    coord_cartesian(clip = "off") +
    labs(
      title = outcome,
      x = "Minutes",
      y = y_axis$label
    ) +
    theme_bw(base_family = "serif", base_size = 16) +
    theme(
      panel.border = element_rect(color = "grey45", linewidth = 0.5),
      panel.grid.major = element_line(color = "grey90", linewidth = 0.35),
      panel.grid.minor = element_line(color = "grey94", linewidth = 0.25),
      axis.title = element_text(size = 18),
      axis.text = element_text(size = 14, color = "grey15"),
      axis.title.x = element_text(margin = margin(t = 2)),
      plot.margin = margin(t = 10, r = 10, b = 76, l = 10),
      aspect.ratio = 0.60
    )

  if (is.null(output_file)) {
    output_file <- paste0(
      outcome,
      "_",
      file_from_label,
      "_",
      file_to_label,
      ".png"
    )
  }

  ggsave(
    output_file,
    plot,
    device = "png",
    width = 10,
    height = 7.25
  )

  plot
}
