base_substitution_theme <- function() {
  cowplot::theme_cowplot() +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", color = NA),
      panel.background = ggplot2::element_rect(fill = "white", color = NA)
    )
}

plot_ideal_composition_heatmap <- function(
  extreme_compositions,
  comp_vars,
  labels
) {
  dt <- data.table::copy(data.table::as.data.table(extreme_compositions))
  component_dt <- data.table::melt(
    dt,
    id.vars = c(
      "outcome",
      "policy",
      "split_id",
      "tst_minutes",
      "whole_minutes"
    ),
    measure.vars = comp_vars,
    variable.name = "component",
    value.name = "minutes"
  )
  component_dt[, proportion := 100 * minutes / whole_minutes]
  component_dt[,
    component := factor(
      component,
      levels = comp_vars,
      labels = unname(labels[comp_vars])
    )
  ]
  component_dt[,
    split_label := sprintf(
      "Split %02d\nTST %d; whole %d",
      split_id,
      round(tst_minutes),
      round(whole_minutes)
    )
  ]
  component_dt[,
    split_label := factor(
      split_label,
      levels = unique(split_label[order(split_id)])
    )
  ]
  component_dt[, policy := factor(policy, levels = c("worst", "best"))]

  ggplot2::ggplot(
    component_dt,
    ggplot2::aes(x = component, y = split_label, fill = proportion)
  ) +
    ggplot2::geom_tile(color = "white", linewidth = 0.2) +
    ggplot2::geom_text(
      ggplot2::aes(label = sprintf("%.0f", proportion)),
      size = 2.6
    ) +
    ggplot2::facet_grid(outcome ~ policy) +
    ggplot2::scale_fill_gradient(
      low = "#f7fbff",
      high = "#08519c",
      name = "Stage\ncomposition (%)"
    ) +
    base_substitution_theme() +
    ggplot2::theme(
      axis.title.y = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_text(size = 6),
      axis.text.x = ggplot2::element_text(angle = 30, hjust = 1),
      strip.text = ggplot2::element_text(face = "bold")
    ) +
    ggplot2::labs(
      title = "Selected best and worst sleep compositions across splits",
      subtitle = "Tiles show each component as a percentage of the five-part whole",
      x = "Sleep component"
    )
}

plot_ideal_composition_dumbbells <- function(
  extreme_compositions,
  comp_vars,
  labels
) {
  dt <- data.table::copy(data.table::as.data.table(extreme_compositions))
  component_dt <- data.table::melt(
    dt,
    id.vars = c("outcome", "policy", "split_id"),
    measure.vars = comp_vars,
    variable.name = "component",
    value.name = "minutes"
  )
  component_dt[,
    component := factor(
      component,
      levels = rev(comp_vars),
      labels = rev(unname(labels[comp_vars]))
    )
  ]
  component_dt[, policy := factor(policy, levels = c("worst", "best"))]

  ggplot2::ggplot(
    component_dt,
    ggplot2::aes(x = minutes, y = component)
  ) +
    ggplot2::geom_line(
      ggplot2::aes(group = interaction(split_id, component)),
      color = "grey70",
      linewidth = 0.35
    ) +
    ggplot2::geom_point(
      ggplot2::aes(color = policy, shape = policy),
      size = 2
    ) +
    ggplot2::facet_wrap(~outcome, scales = "free_x") +
    ggplot2::scale_color_manual(values = c(worst = "#b2182b", best = "#2166ac")) +
    base_substitution_theme() +
    ggplot2::labs(
      title = "Component changes between selected worst and best compositions",
      x = "Minutes",
      y = "Sleep component",
      color = "Policy",
      shape = "Policy"
    )
}

plot_ideal_composition_ilr_map <- function(
  extreme_compositions,
  comp_vars,
  ilr_base
) {
  dt <- data.table::copy(data.table::as.data.table(extreme_compositions))
  ilr_dt <- make_ilrs(dt, comp_vars, ilr_base)
  ilr_names <- paste0("R", seq_len(length(comp_vars) - 1L))
  dt[, (ilr_names) := ilr_dt]
  dt[, policy := factor(policy, levels = c("worst", "best"))]

  map_dt <- data.table::rbindlist(list(
    dt[, .(
      outcome,
      policy,
      split_id,
      ilr_plane = "R1 vs R2",
      x = R1,
      y = R2
    )],
    dt[, .(
      outcome,
      policy,
      split_id,
      ilr_plane = "R3 vs R4",
      x = R3,
      y = R4
    )]
  ))
  map_dt[, ilr_plane := factor(ilr_plane, levels = c("R1 vs R2", "R3 vs R4"))]
  data.table::setorderv(map_dt, c("outcome", "ilr_plane", "split_id", "policy"))

  ggplot2::ggplot(map_dt, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_path(
      ggplot2::aes(group = interaction(split_id)),
      color = "grey70",
      linewidth = 0.35
    ) +
    ggplot2::geom_point(
      ggplot2::aes(color = policy, shape = policy),
      size = 2
    ) +
    ggplot2::geom_text(
      ggplot2::aes(label = split_id),
      vjust = -0.8,
      size = 2.4,
      show.legend = FALSE
    ) +
    ggplot2::facet_grid(ilr_plane ~ outcome, scales = "free") +
    ggplot2::scale_color_manual(values = c(worst = "#b2182b", best = "#2166ac")) +
    base_substitution_theme() +
    ggplot2::labs(
      title = "Selected best and worst compositions in ILR space",
      subtitle = "Lines connect policies selected from the same split",
      x = "First ILR coordinate in panel",
      y = "Second ILR coordinate in panel",
      color = "Policy",
      shape = "Policy"
    )
}
