# Four-stage closure excludes WASO. Only binned counts enter the plot widget.
summarize_composition_distribution <- function(dt, bin_width = 0.02) {
  stage_vars <- c("n1_s2", "n2_s2", "n3_s2", "rem_s2")
  stages <- as.matrix(dt[, ..stage_vars])
  proportions <- as.data.table(stages / rowSums(stages))
  breaks <- quantile(proportions$rem_s2, seq(0, 1, by = 0.2), names = FALSE)
  proportions[,
    quintile := findInterval(
      rem_s2,
      breaks,
      all.inside = TRUE,
      rightmost.closed = TRUE
    )
  ]
  axis_vars <- stage_vars[1:3]
  proportions[,
    (axis_vars) := lapply(.SD, \(x) floor(x / bin_width) * bin_width),
    .SDcols = axis_vars
  ]
  counts <- proportions[, .(n = .N), by = c("quintile", axis_vars)]
  list(counts = counts, rem_breaks = breaks, bin_width = bin_width)
}

plot_composition_distribution <- function(dt, bin_width = 0.02) {
  summary <- summarize_composition_distribution(dt, bin_width)
  counts <- summary$counts
  breaks <- summary$rem_breaks
  colours <- c("#440154", "#3B528B", "#21918C", "#5EC962", "#FDE725")
  vertices <- rbind(c(0, 0, 0), c(1, 0, 0), c(0, 1, 0), c(0, 0, 1))
  edges <- combn(1:4, 2)
  wire <- do.call(
    rbind,
    lapply(seq_len(ncol(edges)), \(i) {
      rbind(vertices[edges[, i], ], c(NA, NA, NA))
    })
  )
  plot <- plotly::plot_ly(height = 850)
  scenes <- list()
  annotations <- list()
  axis <- function(title) {
    list(
      title = title,
      range = c(0, 1),
      tickvals = seq(0, 1, 0.25),
      tickformat = ".0%",
      zeroline = FALSE
    )
  }

  for (q in 1:5) {
    scene <- if (q == 1L) "scene" else paste0("scene", q)
    panel <- counts[quintile == q]
    # Three panels above two panels; all use identical axes and camera angles.
    column <- (q - 1L) %% 3L
    x_domain <- c(column / 3, (column + 1) / 3 - 0.015)
    y_domain <- if (q <= 3L) c(0.55, 0.96) else c(0.04, 0.45)
    scenes[[scene]] <- list(
      domain = list(x = x_domain, y = y_domain),
      xaxis = axis("N1"),
      yaxis = axis("N2"),
      zaxis = axis("N3"),
      aspectmode = "cube",
      camera = list(eye = list(x = 1.5, y = 1.5, z = 1.2))
    )
    annotations[[q]] <- list(
      x = mean(x_domain),
      y = y_domain[2] + 0.02,
      xref = "paper",
      yref = "paper",
      text = sprintf(
        "REM Q%d: %.1f–%.1f%% (n = %d)",
        q,
        100 * breaks[q],
        100 * breaks[q + 1L],
        sum(panel$n)
      ),
      showarrow = FALSE,
      xanchor = "center",
      yanchor = "bottom"
    )
    plot <- plotly::add_trace(
      plot,
      x = wire[, 1],
      y = wire[, 2],
      z = wire[, 3],
      type = "scatter3d",
      mode = "lines",
      scene = scene,
      line = list(color = "#999999", width = 2),
      hoverinfo = "skip",
      showlegend = FALSE,
      inherit = FALSE
    )
    # The two REM cutpoints bound a slab within the tetrahedron.
    for (bound in breaks[c(q, q + 1L)]) {
      triangle <- (1 - bound) * rbind(c(1, 0, 0), c(0, 1, 0), c(0, 0, 1), c(1, 0, 0))
      plot <- plotly::add_trace(
        plot,
        x = triangle[, 1],
        y = triangle[, 2],
        z = triangle[, 3],
        type = "scatter3d",
        mode = "lines",
        scene = scene,
        line = list(color = colours[q], width = 3),
        opacity = 0.4,
        hoverinfo = "skip",
        showlegend = FALSE,
        inherit = FALSE
      )
    }
    plot <- plotly::add_trace(
      plot,
      x = panel$n1_s2,
      y = panel$n2_s2,
      z = panel$n3_s2,
      type = "scatter3d",
      mode = "markers",
      scene = scene,
      marker = list(
        color = colours[q],
        size = panel$n,
        sizemode = "area",
        sizeref = 2 * max(counts$n) / 18^2,
        sizemin = 3,
        opacity = 0.8
      ),
      text = sprintf(
        "N1: %.0f–%.0f%%<br>N2: %.0f–%.0f%%<br>N3: %.0f–%.0f%%<br>Count: %d",
        100 * panel$n1_s2,
        100 * pmin(1, panel$n1_s2 + bin_width),
        100 * panel$n2_s2,
        100 * pmin(1, panel$n2_s2 + bin_width),
        100 * panel$n3_s2,
        100 * pmin(1, panel$n3_s2 + bin_width),
        panel$n
      ),
      hoverinfo = "text",
      showlegend = FALSE,
      inherit = FALSE
    )
  }
  do.call(
    plotly::layout,
    c(
      list(
        p = plot,
        title = list(
          text = paste0(
            "Sleep-stage composition by REM quintile",
            "<br><sup>WASO excluded; N1 + N2 + N3 + REM = 100%</sup>"
          )
        ),
        annotations = c(
          annotations,
          list(list(
            x = 0.83,
            y = 0.25,
            xref = "paper",
            yref = "paper",
            showarrow = FALSE,
            text = sprintf(
              paste0(
                "Marker area represents count.<br>%.0f percentage-point bins;",
                "<br>markers sit at bin lower corners.<br>Coloured triangles bound each REM slice.",
                "<br>Tied REM values stay together;<br>panel sizes may differ."
              ),
              100 * bin_width
            )
          ))
        ),
        margin = list(t = 110, b = 30, l = 10, r = 10)
      ),
      scenes
    )
  )
}
