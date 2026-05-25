make_risk_summary_direction_guide <- function(from_label, to_label) {
  grid::grobTree(
    left_arrow = grid::segmentsGrob(
      x0 = grid::unit(0.40, "npc"),
      x1 = grid::unit(0.20, "npc"),
      y0 = grid::unit(-0.215, "npc"),
      y1 = grid::unit(-0.215, "npc"),
      arrow = grid::arrow(
        angle = 25,
        length = grid::unit(0.1, "inches"),
        type = "open"
      ),
      gp = grid::gpar(col = "grey25", lwd = 1),
      name = "left_arrow"
    ),
    right_arrow = grid::segmentsGrob(
      x0 = grid::unit(0.60, "npc"),
      x1 = grid::unit(0.80, "npc"),
      y0 = grid::unit(-0.215, "npc"),
      y1 = grid::unit(-0.215, "npc"),
      arrow = grid::arrow(
        angle = 25,
        length = grid::unit(0.1, "inches"),
        type = "open"
      ),
      gp = grid::gpar(col = "grey25", lwd = 1),
      name = "right_arrow"
    ),
    left_more_label = grid::textGrob(
      sprintf("More %s", from_label),
      x = grid::unit(0.30, "npc"),
      y = grid::unit(-0.16, "npc"),
      gp = grid::gpar(col = "grey20", fontsize = 14, fontfamily = "serif"),
      name = "left_more_label"
    ),
    left_less_label = grid::textGrob(
      sprintf("Less %s", to_label),
      x = grid::unit(0.30, "npc"),
      y = grid::unit(-0.27, "npc"),
      gp = grid::gpar(col = "grey20", fontsize = 14, fontfamily = "serif"),
      name = "left_less_label"
    ),
    right_less_label = grid::textGrob(
      sprintf("Less %s", from_label),
      x = grid::unit(0.70, "npc"),
      y = grid::unit(-0.16, "npc"),
      gp = grid::gpar(col = "grey20", fontsize = 14, fontfamily = "serif"),
      name = "right_less_label"
    ),
    right_more_label = grid::textGrob(
      sprintf("More %s", to_label),
      x = grid::unit(0.70, "npc"),
      y = grid::unit(-0.27, "npc"),
      gp = grid::gpar(col = "grey20", fontsize = 14, fontfamily = "serif"),
      name = "right_more_label"
    )
  )
}

make_risk_summary_x_breaks <- function(x_limit) {
  candidates <- pretty(c(0, x_limit), n = 10L)
  candidates <- candidates[candidates > 0 & candidates < x_limit]
  if (length(candidates) == 0L) {
    return(c(-x_limit, 0, x_limit))
  }

  distance_from_midpoint <- abs(candidates - (x_limit / 2))
  midpoint_break <- max(
    candidates[distance_from_midpoint == min(distance_from_midpoint)]
  )

  c(-x_limit, -midpoint_break, 0, midpoint_break, x_limit)
}

plot_risk_summary_pair <- function(dt, labels = NULL) {
  required_cols <- c(
    "timegroup",
    "from",
    "to",
    "duration",
    "RR",
    "RR_lower",
    "RR_upper"
  )
  dt <- copy(dt)
  pair <- unique(dt[, .(from, to)])
  final_timegroup <- max(dt$timegroup, na.rm = TRUE)
  dt <- dt[timegroup == final_timegroup]
  setorder(dt, duration)
  x_limit <- max(abs(dt$duration), na.rm = TRUE)
  if (!is.finite(x_limit) || x_limit <= 0) {
    x_limit <- 1L
  }
  x_limits <- c(-x_limit, x_limit)
  x_breaks <- make_risk_summary_x_breaks(x_limit)

  from_label <- pair$from[[1]]
  to_label <- pair$to[[1]]
  if (!is.null(labels)) {
    if (from_label %in% names(labels)) {
      from_label <- unname(labels[[from_label]])
    }
    if (to_label %in% names(labels)) {
      to_label <- unname(labels[[to_label]])
    }
  }

  plot <- ggplot(
    dt,
    aes(x = duration, y = RR)
  ) +
    geom_hline(
      yintercept = 1,
      linetype = "dotted",
      linewidth = 0.4,
      color = "grey25"
    ) +
    geom_ribbon(
      aes(ymin = RR_lower, ymax = RR_upper),
      fill = "#D9A9AF",
      alpha = 0.50
    ) +
    geom_line(linewidth = 0.8, color = "#AB4D54") +
    annotation_custom(
      make_risk_summary_direction_guide(from_label, to_label),
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
      transform = "identity",
      limits = c(0.7, 1.4),
      breaks = seq(0.7, 1.4, by = 0.1),
      minor_breaks = NULL,
      labels = function(x) sprintf("%.2f", x),
      expand = expansion(mult = 0)
    ) +
    coord_cartesian(clip = "off") +
    labs(x = "Minutes", y = "Risk ratio") +
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

  ggsave(
    paste0(from_label, "_", to_label, ".png"),
    plot,
    device = "png",
    width = 10,
    height = 7.25
  )

  plot
}
