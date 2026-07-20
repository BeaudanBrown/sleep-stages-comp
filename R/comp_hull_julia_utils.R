write_comp_hull_input_file <- function(
  dt,
  comp_vars
) {
  dir <- file.path("_targets", "user", "comp_hull")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  out <- data.table::copy(dt[, c("PID", comp_vars), with = FALSE])
  out[, row_id := seq_len(.N)]
  data.table::setcolorder(out, c("row_id", "PID", comp_vars))

  path <- file.path(dir, "comp_hull_input.csv")
  data.table::fwrite(out, path)
  path
}

write_substitutions_file <- function(
  substitutions
) {
  dir <- file.path("_targets", "user", "comp_hull")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(dir, "substitutions.csv")
  data.table::fwrite(data.table::as.data.table(substitutions), path)
  path
}

compute_comp_hull_masks_for_dt <- function(
  dt,
  substitutions,
  imputation_id = "1",
  dir = tempfile("comp_hull_runtime_", tmpdir = comp_hull_work_dir())
) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  input_file <- write_comp_hull_input_file(
    dt = dt,
    imputation_id = imputation_id,
    dir = dir
  )
  substitutions_file <- write_substitutions_file(
    substitutions = substitutions,
    dir = dir
  )
  mask_file <- run_julia_comp_hull_masks(
    input_file = input_file,
    substitutions_file = substitutions_file,
    imputation_id = imputation_id,
    dir = dir
  )

  read_comp_hull_masks(mask_file)
}

run_julia_comp_hull_frontiers <- function(
  input_file,
  comparison_settings,
  comp_vars,
  script = file.path("scripts", "comp_hull_support.jl")
) {
  dir <- file.path("_targets", "user", "comp_hull")
  ratio_threshold <- comparison_settings$ratio_threshold
  max_minutes <- comparison_settings$duration_limit
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  output_file <- file.path(
    dir,
    "comp_hull_frontiers.csv"
  )

  run_julia_comp_hull_support(
    c(
      "--input",
      input_file,
      "--vars",
      paste(comp_vars, collapse = ","),
      "--frontiers",
      output_file,
      "--ratio-threshold",
      as.character(ratio_threshold),
      "--max-minutes",
      as.character(max_minutes)
    ),
    script = script
  )

  output_file
}

run_julia_comp_hull_masks <- function(
  input_file,
  substitutions_file,
  comp_vars,
  script = file.path("scripts", "comp_hull_support.jl")
) {
  dir <- file.path("_targets", "user", "comp_hull")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  output_file <- file.path(
    dir,
    sprintf("comp_hull_masks.csv")
  )

  run_julia_comp_hull_support(
    c(
      "--input",
      input_file,
      "--vars",
      paste(comp_vars, collapse = ","),
      "--substitutions",
      substitutions_file,
      "--masks",
      output_file
    ),
    script = script
  )

  output_file
}

run_julia_comp_hull_support <- function(
  args,
  script = file.path("scripts", "comp_hull_support.jl")
) {
  script <- normalizePath(
    script,
    winslash = "/",
    mustWork = TRUE
  )
  julia <- Sys.which("julia")
  if (!nzchar(julia)) {
    stop("Could not find julia on PATH.", call. = FALSE)
  }

  res <- system2(julia, c(script, args), stdout = TRUE, stderr = TRUE)
  status <- attr(res, "status")

  if (!is.null(status) && status != 0L) {
    stop(
      "Julia convex hull support calculation failed:\n",
      paste(res, collapse = "\n"),
      call. = FALSE
    )
  }

  invisible(res)
}

read_comp_hull_frontiers <- function(frontier_file) {
  data.table::fread(frontier_file)[,
    max_supported_minutes := as.integer(max_supported_minutes)
  ]
}

read_comp_hull_masks <- function(mask_file) {
  out <- data.table::fread(mask_file)
  out[, duration := as.integer(duration)]
  out[, substituted := as.logical(substituted)]
  out[, applied_duration := as.numeric(applied_duration)]
  if ("PID" %in% names(out)) {
    out[, PID := as.character(PID)]
  }
  out
}

is_substitution_mask_table <- function(x) {
  data.table::is.data.table(x) &&
    all(
      c(
        "from",
        "to",
        "duration",
        "substituted",
        "applied_duration"
      ) %in%
        names(x)
    )
}

lookup_substitution_policy <- function(
  dt,
  substitution_masks,
  from,
  to,
  duration
) {
  dt <- data.table::as.data.table(dt)
  masks <- data.table::copy(data.table::as.data.table(substitution_masks))
  if ("PID" %in% names(masks)) {
    masks[, PID := as.character(PID)]
  }
  duration_value <- as.integer(duration)
  from_value <- from
  to_value <- to

  mask_dt <- masks[
    masks[["from"]] == from_value &
      masks[["to"]] == to_value &
      masks[["duration"]] == duration_value
  ]

  if (nrow(mask_dt) == 0L) {
    stop(
      sprintf(
        "No substitution mask for %s -> %s at %s minutes.",
        from,
        to,
        duration
      ),
      call. = FALSE
    )
  }

  if ("PID_original" %in% names(dt) && "PID" %in% names(mask_dt)) {
    lookup <- mask_dt[
      data.table::data.table(PID = as.character(dt$PID_original)),
      on = "PID",
      .(substituted, applied_duration),
      allow.cartesian = TRUE
    ]
  } else if ("PID" %in% names(dt) && "PID" %in% names(mask_dt)) {
    lookup <- mask_dt[
      data.table::data.table(PID = as.character(dt$PID)),
      on = "PID",
      .(substituted, applied_duration),
      allow.cartesian = TRUE
    ]
  } else if ("row_id" %in% names(mask_dt)) {
    lookup <- mask_dt[
      data.table::data.table(row_id = seq_len(nrow(dt))),
      on = "row_id",
      .(substituted, applied_duration)
    ]
  } else {
    stop("Substitution masks need PID or row_id for lookup.", call. = FALSE)
  }

  if (nrow(lookup) != nrow(dt) || anyNA(lookup)) {
    stop(
      sprintf("Substitution mask does not align with %s input rows.", nrow(dt)),
      call. = FALSE
    )
  }

  lookup
}

lookup_substitution_mask <- function(
  dt,
  substitution_masks,
  from,
  to,
  duration
) {
  lookup_substitution_policy(
    dt = dt,
    substitution_masks = substitution_masks,
    from = from,
    to = to,
    duration = duration
  )[["substituted"]]
}
build_support_aware_substitution_grid <- function(
  support_frontiers,
  comparison_settings,
  comp_vars
) {
  points_per_direction <- comparison_settings$points_per_direction
  pair_dt <- make_substitution_grid(
    durations = 0,
    comp_vars = comp_vars,
    directed = FALSE
  )[,
    !"duration"
  ]
  support_dt <- data.table::as.data.table(support_frontiers)

  pair_dt[,
    .(
      duration = list({
        pos_max <- support_dt[
          from == .BY$from & to == .BY$to,
          max_supported_minutes
        ]
        neg_max <- support_dt[
          from == .BY$to & to == .BY$from,
          max_supported_minutes
        ]

        pos_points <- round(seq(
          from = pos_max / points_per_direction,
          to = pos_max,
          length.out = points_per_direction
        ))

        # Negative durations apply the reverse reallocation for this pair.
        neg_points <- -round(seq(
          from = neg_max / points_per_direction,
          to = neg_max,
          length.out = points_per_direction
        ))

        unique(c(neg_points, 0L, pos_points))
      })
    ),
    by = .(from, to)
  ][,
    .(duration = unlist(duration)),
    by = .(from, to)
  ]
}
